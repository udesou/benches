#!/usr/bin/env bash
# graph500seq.build.sh — builds the kernel1_run benchmark binary.
#
# Also invokes graph500seq.build.deps.sh to generate edges.data if it does not
# exist yet.  edges.data is runtime-independent (pure data), so it is generated
# once and reused across all OCaml version builds.
set -euo pipefail

if [[ -z "${OCAML_EXECUTABLE:-}" ]]; then
  echo "OCAML_EXECUTABLE is required (path to the selected ocaml binary)" >&2
  exit 1
fi

BENCH_DIR="${RUNNING_OCAML_BENCH_DIR:-$(pwd)}"
OUT="${RUNNING_OCAML_OUTPUT:-${BENCH_DIR}/graph500seq-${RUNNING_OCAML_RUNTIME_NAME:-runtime}}"
OCAML_BIN_DIR="$(dirname "${OCAML_EXECUTABLE}")"

# --- Locate dune -----------------------------------------------------------
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
  echo "dune not found." >&2
  echo "Install it, or set DUNE_BIN in benchmark build_env." >&2
  echo "  build_env: { DUNE_BIN: /path/to/dune }" >&2
  exit 1
fi

# --- Validate compiler tools -----------------------------------------------
for tool in ocaml ocamlc ocamlopt ocamldep; do
  if [[ ! -x "${OCAML_BIN_DIR}/${tool}" ]]; then
    echo "Expected ${tool} at ${OCAML_BIN_DIR}/${tool}, but it was not found." >&2
    exit 1
  fi
done

export PATH="${OCAML_BIN_DIR}:${PATH}"
ACTIVE_OCAML="$(command -v ocaml)"
if [[ "$(readlink -f "${ACTIVE_OCAML}")" != "$(readlink -f "${OCAML_EXECUTABLE}")" ]]; then
  echo "Compiler mismatch: active ocaml is ${ACTIVE_OCAML}, expected ${OCAML_EXECUTABLE}" >&2
  exit 1
fi

RUNTIME_TAG="${RUNNING_OCAML_RUNTIME_NAME:-runtime}"
RUNTIME_TAG="${RUNTIME_TAG//[^a-zA-Z0-9._-]/_}"
BUILD_DIR="${BENCH_DIR}/_build-running/${RUNTIME_TAG}"

# --- Generate edges.data if needed (runtime-independent, generated once) ---
export DUNE_BIN
"${BENCH_DIR}/graph500seq.build.deps.sh"

# --- Build kernel1_run -----------------------------------------------------
mkdir -p "$(dirname "${BUILD_DIR}")"
mkdir -p "$(dirname "${OUT}")"
"${DUNE_BIN}" build --root "${BENCH_DIR}" --build-dir "${BUILD_DIR}" --profile release kernel1_run.exe
cp "${BUILD_DIR}/default/kernel1_run.exe" "${OUT}"
chmod +x "${OUT}"

echo "Built ${OUT} using compiler tools from ${OCAML_BIN_DIR} via ${DUNE_BIN}" >&2
