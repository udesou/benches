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
# Required: ocamlfind domainslib
_opam_auto_install() {
  local pkgs="ocamlfind domainslib"

  if ! command -v opam >/dev/null 2>&1; then
    echo "opam not found; skipping auto-install. Pre-install manually: ${pkgs}" >&2
    return 0
  fi

  local opam_root
  opam_root="$(opam var root 2>/dev/null)" || opam_root="${OPAM_ROOT:-${HOME}/.opam}"
  local switch=""

  if [[ -n "${OPAM_SWITCH:-}" ]]; then
    switch="${OPAM_SWITCH}"
    if ! opam switch list --short 2>/dev/null | grep -qx "${switch}"; then
      echo "ERROR: OPAM_SWITCH='${switch}' does not exist." >&2; exit 1
    fi

  else
    case "${OCAML_EXECUTABLE}" in
      "${opam_root}"/*/bin/ocaml)
        local rel="${OCAML_EXECUTABLE#${opam_root}/}"
        switch="${rel%%/*}"
        ;;
      *)
        local vnum canonical switch_id
        vnum="$("${OCAML_EXECUTABLE}" -vnum 2>/dev/null)"
        canonical="$(readlink -f "${OCAML_EXECUTABLE}")"
        switch_id="$(printf '%s\n%s\n' "${canonical}" "${vnum}" | md5sum | cut -c1-12)"
        switch="ext-${switch_id}"

        if ! opam switch list --short 2>/dev/null | grep -qx "${switch}"; then
          echo "External compiler: ${OCAML_EXECUTABLE} (OCaml ${vnum})" >&2
          echo "Creating opam switch '${switch}' for this compiler..." >&2

          local localrepo="${opam_root}/ext-compiler-repo"
          mkdir -p "${localrepo}"
          printf 'opam-version: "2.0"\n' > "${localrepo}/repo"
          mkdir -p "${localrepo}/packages/ocaml-system/ocaml-system.${vnum}"
          printf 'opam-version: "2.0"\n' \
            > "${localrepo}/packages/ocaml-system/ocaml-system.${vnum}/opam"
          mkdir -p "${localrepo}/packages/ocaml/ocaml.${vnum}"
          printf 'opam-version: "2.0"\ndepends: [("ocaml-base-compiler" {= "%s"} | "ocaml-system" {= "%s"}) "ocaml-config"]\n' \
            "${vnum}" "${vnum}" \
            > "${localrepo}/packages/ocaml/ocaml.${vnum}/opam"

          if ! opam repository list --all 2>/dev/null | grep -qE '^[[:space:]]*ext-compiler[[:space:]]'; then
            opam repository add ext-compiler "${localrepo}" --rank 1 >&2
          else
            opam update ext-compiler >&2
          fi

          opam switch create "${switch}" \
            --packages "ocaml-system.${vnum}" \
            --repos "ext-compiler,default" \
            --no-switch --yes >&2
        fi
        ;;
    esac
  fi

  echo "Auto-installing [${pkgs}] into opam switch '${switch}'..." >&2
  opam install --switch "${switch}" --yes ${pkgs} >&2

  export PATH="${opam_root}/${switch}/bin:${PATH}"
  export PATH="${OCAML_BIN_DIR}:${PATH}"
  export OCAMLPATH="${opam_root}/${switch}/lib${OCAMLPATH:+:${OCAMLPATH}}"
}
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
