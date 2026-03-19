#!/usr/bin/env bash
# msort_ints.build.sh — builds the mpl/msort_ints benchmark binary.
#
# Source: sandmark benchmarks/mpl/bench/msort_ints/
# Deps: domainslib (via Forkjoin library); OCaml >= 5 required.
set -euo pipefail

if [[ -z "${OCAML_EXECUTABLE:-}" ]]; then
  echo "OCAML_EXECUTABLE is required (path to the selected ocaml binary)" >&2
  exit 1
fi

BENCH_DIR="${RUNNING_OCAML_BENCH_DIR:-$(pwd)}"
OUT="${RUNNING_OCAML_OUTPUT:-${BENCH_DIR}/msort_ints-${RUNNING_OCAML_RUNTIME_NAME:-runtime}}"
OCAML_BIN_DIR="$(dirname "${OCAML_EXECUTABLE}")"

# --- Auto-install domainslib --------------------------------------------------
export PATH="${OCAML_BIN_DIR}:${PATH}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_OPAM_PKGS="domainslib"
source "${SCRIPT_DIR}/../../lib/opam_auto_install.sh"
_opam_auto_install

# --- Locate dune --------------------------------------------------------------
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

# --- Validate compiler tools --------------------------------------------------
for tool in ocaml ocamlc ocamlopt ocamldep; do
  if [[ ! -x "${OCAML_BIN_DIR}/${tool}" ]]; then
    echo "Expected ${tool} at ${OCAML_BIN_DIR}/${tool}, but it was not found." >&2
    exit 1
  fi
done

ACTIVE_OCAML="$(command -v ocaml)"
if [[ "$(readlink -f "${ACTIVE_OCAML}")" != "$(readlink -f "${OCAML_EXECUTABLE}")" ]]; then
  echo "Compiler mismatch: active ocaml is ${ACTIVE_OCAML}, expected ${OCAML_EXECUTABLE}" >&2
  exit 1
fi

RUNTIME_TAG="${RUNNING_OCAML_RUNTIME_NAME:-runtime}"
RUNTIME_TAG="${RUNTIME_TAG//[^a-zA-Z0-9._-]/_}"
BUILD_DIR="${BENCH_DIR}/_build-running/${RUNTIME_TAG}"

# --- Build msort_ints ---------------------------------------------------------
mkdir -p "$(dirname "${BUILD_DIR}")"
mkdir -p "$(dirname "${OUT}")"
"${DUNE_BIN}" build --root "${BENCH_DIR}" --build-dir "${BUILD_DIR}" --profile release msort_ints.exe
cp "${BUILD_DIR}/default/msort_ints.exe" "${OUT}"
chmod +x "${OUT}"

echo "Built ${OUT} using compiler tools from ${OCAML_BIN_DIR} via ${DUNE_BIN}" >&2
