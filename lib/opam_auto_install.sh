#!/usr/bin/env bash
# opam_auto_install.sh — shared helper for benchmark build scripts.
#
# Provides _opam_auto_install() which installs required opam packages for
# the benchmark's compiler.  Handles stock OCaml and OxCaml transparently.
#
# Usage from a build script:
#   OCAML_BIN_DIR="$(dirname "${OCAML_EXECUTABLE}")"
#   export PATH="${OCAML_BIN_DIR}:${PATH}"
#   _OPAM_PKGS="zarith"   # space-separated list
#   source "$(dirname "${BASH_SOURCE[0]}")/../../lib/opam_auto_install.sh"
#   _opam_auto_install
#
# The function honours:
#   OPAM_SWITCH          — explicit switch override (path 1)
#   OCAML_EXECUTABLE     — used to detect opam switch or create one (paths 2/3)
#   _OPAM_PKGS           — packages to install
#
# OxCaml compatibility:
#   OxCaml's extended type system (locality modes) breaks some ecosystem
#   packages (e.g. ocamlfind 1.9.8).  When the compiler version contains
#   "+ox", we add a stub ocamlfind to the local repo so opam doesn't try
#   to build the real one.  Instead we build ocamlfind from source using
#   a stock OCaml compiler and install it into the switch with the correct
#   findlib.conf paths.

# Prefer opam 2.3+ at /usr/local/bin (opam root may require it).
if [[ -x /usr/local/bin/opam ]]; then
  _OPAM_BIN=/usr/local/bin/opam
elif command -v opam >/dev/null 2>&1; then
  _OPAM_BIN="$(command -v opam)"
else
  _OPAM_BIN=""
fi
OPAM="${_OPAM_BIN}"

_opam_auto_install() {
  local pkgs="${_OPAM_PKGS:?_OPAM_PKGS must be set before calling _opam_auto_install}"

  if [[ -z "${OPAM}" ]]; then
    echo "opam not found; skipping auto-install. Pre-install manually: ${pkgs}" >&2
    return 0
  fi

  local ocaml_exe="${OCAML_EXECUTABLE:?OCAML_EXECUTABLE must be set}"
  local ocaml_bin_dir
  ocaml_bin_dir="$(dirname "${ocaml_exe}")"

  local opam_root
  opam_root="$("${OPAM}" var root 2>/dev/null)" || opam_root="${OPAM_ROOT:-${HOME}/.opam}"
  local switch=""
  local vnum=""

  if [[ -n "${OPAM_SWITCH:-}" ]]; then
    # --- Path 1: Explicit override -------------------------------------------
    switch="${OPAM_SWITCH}"
    if ! "${OPAM}" switch list --short 2>/dev/null | grep -qx "${switch}"; then
      echo "ERROR: OPAM_SWITCH='${switch}' does not exist." >&2; exit 1
    fi

  else
    case "${ocaml_exe}" in
      "${opam_root}"/*/bin/ocaml)
        # --- Path 2: Compiler is already in an opam switch --------------------
        local rel="${ocaml_exe#${opam_root}/}"
        switch="${rel%%/*}"
        ;;
      *)
        # --- Path 3: External/custom compiler ---------------------------------
        local canonical switch_id
        vnum="$("${ocaml_exe}" -vnum 2>/dev/null)"
        canonical="$(readlink -f "${ocaml_exe}")"
        switch_id="$(printf '%s\n%s\n' "${canonical}" "${vnum}" | md5sum | cut -c1-12)"
        switch="ext-${switch_id}"

        # --- Ensure local repo with virtual packages --------------------------
        local localrepo="${opam_root}/ext-compiler-repo"
        mkdir -p "${localrepo}"
        printf 'opam-version: "2.0"\n' > "${localrepo}/repo"

        # Virtual ocaml-system package for this exact version.
        mkdir -p "${localrepo}/packages/ocaml-system/ocaml-system.${vnum}"
        printf 'opam-version: "2.0"\n' \
          > "${localrepo}/packages/ocaml-system/ocaml-system.${vnum}/opam"

        # Virtual ocaml meta-package so "ocaml >= X" constraints resolve.
        mkdir -p "${localrepo}/packages/ocaml/ocaml.${vnum}"
        printf 'opam-version: "2.0"\ndepends: [("ocaml-base-compiler" {= "%s"} | "ocaml-system" {= "%s"}) "ocaml-config"]\n' \
          "${vnum}" "${vnum}" \
          > "${localrepo}/packages/ocaml/ocaml.${vnum}/opam"

        # --- OxCaml: stub ocamlfind in local repo -----------------------------
        # OxCaml's locality modes break ocamlfind's use of `ignore`.
        # Add a stub so opam doesn't try to build the real one.
        # We build a real ocamlfind binary separately below.
        if [[ "${vnum}" == *"+ox"* ]]; then
          echo "OxCaml detected (${vnum}): adding stub packages to local repo" >&2

          # Stub ocamlfind — real binary built from stock OCaml below.
          mkdir -p "${localrepo}/packages/ocamlfind/ocamlfind.1.9.8"
          cat > "${localrepo}/packages/ocamlfind/ocamlfind.1.9.8/opam" <<'STUBEOF'
opam-version: "2.0"
synopsis: "Stub ocamlfind for OxCaml — real binary built separately"
build: []
install: []
depends: ["ocaml"]
STUBEOF

          # Stub csexp — real library built with OxCaml below.
          mkdir -p "${localrepo}/packages/csexp/csexp.1.5.2"
          cat > "${localrepo}/packages/csexp/csexp.1.5.2/opam" <<'STUBEOF'
opam-version: "2.0"
synopsis: "Stub csexp for OxCaml — real library built separately"
build: []
install: []
depends: ["ocaml"]
STUBEOF

          # Stub dune and sub-packages — OxCaml's type system breaks dune's
          # build.  dune is already available on the system PATH so the stubs
          # just satisfy opam dependency resolution.
          local dune_ver="3.21.1"
          for dune_pkg in dune dune-configurator dune-private-libs dune-secondary; do
            mkdir -p "${localrepo}/packages/${dune_pkg}/${dune_pkg}.${dune_ver}"
            cat > "${localrepo}/packages/${dune_pkg}/${dune_pkg}.${dune_ver}/opam" <<DUNESTUB
opam-version: "2.0"
synopsis: "Stub ${dune_pkg} for OxCaml — real dune used from system PATH"
build: []
install: []
depends: ["ocaml"]
DUNESTUB
          done
        fi

        # Register/refresh the local repo (always, to pick up stub changes).
        if ! "${OPAM}" repository list --all 2>/dev/null | grep -qE '^[[:space:]]*ext-compiler[[:space:]]'; then
          "${OPAM}" repository add ext-compiler "${localrepo}" --rank 1 >&2
        else
          "${OPAM}" update ext-compiler >&2
        fi

        # --- Create the switch if it doesn't exist ----------------------------
        # Use both `opam switch list` and a directory check to avoid transient
        # detection failures (opam lock contention, concurrent builds, etc.).
        local _switch_exists=false
        if "${OPAM}" switch list --short 2>/dev/null | grep -qFx "${switch}"; then
          _switch_exists=true
        elif [[ -d "${opam_root}/${switch}" ]]; then
          _switch_exists=true
        fi
        if [[ "${_switch_exists}" != "true" ]]; then
          echo "External compiler: ${ocaml_exe} (OCaml ${vnum})" >&2
          echo "Creating opam switch '${switch}' for this compiler..." >&2
          "${OPAM}" switch create "${switch}" \
            --packages "ocaml-system.${vnum}" \
            --repos "ext-compiler,default" \
            --no-switch --yes >&2 \
          || {
            # Switch may already exist if detection was unreliable.
            if "${OPAM}" switch list --short 2>/dev/null | grep -qFx "${switch}" \
               || [[ -d "${opam_root}/${switch}" ]]; then
              echo "Switch '${switch}' already exists; continuing." >&2
            else
              echo "ERROR: Failed to create opam switch '${switch}'." >&2
              exit 1
            fi
          }
        fi

        # --- OxCaml: ensure real ocamlfind binary in the switch ---------------
        # ocamlfind is a pure build tool (reads META files, passes -I flags
        # to ocamlopt).  It doesn't need to be ABI-compatible with OxCaml.
        # Build it with stock OCaml and install it into the switch with the
        # correct findlib.conf paths so `ocamlfind install` targets the
        # right lib directory.
        if [[ "${vnum}" == *"+ox"* ]]; then
          local switch_bin="${opam_root}/${switch}/bin"
          if [[ ! -x "${switch_bin}/ocamlfind" ]]; then
            echo "Building ocamlfind for OxCaml switch with stock OCaml..." >&2
            _build_ocamlfind_for_switch "${switch}" "${opam_root}" "${ocaml_bin_dir}"
          fi

          # Mark stubs as installed in opam so it doesn't try to build
          # them when resolving dependencies for other packages.
          if ! "${OPAM}" list --switch "${switch}" --installed --short ocamlfind 2>/dev/null | grep -q ocamlfind; then
            echo "Registering stub ocamlfind in opam switch '${switch}'..." >&2
            "${OPAM}" install --switch "${switch}" --yes ocamlfind >&2 || true
          fi

          for stub_pkg in csexp dune dune-configurator dune-private-libs dune-secondary; do
            if ! "${OPAM}" list --switch "${switch}" --installed --short "${stub_pkg}" 2>/dev/null | grep -q "${stub_pkg}"; then
              echo "Registering stub ${stub_pkg} in opam switch '${switch}'..." >&2
              "${OPAM}" install --switch "${switch}" --yes "${stub_pkg}" >&2 || true
            fi
          done

          # Ensure a real dune binary is available in the ext switch.
          # The stub dune package doesn't install a binary, so we symlink
          # one from a stock OCaml switch to keep it on PATH.
          if [[ ! -x "${switch_bin}/dune" ]]; then
            local _sys_dune=""
            # Look in stock opam switches.
            local _try_sw
            for _try_sw in $("${OPAM}" switch list --short 2>/dev/null); do
              [[ "${_try_sw}" == ext-* ]] && continue
              [[ "${_try_sw}" == running-ng-oxcaml-build ]] && continue
              if [[ -x "${opam_root}/${_try_sw}/bin/dune" ]]; then
                _sys_dune="${opam_root}/${_try_sw}/bin/dune"
                break
              fi
            done
            # Fallback: dune anywhere on PATH (before we prepend ext switch).
            if [[ -z "${_sys_dune}" ]]; then
              _sys_dune="$(command -v dune 2>/dev/null)" || true
            fi
            if [[ -n "${_sys_dune}" && -x "${_sys_dune}" ]]; then
              mkdir -p "${switch_bin}"
              ln -sf "${_sys_dune}" "${switch_bin}/dune"
              echo "Symlinked dune → ${_sys_dune} into ${switch_bin}/" >&2
            else
              echo "WARNING: No dune binary found to symlink into ext switch." >&2
              echo "  Benchmarks requiring dune may fail." >&2
            fi
          fi

          # --- OxCaml: build real csexp + dune-configurator libraries --------
          # The stub dune-configurator satisfies opam but doesn't install the
          # actual OCaml library.  Packages like lwt, bigstringaf, checkseum
          # need it at build time (their config/discover.ml imports it).
          # Both csexp and dune-configurator compile cleanly with OxCaml.
          local switch_lib="${opam_root}/${switch}/lib"
          if [[ ! -f "${switch_lib}/dune-configurator/configurator.cmxa" ]]; then
            echo "Building csexp + dune-configurator for OxCaml switch..." >&2
            _build_dune_configurator_for_switch "${switch}" "${opam_root}" "${ocaml_bin_dir}"
          fi

        else
          # --- Stock OCaml ext switch: ensure real ocamlfind ----------------------
          # OxCaml stubs in ext-compiler-repo may shadow the real ocamlfind.
          # If the ext switch has no ocamlfind binary (stub was installed instead
          # of the real package), build it from source — same as for OxCaml.
          local switch_bin="${opam_root}/${switch}/bin"
          if [[ ! -x "${switch_bin}/ocamlfind" ]]; then
            echo "Stock OCaml ext switch missing ocamlfind binary (stub shadowed real package)." >&2
            echo "Building ocamlfind from source for ext switch '${switch}'..." >&2
            _build_ocamlfind_for_switch "${switch}" "${opam_root}" "${ocaml_bin_dir}"
          fi

          # Ensure dune binary is available (stub dune has no binary).
          if [[ ! -x "${switch_bin}/dune" ]]; then
            local _sys_dune=""
            local _try_sw
            for _try_sw in $("${OPAM}" switch list --short 2>/dev/null); do
              [[ "${_try_sw}" == ext-* ]] && continue
              [[ "${_try_sw}" == running-ng-oxcaml-build ]] && continue
              if [[ -x "${opam_root}/${_try_sw}/bin/dune" ]]; then
                _sys_dune="${opam_root}/${_try_sw}/bin/dune"
                break
              fi
            done
            if [[ -z "${_sys_dune}" ]]; then
              _sys_dune="$(command -v dune 2>/dev/null)" || true
            fi
            if [[ -n "${_sys_dune}" && -x "${_sys_dune}" ]]; then
              mkdir -p "${switch_bin}"
              ln -sf "${_sys_dune}" "${switch_bin}/dune"
              echo "Symlinked dune → ${_sys_dune} into ${switch_bin}/" >&2
            fi
          fi

          # Build dune-configurator if the stub shadowed the real library.
          # Packages like bigstringaf, checkseum need it at build time.
          local switch_lib="${opam_root}/${switch}/lib"
          if [[ ! -f "${switch_lib}/dune-configurator/configurator.cmxa" ]]; then
            echo "Building csexp + dune-configurator for stock OCaml ext switch..." >&2
            _build_dune_configurator_for_switch "${switch}" "${opam_root}" "${ocaml_bin_dir}"
          fi
        fi
        ;;
    esac
  fi

  # --- Install requested packages --------------------------------------------
  # For OxCaml, filter out stubbed packages (ocamlfind, dune*) — handled above.
  if [[ -z "${vnum}" ]]; then
    vnum="$("${ocaml_exe}" -vnum 2>/dev/null)" || true
  fi

  local install_pkgs=""
  for p in ${pkgs}; do
    if [[ "${vnum}" == *"+ox"* ]]; then
      case "${p}" in
        ocamlfind|dune|dune-configurator|dune-private-libs|dune-secondary|csexp) continue ;;
      esac
    fi
    install_pkgs="${install_pkgs:+${install_pkgs} }${p}"
  done

  if [[ -n "${install_pkgs}" ]]; then
    echo "Auto-installing [${install_pkgs}] into opam switch '${switch}'..." >&2
    "${OPAM}" install --switch "${switch}" --yes ${install_pkgs} >&2
  fi

  # For stock OCaml, install ocamlfind normally if it was in the package list.
  if [[ "${vnum}" != *"+ox"* ]]; then
    for p in ${pkgs}; do
      if [[ "${p}" == "ocamlfind" ]]; then
        if ! "${OPAM}" list --switch "${switch}" --installed --short ocamlfind 2>/dev/null | grep -q ocamlfind; then
          echo "Auto-installing [ocamlfind] into opam switch '${switch}'..." >&2
          "${OPAM}" install --switch "${switch}" --yes ocamlfind >&2
        fi
        break
      fi
    done
  fi

  export PATH="${opam_root}/${switch}/bin:${PATH}"
  export PATH="${ocaml_bin_dir}:${PATH}"
  export OCAMLPATH="${opam_root}/${switch}/lib${OCAMLPATH:+:${OCAMLPATH}}"
}

# Build ocamlfind from source using a stock OCaml compiler and install it
# into the given opam switch prefix.
_build_ocamlfind_for_switch() {
  local switch="$1"
  local opam_root="$2"
  local target_bin_dir="${3:-}"   # bin dir of the target compiler (OxCaml)
  local switch_prefix="${opam_root}/${switch}"

  # Find a stock OCaml compiler to build ocamlfind with.
  # Priority: running-ng bootstrap > user's default opam switch > system ocaml.
  local stock_ocaml=""

  # Check the running-ng bootstrap toolchain (stock OCaml 5.4.0).
  # Toolchains are cached as version-X.Y.Z/install/bin/ or commit-HASH/install/bin/.
  local bootstrap_dir="/tmp/running-ng-ocaml-toolchains"
  for d in "${bootstrap_dir}"/version-5.*/install/bin "${bootstrap_dir}"/5.*/install/bin "${bootstrap_dir}"/version-5.*/bin "${bootstrap_dir}"/5.*/bin; do
    if [[ -x "${d}/ocaml" ]]; then
      stock_ocaml="${d}"
      break
    fi
  done

  # Fallback: any opam switch that has an ocaml binary.
  if [[ -z "${stock_ocaml}" ]]; then
    local try_switch
    for try_switch in $("${OPAM}" switch list --short 2>/dev/null); do
      # Skip the ext- switches (those are external compilers, possibly OxCaml).
      [[ "${try_switch}" == ext-* ]] && continue
      if [[ -x "${opam_root}/${try_switch}/bin/ocaml" ]]; then
        stock_ocaml="${opam_root}/${try_switch}/bin"
        break
      fi
    done
  fi

  if [[ -z "${stock_ocaml}" ]]; then
    echo "WARNING: No stock OCaml found to build ocamlfind. Skipping." >&2
    echo "  ocamlfind-dependent benchmarks may fail to build." >&2
    return 0
  fi

  echo "Using stock OCaml at ${stock_ocaml}/ocaml to build ocamlfind" >&2

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap "rm -rf '${tmpdir}'" RETURN

  # Download ocamlfind source.
  local version="1.9.8"
  local url="https://github.com/ocaml/ocamlfind/archive/refs/tags/findlib-${version}.tar.gz"
  if command -v curl >/dev/null 2>&1; then
    curl -sSL "${url}" | tar xz -C "${tmpdir}"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "${url}" | tar xz -C "${tmpdir}"
  else
    echo "WARNING: Neither curl nor wget found. Cannot download ocamlfind." >&2
    return 0
  fi

  local srcdir="${tmpdir}/ocamlfind-findlib-${version}"
  if [[ ! -d "${srcdir}" ]]; then
    echo "WARNING: ocamlfind source not found after extraction." >&2
    return 0
  fi

  # Build with stock OCaml, install into the OxCaml switch prefix.
  # The key settings: -sitelib and -config point to the ext switch so that
  # `ocamlfind install` targets the correct lib directory.
  (
    cd "${srcdir}"
    PATH="${stock_ocaml}:${PATH}" \
      ./configure \
        -bindir "${switch_prefix}/bin" \
        -sitelib "${switch_prefix}/lib" \
        -mandir "${switch_prefix}/man" \
        -config "${switch_prefix}/lib/findlib.conf"
    PATH="${stock_ocaml}:${PATH}" make all
    PATH="${stock_ocaml}:${PATH}" make install
  ) >&2

  # Fix findlib.conf: the configure step bakes in the stock OCaml stdlib path
  # (used to build ocamlfind).  Replace it with the target (OxCaml) compiler's
  # stdlib so that `ocamlfind ocamlopt -package unix -linkpkg` resolves .cmi
  # files from the correct compiler.
  if [[ -n "${target_bin_dir}" && -x "${target_bin_dir}/ocamlopt" ]]; then
    local target_stdlib
    target_stdlib="$("${target_bin_dir}/ocamlopt" -where 2>/dev/null)" || true
    local conf="${switch_prefix}/lib/findlib.conf"
    if [[ -n "${target_stdlib}" && -f "${conf}" ]]; then
      local stock_stdlib
      stock_stdlib="$(PATH="${stock_ocaml}:${PATH}" ocamlopt -where 2>/dev/null)" || true
      if [[ -n "${stock_stdlib}" && "${stock_stdlib}" != "${target_stdlib}" ]]; then
        echo "Fixing findlib.conf: ${stock_stdlib} → ${target_stdlib}" >&2
        sed -i "s|${stock_stdlib}|${target_stdlib}|g" "${conf}"
      fi
    fi
  fi

  echo "ocamlfind installed into ${switch_prefix}/bin/" >&2
}

# Build csexp and dune-configurator from source using OxCaml and install them
# into the given opam switch prefix.  Both libraries compile cleanly with
# OxCaml's extended type system.
_build_dune_configurator_for_switch() {
  local switch="$1"
  local opam_root="$2"
  local oxcaml_bin_dir="$3"
  local switch_prefix="${opam_root}/${switch}"
  local switch_lib="${switch_prefix}/lib"

  # We need a dune binary (from stock OCaml) on PATH to build these.
  local dune_bin="${switch_prefix}/bin/dune"
  if [[ ! -x "${dune_bin}" ]]; then
    dune_bin="$(command -v dune 2>/dev/null)" || true
  fi
  if [[ -z "${dune_bin}" || ! -x "${dune_bin}" ]]; then
    echo "WARNING: No dune binary available. Cannot build dune-configurator." >&2
    return 0
  fi

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap "rm -rf '${tmpdir}'" RETURN

  local csexp_ver="1.5.2"
  local dune_ver="3.21.1"

  # --- Download sources ---
  local dl_cmd=""
  if command -v curl >/dev/null 2>&1; then
    dl_cmd="curl -sSL"
  elif command -v wget >/dev/null 2>&1; then
    dl_cmd="wget -qO-"
  else
    echo "WARNING: Neither curl nor wget found. Cannot download sources." >&2
    return 0
  fi

  echo "  Downloading csexp ${csexp_ver}..." >&2
  ${dl_cmd} "https://github.com/ocaml-dune/csexp/releases/download/${csexp_ver}/csexp-${csexp_ver}.tbz" \
    | tar xj -C "${tmpdir}"

  echo "  Downloading dune ${dune_ver} (for dune-configurator)..." >&2
  ${dl_cmd} "https://github.com/ocaml/dune/releases/download/${dune_ver}/dune-${dune_ver}.tbz" \
    | tar xj -C "${tmpdir}"

  local csexp_src="${tmpdir}/csexp-${csexp_ver}"
  local dune_src="${tmpdir}/dune-${dune_ver}"

  if [[ ! -d "${csexp_src}" || ! -d "${dune_src}" ]]; then
    echo "WARNING: Source extraction failed. Cannot build dune-configurator." >&2
    return 0
  fi

  # --- Build csexp with OxCaml ---
  echo "  Building csexp with OxCaml..." >&2
  (
    cd "${csexp_src}"
    PATH="${oxcaml_bin_dir}:$(dirname "${dune_bin}"):${PATH}" \
      "${dune_bin}" build -p csexp 2>&1
  ) >&2

  # Install csexp into ext switch
  mkdir -p "${switch_lib}/csexp"
  cp "${csexp_src}"/_build/install/default/lib/csexp/* "${switch_lib}/csexp/"
  echo "  csexp installed into ${switch_lib}/csexp/" >&2

  # --- Build dune-configurator with OxCaml ---
  echo "  Building dune-configurator with OxCaml..." >&2
  (
    cd "${dune_src}"
    rm -rf vendor/csexp vendor/pp
    PATH="${oxcaml_bin_dir}:$(dirname "${dune_bin}"):${PATH}" \
    OCAMLPATH="${switch_lib}" \
      "${dune_bin}" build -p dune-configurator 2>&1
  ) >&2

  # Install dune-configurator into ext switch
  local src_lib="${dune_src}/_build/install/default/lib/dune-configurator"
  if [[ ! -d "${src_lib}" ]]; then
    echo "WARNING: dune-configurator build produced no install files." >&2
    return 0
  fi
  mkdir -p "${switch_lib}/dune-configurator/.private"
  cp "${src_lib}"/*.{a,cma,cmi,cmt,cmti,cmx,cmxa,cmxs,ml,mli} \
     "${switch_lib}/dune-configurator/" 2>/dev/null || true
  cp "${src_lib}/META" "${switch_lib}/dune-configurator/"
  cp "${src_lib}/dune-package" "${switch_lib}/dune-configurator/"
  cp "${src_lib}/opam" "${switch_lib}/dune-configurator/" 2>/dev/null || true
  cp "${src_lib}"/.private/* "${switch_lib}/dune-configurator/.private/" 2>/dev/null || true

  # Create dune META with configurator sub-package redirect so packages
  # using the old name "dune.configurator" can find it.
  mkdir -p "${switch_lib}/dune"
  if [[ ! -f "${switch_lib}/dune/META" ]] || ! grep -q configurator "${switch_lib}/dune/META" 2>/dev/null; then
    cat > "${switch_lib}/dune/META" <<'DUNEMETA'
package "configurator" (
  directory = "configurator"
  version = "3.21.1"
  requires = "dune-configurator"
  exports = "dune-configurator"
)
DUNEMETA
  fi

  echo "  dune-configurator installed into ${switch_lib}/dune-configurator/" >&2
}
