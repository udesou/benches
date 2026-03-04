#!/usr/bin/env bash
# sequence_cps.build.sh — builds sequence_cps benchmark binary.
set -euo pipefail

: "${OCAML_EXECUTABLE:?OCAML_EXECUTABLE is required}"
OUT="${RUNNING_OCAML_OUTPUT:?RUNNING_OCAML_OUTPUT is required}"
SRC="${RUNNING_OCAML_BENCH_DIR}/sequence_cps.ml"
OCAMLOPT="$(dirname "$OCAML_EXECUTABLE")/ocamlopt"

mkdir -p "$(dirname "$OUT")"
"$OCAMLOPT" -O3 "$SRC" -o "$OUT"
chmod +x "$OUT"
