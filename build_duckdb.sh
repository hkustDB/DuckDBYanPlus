#!/usr/bin/env bash

set -euo pipefail

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
BUILD_TYPE=${BUILD_TYPE:-Release}
CMAKE_GENERATOR_NAME=${CMAKE_GENERATOR:-"Unix Makefiles"}
DUCKDB_EXPERIMENT_VERSION=${DUCKDB_EXPERIMENT_VERSION:-v1.5.0-yanplus}
YANPLUS_FRESH_BUILD=${YANPLUS_FRESH_BUILD:-0}

case "${CMAKE_GENERATOR_NAME}" in
Ninja | "Unix Makefiles")
    ;;
*)
    echo "Error: supported generators are 'Ninja' and 'Unix Makefiles'; got '${CMAKE_GENERATOR_NAME}'." >&2
    exit 1
    ;;
esac
case "${YANPLUS_FRESH_BUILD}" in
0 | 1)
    ;;
*)
    echo "Error: YANPLUS_FRESH_BUILD must be 0 or 1." >&2
    exit 1
    ;;
esac
for cmake_argument in "$@"; do
    if [[ "${cmake_argument}" != -D* ]]; then
        echo "Error: common CMake arguments must use -DNAME=VALUE; got '${cmake_argument}'." >&2
        exit 1
    fi
done

if [[ -n ${BUILD_JOBS:-} ]]; then
    JOBS=${BUILD_JOBS}
elif command -v nproc >/dev/null 2>&1; then
    JOBS=$(nproc)
elif command -v sysctl >/dev/null 2>&1; then
    JOBS=$(sysctl -n hw.ncpu)
else
    JOBS=1
fi

if ! [[ "${JOBS}" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: BUILD_JOBS must be a positive integer, got '${JOBS}'." >&2
    exit 1
fi
if ! command -v cmake >/dev/null 2>&1; then
    echo "Error: cmake is required." >&2
    exit 1
fi
if [[ "${CMAKE_GENERATOR_NAME}" == Ninja ]] && ! command -v ninja >/dev/null 2>&1; then
    echo "Error: Ninja is not installed. Install Ninja or omit CMAKE_GENERATOR to use Unix Makefiles." >&2
    exit 1
fi
if [[ "${CMAKE_GENERATOR_NAME}" == "Unix Makefiles" ]] && ! command -v make >/dev/null 2>&1; then
    echo "Error: make is required for the Unix Makefiles generator." >&2
    exit 1
fi

if [[ "${YANPLUS_FRESH_BUILD}" == 1 ]]; then
    echo "Removing the two dedicated variant caches"
    cmake -E remove_directory "${SCRIPT_PATH}/build/duckdb_origin"
    cmake -E remove_directory "${SCRIPT_PATH}/build/duckdb_YanPlus"
fi

configure_and_build() {
    local label=$1
    local yanplus_enabled=$2
    shift 2
    local build_dir="${SCRIPT_PATH}/build/${label}"
    local cmake_command=(cmake -S "${SCRIPT_PATH}" -B "${build_dir}" -G "${CMAKE_GENERATOR_NAME}")
    cmake_command+=(
        -DCMAKE_BUILD_TYPE="${BUILD_TYPE}"
        -DBUILD_UNITTESTS=OFF
        -DBUILD_BENCHMARKS=OFF
    )

    echo "Configuring ${label} (ENABLE_YANPLUS=${yanplus_enabled})"
    "${cmake_command[@]}" "$@" \
        -DDUCKDB_EXPLICIT_VERSION="${DUCKDB_EXPERIMENT_VERSION}" \
        -DENABLE_YANPLUS="${yanplus_enabled}"

    echo "Building ${label} with ${JOBS} jobs"
    CMAKE_BUILD_PARALLEL_LEVEL="${JOBS}" cmake --build "${build_dir}" --target shell
}

# Extra command-line arguments are common CMake options and are deliberately
# applied to both builds so ENABLE_YANPLUS is their only configuration delta.
configure_and_build duckdb_origin OFF "$@"
configure_and_build duckdb_YanPlus ON "$@"

ORIGIN_BIN="${SCRIPT_PATH}/build/duckdb_origin/duckdb"
YANPLUS_BIN="${SCRIPT_PATH}/build/duckdb_YanPlus/duckdb"
ORIGIN_SETTING_COUNT=$("${ORIGIN_BIN}" -csv -noheader \
    -c "SELECT count(*) FROM duckdb_settings() WHERE name = 'yanplus_enable';" | tr -d '\r')
YANPLUS_SETTING_COUNT=$("${YANPLUS_BIN}" -csv -noheader \
    -c "SELECT count(*) FROM duckdb_settings() WHERE name = 'yanplus_enable';" | tr -d '\r')
YANPLUS_DEFAULTS=$("${YANPLUS_BIN}" -csv -noheader \
    -c "SELECT current_setting('yanplus_enable')::VARCHAR || '|' || current_setting('yanplus_semijoin_filter')::VARCHAR;" |
    tr -d '\r')
ORIGIN_VERSION=$("${ORIGIN_BIN}" -csv -noheader -c "SELECT version();" | tr -d '\r')
YANPLUS_VERSION=$("${YANPLUS_BIN}" -csv -noheader -c "SELECT version();" | tr -d '\r')

if [[ "${ORIGIN_SETTING_COUNT}" != 0 ]]; then
    echo "Error: origin build unexpectedly exposes yanplus_enable." >&2
    exit 1
fi
if [[ "${YANPLUS_SETTING_COUNT}" != 1 || "${YANPLUS_DEFAULTS}" != "true|BLOOM" ]]; then
    echo "Error: Yan+ build validation failed (${YANPLUS_SETTING_COUNT}, ${YANPLUS_DEFAULTS})." >&2
    exit 1
fi
if [[ "${ORIGIN_VERSION}" != "${DUCKDB_EXPERIMENT_VERSION}" ||
      "${YANPLUS_VERSION}" != "${DUCKDB_EXPERIMENT_VERSION}" ]]; then
    echo "Error: variant version mismatch (origin=${ORIGIN_VERSION}, Yan+=${YANPLUS_VERSION})." >&2
    exit 1
fi

echo
echo "Built and validated:"
echo "  origin: ${ORIGIN_BIN} (${ORIGIN_VERSION})"
echo "  Yan+:   ${YANPLUS_BIN} (${YANPLUS_VERSION}, enabled/BLOOM)"
