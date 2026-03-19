#!/usr/bin/env bash
set -euo pipefail

: "${OCAML_EXECUTABLE:?OCAML_EXECUTABLE is required}"
OUT="${RUNNING_OCAML_OUTPUT:?RUNNING_OCAML_OUTPUT is required}"
BENCH_DIR="${RUNNING_OCAML_BENCH_DIR:?RUNNING_OCAML_BENCH_DIR is required}"
SRC="${BENCH_DIR}/big_array_bench.ml"

OCAML_BIN_DIR="$(dirname "${OCAML_EXECUTABLE}")"
OCAMLOPT="${OCAML_BIN_DIR}/ocamlopt"

[[ -x "${OCAMLOPT}" ]] || { echo "ocamlopt not found at ${OCAMLOPT}" >&2; exit 1; }
[[ -f "${SRC}" ]]      || { echo "Source not found: ${SRC}" >&2; exit 1; }

mkdir -p "$(dirname "${OUT}")"
# bigarray is bundled into stdlib in OCaml >= 5.0; link it explicitly only
# when the stub library exists (OCaml 4.x).
STDLIB_DIR="$("${OCAMLOPT}" -where)"
if [[ -f "${STDLIB_DIR}/bigarray.cmxa" ]]; then
  BIGARRAY_FLAGS="-I +bigarray bigarray.cmxa"
else
  BIGARRAY_FLAGS=""
fi
# shellcheck disable=SC2086
"${OCAMLOPT}" -O3 ${BIGARRAY_FLAGS} "${SRC}" -o "${OUT}"
chmod +x "${OUT}"
echo "Built ${OUT} using ${OCAMLOPT}" >&2
