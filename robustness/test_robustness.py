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

            self.write_csv(raw, run_experiment.RAW_FIELDS, raw_rows([12.0, 13.0, 11.0]))
            overall = summarize.summarize(raw, validation, directory)
            self.assertFalse(overall["all_plans_outperform_by_median"])
            self.assertIn(
                "do not support",
                (directory / "summary.md").read_text(encoding="utf-8"),
            )


if __name__ == "__main__":
    unittest.main()
