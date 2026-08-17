#!/usr/bin/env python3
"""Run an isolated Bloom-versus-Hash cache-boundary microbenchmark."""

from __future__ import annotations

import argparse
import csv
import io
import math
import os
import pathlib
import random
import shutil
import subprocess
import sys
from typing import Callable, Dict, Iterable, List, NamedTuple, Optional, Sequence, Tuple


HERE = pathlib.Path(__file__).resolve().parent
REPOSITORY_ROOT = HERE.parents[1]
SOURCE = HERE / "cache_filter_microbenchmark.cpp"
DEFAULT_BINARY = REPOSITORY_ROOT / "build" / "yanplus_cache_filter_microbenchmark"
DEFAULT_OUTPUT = REPOSITORY_ROOT / "semijoin_cache_results.csv"
MIB = 1024 * 1024
BLOOM_MAX_SECTORS = 1 << 26
BLOOM_ALIGNMENT_ALLOWANCE = 64
BLOOM_MIN_BITS = 512
BLOOM_BITS_PER_BUILD_ROW = 12
HASH_INITIAL_CAPACITY = 64
HASH_INLINE_SLOT_BYTES = 16
HASH_RETAINED_BOXED_BYTES = HASH_INITIAL_CAPACITY * HASH_INLINE_SLOT_BYTES


class CacheHierarchy(NamedTuple):
    l1d_bytes: int
    l2_bytes: int
    l3_bytes: int
    source: str


CPP_FIELDS = (
    "backend",
    "build_keys",
    "probe_count",
    "requested_hit_rate",
    "repetitions",
    "filter_bytes",
    "peak_build_bytes",
    "initialization_median_seconds",
    "insertion_median_seconds",
    "build_median_seconds",
    "build_p95_seconds",
    "build_ns_per_key",
    "probe_median_seconds",
    "probe_p95_seconds",
    "probe_ns_per_key",
    "generated_hit_rate",
    "observed_match_rate",
    "false_positive_rate",
    "initialization_samples_seconds",
    "insertion_samples_seconds",
    "probe_samples_seconds",
)
CSV_FIELDS = CPP_FIELDS + (
    "point_labels",
    "bytes_per_build_key",
    "smallest_cache_fit",
    "cpu",
    "affinity",
    "cache_source",
    "l1d_bytes",
    "l2_bytes",
    "l3_bytes",
    "warmups",
    "seed",
)


def next_power_of_two(value: int) -> int:
    if value <= 1:
        return 1
    return 1 << (value - 1).bit_length()


def bloom_filter_bytes(build_rows: int) -> int:
    minimum_bits = max(BLOOM_MIN_BITS, build_rows * BLOOM_BITS_PER_BUILD_ROW)
    sectors = min(next_power_of_two(minimum_bits) >> 6, BLOOM_MAX_SECTORS)
    return BLOOM_ALIGNMENT_ALLOWANCE + sectors * 8


def hash_capacity(distinct_keys: int) -> int:
    capacity = HASH_INITIAL_CAPACITY
    while distinct_keys > capacity - (capacity >> 2):
        capacity *= 2
    return capacity


def hash_filter_bytes(distinct_keys: int) -> int:
    capacity = hash_capacity(distinct_keys)
    return (
        HASH_RETAINED_BOXED_BYTES
        + capacity * HASH_INLINE_SLOT_BYTES
        + math.ceil(capacity / 64) * 8
    )


MEMORY_FUNCTIONS: Dict[str, Callable[[int], int]] = {
    "bloom": bloom_filter_bytes,
    "hash": hash_filter_bytes,
}


def parse_size(text: str) -> int:
    normalized = text.strip().upper()
    suffix_scale = 1
    for suffix, scale in (("KIB", 1 << 10), ("MIB", 1 << 20), ("GIB", 1 << 30),
                          ("K", 1 << 10), ("M", 1 << 20), ("G", 1 << 30)):
        if normalized.endswith(suffix):
            normalized = normalized[: -len(suffix)]
            suffix_scale = scale
            break
    value = float(normalized)
    if not math.isfinite(value) or value <= 0:
        raise ValueError(f"invalid cache size: {text}")
    return round(value * suffix_scale)


def detect_linux_cache(cpu: int) -> CacheHierarchy:
    cache_root = pathlib.Path(f"/sys/devices/system/cpu/cpu{cpu}/cache")
    if not cache_root.is_dir():
        raise RuntimeError(f"Linux cache topology is unavailable for CPU {cpu}: {cache_root}")
    candidates: Dict[str, List[Tuple[int, str]]] = {"L1d": [], "L2": [], "L3": []}
    for index in sorted(cache_root.glob("index*")):
        try:
            level = int((index / "level").read_text(encoding="utf-8").strip())
            cache_type = (index / "type").read_text(encoding="utf-8").strip().lower()
            size = parse_size((index / "size").read_text(encoding="utf-8"))
        except (FileNotFoundError, ValueError):
            continue
        if level == 1 and cache_type == "data":
            candidates["L1d"].append((size, cache_type))
        elif level == 2 and cache_type in {"data", "unified"}:
            candidates["L2"].append((size, cache_type))
        elif level == 3 and cache_type in {"data", "unified"}:
            candidates["L3"].append((size, cache_type))
    missing = [name for name, values in candidates.items() if not values]
    if missing:
        raise RuntimeError(
            f"could not detect {', '.join(missing)} for CPU {cpu}; use --cache-sizes-mib"
        )
    sizes = {name: max(values)[0] for name, values in candidates.items()}
    return CacheHierarchy(
        sizes["L1d"], sizes["L2"], sizes["L3"], f"Linux sysfs ONE-SIZE for CPU {cpu}"
    )


def selected_cache_hierarchy(args: argparse.Namespace) -> CacheHierarchy:
    if args.cache_sizes_mib is not None:
        sizes = tuple(round(value * MIB) for value in args.cache_sizes_mib)
        if any(value <= 0 for value in sizes):
            raise ValueError("--cache-sizes-mib values must be positive")
        hierarchy = CacheHierarchy(*sizes, "manual per-instance override")
    elif sys.platform == "linux":
        hierarchy = detect_linux_cache(args.cpu)
    else:
        raise RuntimeError(
            "automatic cache detection is Linux-only; provide --cache-sizes-mib L1D L2 L3"
        )
    if not hierarchy.l1d_bytes < hierarchy.l2_bytes < hierarchy.l3_bytes:
        raise ValueError("cache sizes must satisfy L1d < L2 < L3")
    return hierarchy


def last_keys_at_or_below(memory_function: Callable[[int], int], byte_limit: int) -> int:
    if memory_function(1) > byte_limit:
        raise ValueError(
            f"cache boundary {byte_limit} bytes is below the filter's minimum allocation"
        )
    low = 1
    high = 2
    previous_bytes = memory_function(high)
    while previous_bytes <= byte_limit:
        low = high
        high *= 2
        current_bytes = memory_function(high)
        if current_bytes == previous_bytes and high > (1 << 50):
            raise ValueError("filter allocation is capped below the requested cache boundary")
        previous_bytes = current_bytes
    while low + 1 < high:
        middle = (low + high) // 2
        if memory_function(middle) <= byte_limit:
            low = middle
        else:
            high = middle
    return low


def key_range_for_allocation(
    memory_function: Callable[[int], int], allocation_bytes: int
) -> Tuple[int, int]:
    first_high = 1
    while memory_function(first_high) < allocation_bytes:
        first_high *= 2
    first_low = 1
    while first_low < first_high:
        middle = (first_low + first_high) // 2
        if memory_function(middle) < allocation_bytes:
            first_low = middle + 1
        else:
            first_high = middle
    if memory_function(first_low) != allocation_bytes:
        raise AssertionError("allocation is not reachable")

    last_low = first_low
    last_high = max(first_low + 1, first_low * 2)
    while memory_function(last_high) == allocation_bytes:
        last_low = last_high
        last_high *= 2
    while last_low + 1 < last_high:
        middle = (last_low + last_high) // 2
        if memory_function(middle) == allocation_bytes:
            last_low = middle
        else:
            last_high = middle
    return first_low, last_low


def representative_keys(
    memory_function: Callable[[int], int], allocation_bytes: int
) -> int:
    first, last = key_range_for_allocation(memory_function, allocation_bytes)
    # Keep the point midway through its allocation step. This gives consecutive
    # table sizes comparable occupancy instead of comparing a full table with a
    # just-resized half-empty table.
    return (first + last) // 2


def cache_boundary_points(hierarchy: CacheHierarchy) -> List[Tuple[str, int, str]]:
    cache_sizes = (
        ("L1d", hierarchy.l1d_bytes),
        ("L2", hierarchy.l2_bytes),
        ("L3", hierarchy.l3_bytes),
    )
    labeled_points: Dict[Tuple[str, int], List[str]] = {}
    for backend, memory_function in MEMORY_FUNCTIONS.items():
        for cache_name, cache_bytes in cache_sizes:
            last_below = last_keys_at_or_below(memory_function, cache_bytes)
            below_bytes = memory_function(last_below)
            above_bytes = memory_function(last_below + 1)
            for relation, allocation_bytes in (("below", below_bytes), ("above", above_bytes)):
                keys = representative_keys(memory_function, allocation_bytes)
                labeled_points.setdefault((backend, keys), []).append(
                    f"{cache_name}_{relation}"
                )
    return sorted(
        (
            (backend, keys, ";".join(labels))
            for (backend, keys), labels in labeled_points.items()
        ),
        key=lambda item: (item[0], MEMORY_FUNCTIONS[item[0]](item[1]), item[1]),
    )


def compile_binary(args: argparse.Namespace) -> pathlib.Path:
    binary = args.binary.expanduser().resolve()
    binary.parent.mkdir(parents=True, exist_ok=True)
    if (
        not args.rebuild
        and binary.is_file()
        and os.access(binary, os.X_OK)
        and binary.stat().st_mtime_ns >= SOURCE.stat().st_mtime_ns
    ):
        return binary
    compiler = shutil.which(args.cxx)
    if compiler is None:
        raise RuntimeError(f"C++ compiler was not found: {args.cxx}")
    command = [
        compiler,
        "-O3",
        "-DNDEBUG",
        "-std=c++17",
        "-march=native",
        str(SOURCE),
        "-o",
        str(binary),
    ]
    result = subprocess.run(command, text=True, capture_output=True, check=False)
    if result.returncode:
        raise RuntimeError(
            "microbenchmark compilation failed:\n"
            + result.stdout
            + result.stderr
            + "\nCommand: "
            + " ".join(command)
        )
    return binary


def affinity_prefix(args: argparse.Namespace) -> List[str]:
    if args.no_affinity:
        return []
    if sys.platform != "linux":
        raise RuntimeError("taskset affinity requires Linux; use --no-affinity for a smoke test")
    taskset = shutil.which(args.taskset)
    if taskset is None:
        raise RuntimeError("taskset was not found; install util-linux or use --no-affinity")
    return [taskset, "--cpu-list", str(args.cpu)]


def run_point(
    args: argparse.Namespace,
    binary: pathlib.Path,
    hierarchy: CacheHierarchy,
    backend: str,
    keys: int,
    labels: str,
) -> Dict[str, object]:
    command = affinity_prefix(args) + [
        str(binary),
        "--backend",
        backend,
        "--build-keys",
        str(keys),
        "--probe-count",
        str(args.probe_count),
        "--hit-rate",
        str(args.hit_rate),
        "--warmups",
        str(args.warmups),
        "--repetitions",
        str(args.repetitions),
        "--seed",
        str(args.seed),
    ]
    print(
        f"Running {backend}: keys={keys:,}, filter={MEMORY_FUNCTIONS[backend](keys) / MIB:.3f} MiB, "
        f"points={labels}",
        file=sys.stderr,
    )
    try:
        result = subprocess.run(
            command,
            text=True,
            capture_output=True,
            check=False,
            timeout=args.timeout,
        )
    except subprocess.TimeoutExpired as error:
        raise RuntimeError(f"microbenchmark timed out: {' '.join(command)}") from error
    if result.returncode:
        raise RuntimeError(
            f"microbenchmark failed: {' '.join(command)}\n{result.stdout}{result.stderr}"
        )
    rows = list(csv.DictReader(io.StringIO(result.stdout)))
    if len(rows) != 1 or tuple(rows[0]) != CPP_FIELDS:
        raise RuntimeError(f"unexpected microbenchmark output:\n{result.stdout}")
    row: Dict[str, object] = dict(rows[0])
    expected_bytes = MEMORY_FUNCTIONS[backend](keys)
    if int(str(row["filter_bytes"])) != expected_bytes:
        raise RuntimeError(
            f"{backend} reported {row['filter_bytes']} bytes; sizing model expected {expected_bytes}"
        )
    row.update(
        {
            "point_labels": labels,
            "bytes_per_build_key": f"{expected_bytes / keys:.6f}",
            "smallest_cache_fit": smallest_cache_fit(expected_bytes, hierarchy),
            "cpu": args.cpu,
            "affinity": "none" if args.no_affinity else f"taskset CPU {args.cpu}",
            "cache_source": hierarchy.source,
            "l1d_bytes": hierarchy.l1d_bytes,
            "l2_bytes": hierarchy.l2_bytes,
            "l3_bytes": hierarchy.l3_bytes,
            "warmups": args.warmups,
            "seed": args.seed,
        }
    )
    return row


def smallest_cache_fit(filter_bytes: int, hierarchy: CacheHierarchy) -> str:
    if filter_bytes <= hierarchy.l1d_bytes:
        return "L1d"
    if filter_bytes <= hierarchy.l2_bytes:
        return "L2"
    if filter_bytes <= hierarchy.l3_bytes:
        return "L3"
    return "memory"


def write_results(rows: Iterable[Dict[str, object]], output: pathlib.Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_name(f".{output.name}.tmp")
    try:
        with temporary.open("w", encoding="utf-8", newline="") as destination:
            writer = csv.DictWriter(destination, fieldnames=CSV_FIELDS)
            writer.writeheader()
            writer.writerows(rows)
        temporary.replace(output)
    finally:
        if temporary.exists():
            temporary.unlink()


def print_design(points: Sequence[Tuple[str, int, str]], hierarchy: CacheHierarchy) -> None:
    print(
        f"Cache hierarchy ({hierarchy.source}): "
        f"L1d={hierarchy.l1d_bytes / MIB:.6f} MiB, "
        f"L2={hierarchy.l2_bytes / MIB:.6f} MiB, "
        f"L3={hierarchy.l3_bytes / MIB:.6f} MiB"
    )
    print("backend\tbuild_keys\tfilter_mib\tboundary_points")
    for backend, keys, labels in points:
        print(f"{backend}\t{keys}\t{MEMORY_FUNCTIONS[backend](keys) / MIB:.6f}\t{labels}")


def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cpu", type=int, default=0, help="one logical CPU to pin")
    parser.add_argument(
        "--cache-sizes-mib",
        type=float,
        nargs=3,
        metavar=("L1D", "L2", "L3"),
        help="verified per-instance cache sizes; default reads Linux sysfs for --cpu",
    )
    parser.add_argument("--probe-count", type=int, default=20_000_000)
    parser.add_argument("--hit-rate", type=float, default=0.5)
    parser.add_argument("--warmups", type=int, default=1)
    parser.add_argument("--repetitions", type=int, default=9)
    parser.add_argument("--seed", type=int, default=15)
    parser.add_argument("--timeout", type=int, default=7200, help="seconds per size/backend")
    parser.add_argument("--no-affinity", action="store_true", help="development smoke tests only")
    parser.add_argument("--taskset", default="taskset")
    parser.add_argument("--cxx", default=os.environ.get("CXX", "c++"))
    parser.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    parser.add_argument("--rebuild", action="store_true")
    parser.add_argument("--dry-run", action="store_true", help="print sizes without compiling/running")
    parser.add_argument("--output", type=pathlib.Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args(argv)
    if args.cpu < 0:
        parser.error("--cpu must be non-negative")
    if args.probe_count < 1:
        parser.error("--probe-count must be positive")
    if not 0 <= args.hit_rate <= 1:
        parser.error("--hit-rate must be between 0 and 1")
    if args.warmups < 0 or args.repetitions < 1:
        parser.error("--warmups must be non-negative and --repetitions positive")
    if args.timeout < 1:
        parser.error("--timeout must be positive")
    return args


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parse_args(argv)
    hierarchy = selected_cache_hierarchy(args)
    points = cache_boundary_points(hierarchy)
    print_design(points, hierarchy)
    if args.dry_run:
        return 0

    binary = compile_binary(args)
    execution_points = list(points)
    random.Random(args.seed).shuffle(execution_points)
    rows = [
        run_point(args, binary, hierarchy, backend, keys, labels)
        for backend, keys, labels in execution_points
    ]
    rows.sort(
        key=lambda row: (
            str(row["backend"]),
            int(str(row["filter_bytes"])),
            int(str(row["build_keys"])),
        )
    )
    output = args.output.expanduser().resolve()
    write_results(rows, output)
    print(f"Cache comparison CSV: {output}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, ValueError) as error:
        print(f"Error: {error}", file=sys.stderr)
        raise SystemExit(1)
