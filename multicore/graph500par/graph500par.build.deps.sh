#!/usr/bin/env bash
# graph500par.build.deps.sh — generates edges.data using a locally-built gen binary.
#
# Called by kernel1_run_multicore.build.sh when edges.data does not yet exist.
# edges.data is independent of the OCaml runtime version, so it is generated
# once and shared across all runtime builds.
#
# Required env vars:
#   OCAML_EXECUTABLE, RUNNING_OCAML_BENCH_DIR
set -euo pipefail

BENCH_DIR="${RUNNING_OCAML_BENCH_DIR:-$(pwd)}"
EDGES_DATA="${BENCH_DIR}/edges.data"

if [[ -f "${EDGES_DATA}" ]]; then
  echo "edges.data already exists at ${EDGES_DATA}; skipping generation." >&2
  exit 0
fi

: "${OCAML_EXECUTABLE:?OCAML_EXECUTABLE is required}"

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

# Build gen into a temporary directory, then use it to generate edges.data.
GEN_TMPDIR="$(mktemp -d)"
trap 'rm -rf "${GEN_TMPDIR}"' EXIT

GEN_BIN="${GEN_TMPDIR}/gen"
cd "${BENCH_DIR}"
"${OCAMLFIND}" ocamlopt -O3 -package domainslib,unix -linkpkg \
  graphTypes.ml sparseGraph.ml generate.ml gen.ml -o "${GEN_BIN}"

echo "Generating edges.data (scale=14, edgefactor=16)..." >&2
"${GEN_BIN}" -scale 14 -edgefactor 16 "${EDGES_DATA}"
echo "Generated ${EDGES_DATA}" >&2
