#!/usr/bin/env bash
# game_of_life_multicore.build.sh — requires domainslib
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
# Required: ocamlfind domainslib
#
# Behaviour (no manual setup needed):
#   1. If OPAM_SWITCH is set (via build_env): uses that switch directly.
#   2. If the compiler lives under ~/.opam/<switch>/: installs into it.
#   3. External/custom compiler: auto-creates a per-version opam switch using
#      a minimal local repo so any version string (release or dev) is accepted.
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

if [[ ! -f "${BENCH_DIR}/game_of_life_multicore.ml" ]]; then
  echo "Source not found: ${BENCH_DIR}/game_of_life_multicore.ml" >&2; exit 1
fi

mkdir -p "$(dirname "${OUT}")"
"${OCAMLFIND}" ocamlopt -O3 -package domainslib -linkpkg "${BENCH_DIR}/game_of_life_multicore.ml" -o "${OUT}"
chmod +x "${OUT}"
echo "Built ${OUT} using ${OCAMLFIND}" >&2
