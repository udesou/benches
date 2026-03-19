#!/usr/bin/env bash
# test_sched.build.sh — builds test_sched benchmark binary.
#
# Required opam packages: saturn_lockfree
set -euo pipefail

if [[ -z "${OCAML_EXECUTABLE:-}" ]]; then
  echo "OCAML_EXECUTABLE is required" >&2; exit 1
fi

BENCH_DIR="${RUNNING_OCAML_BENCH_DIR:-$(pwd)}"
OUT="${RUNNING_OCAML_OUTPUT:-${BENCH_DIR}/test_sched-${RUNNING_OCAML_RUNTIME_NAME:-runtime}}"
OCAML_BIN_DIR="$(dirname "${OCAML_EXECUTABLE}")"

export PATH="${OCAML_BIN_DIR}:${PATH}"

# --- Auto-install required opam packages -----------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_OPAM_PKGS="saturn_lockfree"
source "${SCRIPT_DIR}/../../lib/opam_auto_install.sh"
_opam_auto_install

# --- Locate ocamlfind -------------------------------------------------------
OCAMLFIND="${OCAML_BIN_DIR}/ocamlfind"
if [[ ! -x "${OCAMLFIND}" ]]; then
  OCAMLFIND="$(command -v ocamlfind 2>/dev/null || true)"
fi
[[ -n "${OCAMLFIND:-}" && -x "${OCAMLFIND}" ]] || {
  echo "ocamlfind not found" >&2; exit 1
}

mkdir -p "$(dirname "${OUT}")"
cd "${BENCH_DIR}"

"${OCAMLFIND}" ocamlopt -O3 \
  -package saturn_lockfree -linkpkg \
  ms_sched.mli ms_sched.ml test_sched.ml \
  -o "${OUT}"
chmod +x "${OUT}"
echo "Built ${OUT} using ${OCAMLFIND}" >&2
