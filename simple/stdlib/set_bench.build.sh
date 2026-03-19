#!/usr/bin/env bash
set -euo pipefail

: "${OCAML_EXECUTABLE:?OCAML_EXECUTABLE is required}"
OUT="${RUNNING_OCAML_OUTPUT:?RUNNING_OCAML_OUTPUT is required}"
BENCH_DIR="${RUNNING_OCAML_BENCH_DIR:?RUNNING_OCAML_BENCH_DIR is required}"
SRC="${BENCH_DIR}/set_bench.ml"

OCAML_BIN_DIR="$(dirname "${OCAML_EXECUTABLE}")"
OCAMLOPT="${OCAML_BIN_DIR}/ocamlopt"

[[ -x "${OCAMLOPT}" ]] || { echo "ocamlopt not found at ${OCAMLOPT}" >&2; exit 1; }
[[ -f "${SRC}" ]]      || { echo "Source not found: ${SRC}" >&2; exit 1; }

mkdir -p "$(dirname "${OUT}")"
"${OCAMLOPT}" -O3 "${SRC}" -o "${OUT}"
chmod +x "${OUT}"
echo "Built ${OUT} using ${OCAMLOPT}" >&2
