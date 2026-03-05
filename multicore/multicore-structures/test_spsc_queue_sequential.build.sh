#!/usr/bin/env bash
# test_spsc_queue_sequential.build.sh
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

if [[ ! -f "${BENCH_DIR}/test_spsc_queue_sequential.ml" ]]; then
  echo "Source not found: ${BENCH_DIR}/test_spsc_queue_sequential.ml" >&2; exit 1
fi

mkdir -p "$(dirname "${OUT}")"
cd "${BENCH_DIR}"
"${OCAMLOPT}" -O3 -I +unix unix.cmxa spsc_queue.ml test_spsc_queue_sequential.ml -o "${OUT}"
chmod +x "${OUT}"
echo "Built ${OUT} using ${OCAMLOPT}" >&2
