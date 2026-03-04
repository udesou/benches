#!/usr/bin/env bash
# graph500seq.build.deps.sh — generates edges.data using gen.exe.
#
# Called by graph500seq.build.sh when edges.data does not yet exist.
# edges.data is independent of the OCaml runtime version, so it is generated
# once and shared across all runtime builds.
#
# Required env vars (inherited from the parent build script):
#   OCAML_EXECUTABLE, RUNNING_OCAML_BENCH_DIR, DUNE_BIN (optional)
set -euo pipefail

BENCH_DIR="${RUNNING_OCAML_BENCH_DIR:-$(pwd)}"
EDGES_DATA="${BENCH_DIR}/edges.data"

if [[ -f "${EDGES_DATA}" ]]; then
  echo "edges.data already exists at ${EDGES_DATA}; skipping generation." >&2
  exit 0
fi

if [[ -z "${OCAML_EXECUTABLE:-}" ]]; then
  echo "OCAML_EXECUTABLE is required" >&2
  exit 1
fi

OCAML_BIN_DIR="$(dirname "${OCAML_EXECUTABLE}")"

# Locate dune (same resolution order as the main build script).
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
"${DUNE_BIN}" build --root "${BENCH_DIR}" --build-dir "${BUILD_DIR}" --profile release gen.exe

GEN="${BUILD_DIR}/default/gen.exe"
echo "Generating edges.data (scale=21, edgefactor=16)..." >&2
"${GEN}" -scale 21 -edgefactor 16 "${EDGES_DATA}"
echo "Generated ${EDGES_DATA}" >&2
