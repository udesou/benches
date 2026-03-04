#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${OCAML_EXECUTABLE:-}" ]]; then
  echo "OCAML_EXECUTABLE is required (path to the ocaml binary)" >&2
  exit 1
fi

BENCH_DIR="${RUNNING_OCAML_BENCH_DIR:-$(pwd)}"
SRC_DATASET="${BENCH_DIR}/naive_multilayer_dataset.ml"
SRC="${BENCH_DIR}/naive_multilayer.ml"
OUT="${RUNNING_OCAML_OUTPUT:-${BENCH_DIR}/naive_multilayer.opt}"

OCAML_BIN_DIR="$(dirname "${OCAML_EXECUTABLE}")"
OCAMLOPT="${OCAML_BIN_DIR}/ocamlopt"

if [[ ! -x "${OCAMLOPT}" ]]; then
  echo "ocamlopt not found at ${OCAMLOPT}" >&2
  exit 1
fi
for f in "${SRC_DATASET}" "${SRC}"; do
  if [[ ! -f "${f}" ]]; then
    echo "Source not found: ${f}" >&2
    exit 1
  fi
done

mkdir -p "$(dirname "${OUT}")"
# Dataset module must be compiled first; naive_multilayer.ml references Naive_multilayer_dataset.
"${OCAMLOPT}" -O3 "${SRC_DATASET}" "${SRC}" -o "${OUT}"
chmod +x "${OUT}"

echo "Built ${OUT} using ${OCAMLOPT}" >&2
