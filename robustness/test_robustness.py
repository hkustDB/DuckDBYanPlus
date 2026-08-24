#!/usr/bin/env python3
"""Unit tests for the robustness experiment infrastructure."""

from __future__ import annotations

import csv
import json
import pathlib
import sys
import tempfile
import unittest
from unittest import mock

import run_experiment
import summarize


class SqlPreparationTest(unittest.TestCase):
    def test_experiment_server_defaults(self) -> None:
        with mock.patch.object(sys, "argv", ["run_experiment.py"]):
            args = run_experiment.parse_args()
        self.assertEqual(args.duckdb, run_experiment.REPOSITORY_ROOT / "build/duckdb_origin/duckdb")
        self.assertEqual(args.lsqb_database, run_experiment.REPOSITORY_ROOT / "lsqb_db")
        self.assertEqual(args.job_database, run_experiment.REPOSITORY_ROOT / "job_db")
        self.assertEqual(args.threads, 64)
        self.assertEqual(args.cpu_list, "0-31,36-67")
        self.assertEqual(args.repetitions, 10)
        self.assertEqual(args.warmups, 1)
        self.assertEqual(args.seed, 20260822)
        self.assertEqual(args.timeout, 600)

    def test_split_and_temporary_view_conversion(self) -> None:
        sql = """-- a semicolon in a comment ;
create or replace view v as select ';' AS value;
/* another ; */ select count(*) from v;
"""
        with tempfile.TemporaryDirectory() as temporary:
            source = pathlib.Path(temporary) / "rewrite1.sql"
            source.write_text(sql, encoding="utf-8")
            plan = run_experiment.prepare_plan("test", "q1", "rewrite", source)
        self.assertEqual(len(plan.setup), 1)
        self.assertTrue(plan.setup[0].lower().startswith("-- a semicolon"))
        self.assertIn("create or replace temp view", plan.setup[0].lower())
        self.assertIn("select count(*)", plan.final_query.lower())

    def test_timer_parser(self) -> None:
        output = "Run Time (s): real 0.123456 user 0.1 sys 0.0"
        self.assertEqual(run_experiment.TIMER_PATTERN.findall(output), ["0.123456"])

    def test_timed_query_preparation_is_python_38_compatible(self) -> None:
        plan = run_experiment.Plan(
            suite="test",
            query="q1",
            name="rewrite1",
            kind="rewrite",
            source_file=pathlib.Path("rewrite1.sql"),
            setup=(),
            final_query="SELECT 1;",
        )
        command = run_experiment.plan_command(
            plan,
            pathlib.Path("duckdb"),
            pathlib.Path("test.db"),
            [],
            threads=1,
            warmups=1,
        )
        self.assertIn("COPY (\nSELECT 1\n) TO '/dev/null' (FORMAT CSV);", command)

    def test_rewrite_remains_timing_eligible_when_original_times_out(self) -> None:
        original = run_experiment.Plan(
            "lsqb",
            "q9",
            "query",
            "original",
            run_experiment.ROOT / "lsqb-q9/query.sql",
            (),
            "SELECT 1",
        )
        rewrite = run_experiment.Plan(
            "lsqb",
            "q9",
            "rewrite1",
            "rewrite",
            run_experiment.ROOT / "lsqb-q9/rewrite1.sql",
            (),
            "SELECT 1",
        )
        results = [
            run_experiment.CommandResult("timeout", b"", b"", "timed out after 600 seconds"),
            run_experiment.CommandResult("ok", b"42\n", b"", ""),
        ]
        with tempfile.TemporaryDirectory() as temporary:
            with mock.patch.object(run_experiment, "run_command", side_effect=results):
                rows, timing_eligible = run_experiment.validate_plans(
                    [original, rewrite],
                    pathlib.Path("duckdb"),
                    {"lsqb": pathlib.Path("lsqb.db")},
                    [],
                    1,
                    600,
                    pathlib.Path(temporary),
                )
        self.assertNotIn(original.key, timing_eligible)
        self.assertIn(rewrite.key, timing_eligible)
        self.assertEqual(rows[0]["status"], "timeout")
        self.assertEqual(rows[1]["status"], "unverified")
        self.assertEqual(rows[1]["matches_original"], "false")
        self.assertTrue(rows[1]["result_sha256"])


class SummaryTest(unittest.TestCase):
    def write_csv(
        self, path: pathlib.Path, fields: tuple[str, ...], rows: list[dict[str, object]]
    ) -> None:
        with path.open("w", newline="", encoding="utf-8") as destination:
            writer = csv.DictWriter(destination, fieldnames=fields)
            writer.writeheader()
            writer.writerows(rows)

    def test_all_plan_win_and_negative_conclusion(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = pathlib.Path(temporary)
            raw = directory / "raw_results.csv"
            validation = directory / "validation.csv"
            metadata = directory / "metadata.json"
            metadata.write_text(json.dumps({"repetitions": 3}), encoding="utf-8")
            validation_rows = []
            for plan, kind in (("query", "original"), ("rewrite1", "rewrite"), ("rewrite2", "rewrite")):
                validation_rows.append(
                    {
                        "suite": "job",
                        "query": "2d",
                        "plan": plan,
                        "plan_kind": kind,
                        "source_file": f"job-2d/{plan}.sql",
                        "status": "ok",
                        "matches_original": "true",
                        "result_sha256": "hash",
                        "error": "",
                    }
                )
            self.write_csv(validation, run_experiment.VALIDATION_FIELDS, validation_rows)

            def raw_rows(rewrite2: list[float]) -> list[dict[str, object]]:
                rows = []
                values = {
                    "query": [10.0, 11.0, 9.0],
                    "rewrite1": [5.0, 6.0, 4.0],
                    "rewrite2": rewrite2,
                }
                order = 0
                for plan, timings in values.items():
                    for repetition, seconds in enumerate(timings, start=1):
                        order += 1
                        rows.append(
                            {
                                "suite": "job",
                                "query": "2d",
                                "plan": plan,
                                "plan_kind": "original" if plan == "query" else "rewrite",
                                "source_file": f"job-2d/{plan}.sql",
                                "repetition": repetition,
                                "execution_order": order,
                                "seconds": seconds,
                                "status": "ok",
                                "error": "",
                            }
                        )
                return rows

            self.write_csv(raw, run_experiment.RAW_FIELDS, raw_rows([7.0, 8.0, 6.0]))
            overall = summarize.summarize(raw, validation, directory)
            self.assertTrue(overall["all_plans_outperform_by_median"])
            self.assertTrue(overall["all_plans_outperform_by_mean"])
            with (directory / "robust_query_statistics.csv").open(
                newline="", encoding="utf-8"
            ) as source:
                robust_rows = list(csv.DictReader(source))
            self.assertEqual(len(robust_rows), 1)
            self.assertEqual(list(robust_rows[0]), list(summarize.ROBUST_QUERY_FIELDS))
            self.assertEqual(robust_rows[0]["# Rewrite Plan"], "2")
            self.assertEqual(robust_rows[0]["Fastest rewrite (s)"], "4.000000")
            self.assertEqual(robust_rows[0]["Slowest rewrite (s)"], "8.000000")

            self.write_csv(raw, run_experiment.RAW_FIELDS, raw_rows([12.0, 13.0, 11.0]))
            overall = summarize.summarize(raw, validation, directory)
            self.assertFalse(overall["all_plans_outperform_by_median"])
            self.assertIn(
                "do not support",
                (directory / "summary.md").read_text(encoding="utf-8"),
            )
            with (directory / "robust_query_statistics.csv").open(
                newline="", encoding="utf-8"
            ) as source:
                robust_rows = list(csv.DictReader(source))
            self.assertEqual(robust_rows[0]["# Rewrite Plan"], "1")

    def test_timeout_original_uses_lower_bound_and_keeps_rewrite_statistics(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = pathlib.Path(temporary)
            raw = directory / "raw_results.csv"
            validation = directory / "validation.csv"
            (directory / "metadata.json").write_text(
                json.dumps({"repetitions": 3, "timeout_seconds": 600}),
                encoding="utf-8",
            )
            self.write_csv(
                validation,
                run_experiment.VALIDATION_FIELDS,
                [
                    {
                        "suite": "lsqb",
                        "query": "q9",
                        "plan": "query",
                        "plan_kind": "original",
                        "source_file": "lsqb-q9/query.sql",
                        "status": "timeout",
                        "matches_original": "false",
                        "result_sha256": "",
                        "error": "timed out after 600 seconds",
                    },
                    {
                        "suite": "lsqb",
                        "query": "q9",
                        "plan": "rewrite1",
                        "plan_kind": "rewrite",
                        "source_file": "lsqb-q9/rewrite1.sql",
                        "status": "unverified",
                        "matches_original": "false",
                        "result_sha256": "hash",
                        "error": "original result unavailable; rewrite will still be timed",
                    },
                ],
            )
            self.write_csv(
                raw,
                run_experiment.RAW_FIELDS,
                [
                    {
                        "suite": "lsqb",
                        "query": "q9",
                        "plan": "rewrite1",
                        "plan_kind": "rewrite",
                        "source_file": "lsqb-q9/rewrite1.sql",
                        "repetition": repetition,
                        "execution_order": repetition,
                        "seconds": seconds,
                        "status": "ok",
                        "error": "",
                    }
                    for repetition, seconds in enumerate((5.0, 6.0, 4.0), start=1)
                ],
            )
            summarize.summarize(raw, validation, directory)
            with (directory / "robust_query_statistics.csv").open(
                newline="", encoding="utf-8"
            ) as source:
                rows = list(csv.DictReader(source))
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]["Query"], "lsqb-q9")
            self.assertEqual(rows[0]["Original (s)"], "600")
            self.assertEqual(rows[0]["# Rewrite Plan"], "1")
            self.assertEqual(rows[0]["Rewrite average (s)"], "5.000000")
            self.assertEqual(rows[0]["Rewrite median (s)"], "5.000000")
            self.assertEqual(rows[0]["Fastest rewrite (s)"], "4.000000")
            self.assertEqual(rows[0]["Slowest rewrite (s)"], "6.000000")
            self.assertEqual(rows[0]["Rewrite run std (s)"], "1.000000")


if __name__ == "__main__":
    unittest.main()
