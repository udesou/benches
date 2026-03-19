#!/usr/bin/env bash
# globroots_seq.build.sh — builds the globroots_seq benchmark binary.
#
# Source: sandmark benchmarks/multicore-gcroots/
# Deps: C stub (globrootsprim.c) via dune foreign_stubs; OCaml >= 5 required.
set -euo pipefail

if [[ -z "${OCAML_EXECUTABLE:-}" ]]; then
  echo "OCAML_EXECUTABLE is required (path to the selected ocaml binary)" >&2
  exit 1
fi

BENCH_DIR="${RUNNING_OCAML_BENCH_DIR:-$(pwd)}"
OUT="${RUNNING_OCAML_OUTPUT:-${BENCH_DIR}/globroots_seq-${RUNNING_OCAML_RUNTIME_NAME:-runtime}}"
OCAML_BIN_DIR="$(dirname "${OCAML_EXECUTABLE}")"

# --- Locate dune ------------------------------------------------------------
if [[ -n "${DUNE_BIN:-}" ]]; then
  [[ -x "${DUNE_BIN}" ]] || { echo "DUNE_BIN not executable: ${DUNE_BIN}" >&2; exit 1; }
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
[[ -n "${DUNE_BIN:-}" ]] || { echo "dune not found. Install it or set DUNE_BIN." >&2; exit 1; }

# --- Validate compiler tools ------------------------------------------------
for tool in ocaml ocamlc ocamlopt ocamldep; do
  [[ -x "${OCAML_BIN_DIR}/${tool}" ]] || { echo "${tool} not found at ${OCAML_BIN_DIR}/${tool}" >&2; exit 1; }
done

export PATH="${OCAML_BIN_DIR}:${PATH}"
ACTIVE_OCAML="$(command -v ocaml)"
if [[ "$(readlink -f "${ACTIVE_OCAML}")" != "$(readlink -f "${OCAML_EXECUTABLE}")" ]]; then
  echo "Compiler mismatch: active ocaml is ${ACTIVE_OCAML}, expected ${OCAML_EXECUTABLE}" >&2; exit 1
fi

RUNTIME_TAG="${RUNNING_OCAML_RUNTIME_NAME:-runtime}"
RUNTIME_TAG="${RUNTIME_TAG//[^a-zA-Z0-9._-]/_}"
BUILD_DIR="${BENCH_DIR}/_build-running/${RUNTIME_TAG}"

mkdir -p "$(dirname "${BUILD_DIR}")"
mkdir -p "$(dirname "${OUT}")"
"${DUNE_BIN}" build --root "${BENCH_DIR}" --build-dir "${BUILD_DIR}" --profile release globroots_seq.exe
cp "${BUILD_DIR}/default/globroots_seq.exe" "${OUT}"
chmod +x "${OUT}"
echo "Built ${OUT} using compiler tools from ${OCAML_BIN_DIR} via ${DUNE_BIN}" >&2
