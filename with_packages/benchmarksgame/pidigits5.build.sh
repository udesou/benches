#!/usr/bin/env bash
# pidigits5.build.sh — builds pidigits5 benchmark binary.
#
# Required opam packages: zarith
set -euo pipefail

if [[ -z "${OCAML_EXECUTABLE:-}" ]]; then
  echo "OCAML_EXECUTABLE is required" >&2; exit 1
fi

BENCH_DIR="${RUNNING_OCAML_BENCH_DIR:-$(pwd)}"
OUT="${RUNNING_OCAML_OUTPUT:-${BENCH_DIR}/pidigits5-${RUNNING_OCAML_RUNTIME_NAME:-runtime}}"
OCAML_BIN_DIR="$(dirname "${OCAML_EXECUTABLE}")"

# Set PATH early so opam and dune see the right compiler.
export PATH="${OCAML_BIN_DIR}:${PATH}"

# --- Auto-install required opam packages -----------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_OPAM_PKGS="zarith"
source "${SCRIPT_DIR}/../../lib/opam_auto_install.sh"
_opam_auto_install

# --- Locate dune -----------------------------------------------------------
if [[ -n "${DUNE_BIN:-}" ]]; then
  [[ -x "${DUNE_BIN}" ]] || { echo "DUNE_BIN not executable: ${DUNE_BIN}" >&2; exit 1; }
elif command -v dune >/dev/null 2>&1; then
  DUNE_BIN="$(command -v dune)"
elif [[ -x "${OCAML_BIN_DIR}/dune" ]]; then
  DUNE_BIN="${OCAML_BIN_DIR}/dune"
fi
[[ -n "${DUNE_BIN:-}" ]] || { echo "dune not found. Install it (opam install dune) or set DUNE_BIN." >&2; exit 1; }

# --- Validate compiler tools -----------------------------------------------
for tool in ocaml ocamlc ocamlopt ocamldep; do
  [[ -x "${OCAML_BIN_DIR}/${tool}" ]] || { echo "${tool} not found at ${OCAML_BIN_DIR}/${tool}" >&2; exit 1; }
done

ACTIVE_OCAML="$(command -v ocaml)"
if [[ "$(readlink -f "${ACTIVE_OCAML}")" != "$(readlink -f "${OCAML_EXECUTABLE}")" ]]; then
  echo "Compiler mismatch: active ocaml is ${ACTIVE_OCAML}, expected ${OCAML_EXECUTABLE}" >&2; exit 1
fi

RUNTIME_TAG="${RUNNING_OCAML_RUNTIME_NAME:-runtime}"
RUNTIME_TAG="${RUNTIME_TAG//[^a-zA-Z0-9._-]/_}"
BUILD_DIR="${BENCH_DIR}/_build-running/${RUNTIME_TAG}"

mkdir -p "$(dirname "${BUILD_DIR}")"
mkdir -p "$(dirname "${OUT}")"
"${DUNE_BIN}" build --root "${BENCH_DIR}" --build-dir "${BUILD_DIR}" --profile release pidigits5.exe
cp "${BUILD_DIR}/default/pidigits5.exe" "${OUT}"
chmod +x "${OUT}"
echo "Built ${OUT} using compiler tools from ${OCAML_BIN_DIR} via ${DUNE_BIN}" >&2
