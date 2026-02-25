# benches

Standalone benchmark sources used by `running-ng`.

This repo is intended to be referenced from `running-ng` configs via absolute paths in suite `programs.<benchmark>.path`.

## Expected Layout

Each benchmark lives in its own folder:

```text
benches/
  <benchmark-name>/
    <benchmark-name>.ml
    <benchmark-name>.build.sh
    dependencies.txt            # optional notes
```

Example:

```text
benches/
  binarytrees/
    binarytrees.ml
    binarytrees.build.sh
```

## Integration With `running-ng`

For `OCamlBenchmarkSuite`, when `path` points to a directory, `running-ng` uses build mode.

Conventions used by default:

- build script: `<benchmark-name>.build.sh`
- output binary: `<benchmark-name>-<runtime-name>`

So benchmark `binarytrees` with runtime `ocaml-local` produces:

- `binarytrees-ocaml-local`

You can override this in `running-ng` config with `build_script` and `binary`, but the convention above means those fields are usually unnecessary.

## Build Script Contract

`running-ng` invokes the build script with these env vars:

- `OCAML_EXECUTABLE`: selected OCaml executable path.
- `OCAML_HOME`: runtime prefix (parent of `bin`).
- `RUNNING_OCAML_OUTPUT`: expected output binary path.
- `RUNNING_OCAML_BENCH_DIR`: benchmark directory.
- `RUNNING_OCAML_RUNTIME_NAME`: runtime name from config.

Build scripts should write the executable to `RUNNING_OCAML_OUTPUT`.

## Minimal Example Build Script

```bash
#!/usr/bin/env bash
set -euo pipefail

: "${OCAML_EXECUTABLE:?OCAML_EXECUTABLE is required}"
OUT="${RUNNING_OCAML_OUTPUT:?RUNNING_OCAML_OUTPUT is required}"
SRC="${RUNNING_OCAML_BENCH_DIR}/binarytrees.ml"
OCAMLOPT="$(dirname "$OCAML_EXECUTABLE")/ocamlopt"

mkdir -p "$(dirname "$OUT")"
"$OCAMLOPT" -O3 -I +unix unix.cmxa "$SRC" -o "$OUT"
chmod +x "$OUT"
```
