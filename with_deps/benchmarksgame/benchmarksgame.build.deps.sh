#!/usr/bin/env bash
# benchmarksgame.build.deps.sh — generates FASTA input files using fasta3.exe.
#
# Called by each benchmark's build script when input data does not yet exist.
# Both input files are independent of the OCaml runtime version, so they are
# generated once and shared across all runtime builds.
#
# Required env vars (inherited from the parent build script):
#   OCAML_EXECUTABLE, RUNNING_OCAML_BENCH_DIR, DUNE_BIN (optional)
set -euo pipefail

BENCH_DIR="${RUNNING_OCAML_BENCH_DIR:-$(pwd)}"
INPUT_25M="${BENCH_DIR}/input25000000.txt"
INPUT_5M="${BENCH_DIR}/input5000000.txt"

if [[ -f "${INPUT_25M}" && -f "${INPUT_5M}" ]]; then
  echo "Input files already exist; skipping generation." >&2
  exit 0
fi

if [[ -z "${OCAML_EXECUTABLE:-}" ]]; then
  echo "OCAML_EXECUTABLE is required" >&2
  exit 1
fi

OCAML_BIN_DIR="$(dirname "${OCAML_EXECUTABLE}")"

# Locate dune (same resolution order as the main build scripts).
if [[ -n "${DUNE_BIN:-}" ]]; then
  if [[ ! -x "${DUNE_BIN}" ]]; then
    echo "DUNE_BIN is set but not executable: ${DUNE_BIN}" >&2
    exit 1
  fi
elif command -v dune >/dev/null 2>&1; then
  DUNE_BIN="$(command -v dune)"
elif [[ -x "${OCAML_BIN_DIR}/dune" ]]; then
  DUNE_BIN="${OCAML_BIN_DIR}/dune"
elif [[ "${OCAML_EXECUTABLE}" == /home/*/.opam/*/bin/ocaml ]]; then
  OPAM_SWITCH_BIN="$(dirname "${OCAML_EXECUTABLE}")"
  if [[ -x "${OPAM_SWITCH_BIN}/dune" ]]; then
    DUNE_BIN="${OPAM_SWITCH_BIN}/dune"
  fi
fi

if [[ -z "${DUNE_BIN:-}" ]]; then
  echo "dune not found. Install it or set DUNE_BIN." >&2
  exit 1
fi

RUNTIME_TAG="${RUNNING_OCAML_RUNTIME_NAME:-runtime}"
RUNTIME_TAG="${RUNTIME_TAG//[^a-zA-Z0-9._-]/_}"
BUILD_DIR="${BENCH_DIR}/_build-running/${RUNTIME_TAG}"

export PATH="${OCAML_BIN_DIR}:${PATH}"

mkdir -p "$(dirname "${BUILD_DIR}")"
"${DUNE_BIN}" build --root "${BENCH_DIR}" --build-dir "${BUILD_DIR}" --profile release fasta3.exe

FASTA3="${BUILD_DIR}/default/fasta3.exe"

if [[ ! -f "${INPUT_25M}" ]]; then
  echo "Generating input25000000.txt (25M nucleotides)..." >&2
  "${FASTA3}" 25000000 > "${INPUT_25M}"
  echo "Generated ${INPUT_25M}" >&2
fi

if [[ ! -f "${INPUT_5M}" ]]; then
  echo "Generating input5000000.txt (5M nucleotides)..." >&2
  "${FASTA3}" 5000000 > "${INPUT_5M}"
  echo "Generated ${INPUT_5M}" >&2
fi
