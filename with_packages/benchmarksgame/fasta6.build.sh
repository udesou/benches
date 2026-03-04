#!/usr/bin/env bash
# fasta6.build.sh — builds fasta6 benchmark binary.
#
# Required opam packages: zarith
#
# Package auto-install behaviour (no manual setup needed):
#   1. If OPAM_SWITCH is set (via build_env): uses that switch directly.
#   2. If the compiler lives under ~/.opam/<switch>/: installs into it.
#   3. External/custom compiler: auto-creates a per-version opam switch using
#      a minimal local repo so any version string (release or dev) is accepted.
set -euo pipefail

if [[ -z "${OCAML_EXECUTABLE:-}" ]]; then
  echo "OCAML_EXECUTABLE is required" >&2; exit 1
fi

BENCH_DIR="${RUNNING_OCAML_BENCH_DIR:-$(pwd)}"
OUT="${RUNNING_OCAML_OUTPUT:-${BENCH_DIR}/fasta6-${RUNNING_OCAML_RUNTIME_NAME:-runtime}}"
OCAML_BIN_DIR="$(dirname "${OCAML_EXECUTABLE}")"

# Set PATH early so opam and dune see the right compiler.
export PATH="${OCAML_BIN_DIR}:${PATH}"

# --- Auto-install required opam packages -----------------------------------
_opam_auto_install() {
  local pkgs="zarith"

  if ! command -v opam >/dev/null 2>&1; then
    echo "opam not found; skipping auto-install. Pre-install manually: ${pkgs}" >&2
    return 0
  fi

  local opam_root
  opam_root="$(opam var root 2>/dev/null)" || opam_root="${OPAM_ROOT:-${HOME}/.opam}"
  local switch=""

  if [[ -n "${OPAM_SWITCH:-}" ]]; then
    # 1. Explicit override ---------------------------------------------------
    switch="${OPAM_SWITCH}"
    if ! opam switch list --short 2>/dev/null | grep -qx "${switch}"; then
      echo "ERROR: OPAM_SWITCH='${switch}' does not exist." >&2; exit 1
    fi

  else
    case "${OCAML_EXECUTABLE}" in
      "${opam_root}"/*/bin/ocaml)
        # 2. Compiler is already in an opam switch ---------------------------
        local rel="${OCAML_EXECUTABLE#${opam_root}/}"
        switch="${rel%%/*}"
        ;;
      *)
        # 3. External/custom compiler ----------------------------------------
        # Derive a stable switch name from (canonical path, version).
        local vnum canonical switch_id
        vnum="$("${OCAML_EXECUTABLE}" -vnum 2>/dev/null)"
        canonical="$(readlink -f "${OCAML_EXECUTABLE}")"
        switch_id="$(printf '%s\n%s\n' "${canonical}" "${vnum}" | md5sum | cut -c1-12)"
        switch="ext-${switch_id}"

        if ! opam switch list --short 2>/dev/null | grep -qx "${switch}"; then
          echo "External compiler: ${OCAML_EXECUTABLE} (OCaml ${vnum})" >&2
          echo "Creating opam switch '${switch}' for this compiler..." >&2

          # Create a minimal local opam repo with a virtual ocaml-system package
          # pinned to this exact version.  The switch is tied to this compiler
          # via its hash-derived name, so no availability guard is needed.
          local localrepo="${opam_root}/ext-compiler-repo"

          mkdir -p "${localrepo}"
          printf 'opam-version: "2.0"\n' > "${localrepo}/repo"
          mkdir -p "${localrepo}/packages/ocaml-system/ocaml-system.${vnum}"
          printf 'opam-version: "2.0"\n'             > "${localrepo}/packages/ocaml-system/ocaml-system.${vnum}/opam"

          # Also provide the ocaml meta-package at this version so packages
          # that depend on 'ocaml >= X' can resolve it.
          mkdir -p "${localrepo}/packages/ocaml/ocaml.${vnum}"
          printf 'opam-version: "2.0"\ndepends: [("ocaml-base-compiler" {= "%s"} | "ocaml-system" {= "%s"}) "ocaml-config"]\n'             "${vnum}" "${vnum}" > "${localrepo}/packages/ocaml/ocaml.${vnum}/opam"

          # Register/refresh the local repo in opam's global index so the
          # switch creation sees the up-to-date package files.
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
  # Tell dune and ocamlfind where to find packages installed in this switch.
  export OCAMLPATH="${opam_root}/${switch}/lib${OCAMLPATH:+:${OCAMLPATH}}"
}
_opam_auto_install

# --- Locate dune -----------------------------------------------------------
if [[ -n "${DUNE_BIN:-}" ]]; then
  [[ -x "${DUNE_BIN}" ]] || { echo "DUNE_BIN not executable: ${DUNE_BIN}" >&2; exit 1; }
elif command -v dune >/dev/null 2>&1; then
  DUNE_BIN="$(command -v dune)"
elif [[ -x "${OCAML_BIN_DIR}/dune" ]]; then
  DUNE_BIN="${OCAML_BIN_DIR}/dune"
fi
[[ -n "${DUNE_BIN:-}" ]] || { echo "dune not found. Install it (opam install dune) or set DUNE_BIN." >&2; exit 1; }

# --- Validate compiler tools -----------------------------------------------
for tool in ocaml ocamlc ocamlopt ocamldep; do
  [[ -x "${OCAML_BIN_DIR}/${tool}" ]] || { echo "${tool} not found at ${OCAML_BIN_DIR}/${tool}" >&2; exit 1; }
done

ACTIVE_OCAML="$(command -v ocaml)"
if [[ "$(readlink -f "${ACTIVE_OCAML}")" != "$(readlink -f "${OCAML_EXECUTABLE}")" ]]; then
  echo "Compiler mismatch: active ocaml is ${ACTIVE_OCAML}, expected ${OCAML_EXECUTABLE}" >&2; exit 1
fi

RUNTIME_TAG="${RUNNING_OCAML_RUNTIME_NAME:-runtime}"
RUNTIME_TAG="${RUNTIME_TAG//[^a-zA-Z0-9._-]/_}"
BUILD_DIR="${BENCH_DIR}/_build-running/${RUNTIME_TAG}"

mkdir -p "$(dirname "${BUILD_DIR}")"
mkdir -p "$(dirname "${OUT}")"
"${DUNE_BIN}" build --root "${BENCH_DIR}" --build-dir "${BUILD_DIR}" --profile release fasta6.exe
cp "${BUILD_DIR}/default/fasta6.exe" "${OUT}"
chmod +x "${OUT}"
echo "Built ${OUT} using compiler tools from ${OCAML_BIN_DIR} via ${DUNE_BIN}" >&2
