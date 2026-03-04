#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${OCAML_EXECUTABLE:-}" ]]; then
  echo "OCAML_EXECUTABLE is required (path to the ocaml binary)" >&2
  exit 1
fi

BENCH_DIR="${RUNNING_OCAML_BENCH_DIR:-$(pwd)}"
SRC="${BENCH_DIR}/fannkuchredux.ml"
OUT="${RUNNING_OCAML_OUTPUT:-${BENCH_DIR}/fannkuchredux.opt}"

OCAML_BIN_DIR="$(dirname "${OCAML_EXECUTABLE}")"
OCAMLOPT="${OCAML_BIN_DIR}/ocamlopt"

if [[ ! -x "${OCAMLOPT}" ]]; then
  echo "ocamlopt not found at ${OCAMLOPT}" >&2
  exit 1
fi
if [[ ! -f "${SRC}" ]]; then
  echo "Source not found: ${SRC}" >&2
  exit 1
fi

mkdir -p "$(dirname "${OUT}")"
# sandmark uses -noassert -unsafe for this benchmark
"${OCAMLOPT}" -O3 -noassert -unsafe "${SRC}" -o "${OUT}"
chmod +x "${OUT}"

echo "Built ${OUT} using ${OCAMLOPT}" >&2
