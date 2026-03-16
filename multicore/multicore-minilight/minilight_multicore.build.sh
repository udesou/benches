#!/usr/bin/env bash
# minilight_multicore.build.sh — requires domainslib
set -euo pipefail

: "${OCAML_EXECUTABLE:?OCAML_EXECUTABLE is required}"
OUT="${RUNNING_OCAML_OUTPUT:?RUNNING_OCAML_OUTPUT is required}"
BENCH_DIR="${RUNNING_OCAML_BENCH_DIR:?RUNNING_OCAML_BENCH_DIR is required}"

OCAML_BIN_DIR="$(dirname "${OCAML_EXECUTABLE}")"
export PATH="${OCAML_BIN_DIR}:${PATH}"
OCAMLOPT="${OCAML_BIN_DIR}/ocamlopt"

if [[ ! -x "${OCAMLOPT}" ]]; then
  echo "ocamlopt not found at ${OCAMLOPT}" >&2; exit 1
fi

# --- Auto-install required opam packages -----------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_OPAM_PKGS="ocamlfind domainslib"
source "${SCRIPT_DIR}/../../lib/opam_auto_install.sh"
_opam_auto_install

OCAMLFIND="$(command -v ocamlfind 2>/dev/null)" || {
  echo "ocamlfind not found. Install with: opam install ocamlfind domainslib" >&2; exit 1
}

if [[ ! -f "${BENCH_DIR}/minilight_multicore.ml" ]]; then
  echo "Source not found: ${BENCH_DIR}/minilight_multicore.ml" >&2; exit 1
fi

mkdir -p "$(dirname "${OUT}")"
cd "${BENCH_DIR}"
"${OCAMLFIND}" ocamlopt -O3 -package domainslib -linkpkg \
  vector3f.ml triangle.ml surfacePoint.ml spatialIndex.ml scene.ml image.ml rayTracer.ml camera.ml \
  minilight_multicore.ml -o "${OUT}"
chmod +x "${OUT}"
echo "Built ${OUT} using ${OCAMLFIND}" >&2
