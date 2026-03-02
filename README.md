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

---

## Benchmarks

All benchmarks below are sourced from [sandmark](https://github.com/ocaml-bench/sandmark) unless noted otherwise.
Build approach is either **ocamlopt** (single `.ml` compiled directly) or **dune** (multi-file, uses a `dune` file in the benchmark dir).

### binarytrees

- **Source:** benchmarksgame (via sandmark `benchmarksgame/binarytrees5.ml`, adapted)
- **Build:** ocamlopt + `unix.cmxa`
- **Args:** `<depth>` — tree depth; config uses `21`
- **Description:** Allocates and traverses binary trees of increasing depth. Classic GC stress test; the vast majority of allocation is short-lived.

### markbench

- **Source:** sandmark `benchmarks/markbench/`
- **Build:** dune + `unix`
- **Args:** _(none)_ — defaults to 10 `Gc.full_major` cycles; pass an integer to override
- **Description:** Microbenchmark for the major GC mark phase. Allocates a large live set and calls `Gc.full_major` repeatedly, measuring seconds per GC cycle. Sensitive to `o` (space overhead) and `s` (minor heap size).

### almabench

- **Source:** sandmark `benchmarks/almabench/` (originally OCamlPro's ocamlbench-repo)
- **Build:** ocamlopt (stdlib only)
- **Args:** _(none)_
- **Description:** Floating-point benchmark computing energy levels of a quantum-mechanical system. Exercises the minor heap heavily with small float arrays.

### bdd

- **Source:** sandmark `benchmarks/bdd/` (originally OCamlPro's ocamlbench-repo)
- **Build:** ocamlopt (stdlib only)
- **Args:** _(none)_
- **Description:** Binary Decision Diagram operations (AND, OR, NOT, quantification) on propositional formulae. Pointer-heavy graph structure; exercises major GC and sharing.

### hamming

- **Source:** sandmark `benchmarks/hamming/`
- **Build:** ocamlopt (stdlib only)
- **Args:** `<N>` — number of Hamming numbers to iterate over; config uses `500000`
- **Description:** Generates the infinite lazy Hamming sequence (numbers of the form 2^i × 3^j × 5^k) using lazy streams and lazy merging. Exercises lazy allocation and minor GC.

### soli

- **Source:** sandmark `benchmarks/soli/`
- **Build:** ocamlopt (stdlib only)
- **Args:** `<nruns>` — number of solver runs; config uses `50`
- **Description:** Peg solitaire solver using backtracking search. Exercises call stack and moderate allocation; useful for testing the interaction between recursion depth and minor heap pressure.

### kb

- **Source:** sandmark `benchmarks/kb/` (originally OCamlPro's ocamlbench-repo)
- **Build:** ocamlopt (stdlib only)
- **Args:** _(none)_ — runs 100 iterations of Knuth-Bendix completion internally
- **Description:** Knuth-Bendix completion procedure (with exceptions). Algebraic term rewriting; heavily allocates and collects term structures. A classic OCaml GC benchmark.

### kb_no_exc

- **Source:** sandmark `benchmarks/kb/kb_no_exc.ml` (shares directory with `kb`)
- **Build:** ocamlopt (stdlib only) — build script is `kb_no_exc.build.sh` in `benches/kb/`
- **Args:** _(none)_ — runs 100 iterations of Knuth-Bendix completion internally
- **Description:** Same algorithm as `kb` but with the exception-based search replaced by an explicit option type. Useful for comparing exception overhead against allocation/GC cost.

### lexifi-g2pp

- **Source:** sandmark `benchmarks/lexifi-g2pp/` (originally OCamlPro's ocamlbench-repo)
- **Build:** dune (stdlib only, multi-file; entry point: `main.exe`)
- **Args:** _(none)_
- **Description:** Calibrates a G2++ two-factor interest rate model (LexiFi's financial library benchmark). Involves iterative numerical optimisation over a large structured dataset. Exercises both arithmetic and moderate allocation in a realistic workload.

### zdd

- **Source:** sandmark `benchmarks/zdd/`
- **Build:** ocamlopt (stdlib only)
- **Args:** `<words-file>` — absolute path to `words.txt`; use `/home/udesou/benches/zdd/words.txt`
- **Description:** Zero-suppressed Binary Decision Diagram (ZDD) operations over an English word dictionary. Builds a ZDD from all words, then counts matches for a pattern query. Exercises pointer-heavy DAG structures similar to `bdd`.
- **Note:** The run cwd is a temp dir, so the word file must be passed as an absolute path.

---

## TODO — Benchmarks Not Yet Added

### Easy to add (stdlib or `unix` only, no external packages)

- **`numerical-analysis` programs** — `crout_decomposition`, `qr_decomposition`, `durand_kerner_aberth`, `levinson_durbin`, `naive_multilayer` are stdlib-only; `fft` additionally needs `unix`. All single-file or two-file benchmarks that can be compiled with `ocamlopt` directly.
- **`benchmarksgame/fannkuchredux`** — Has its own `executable` stanza with no library dependencies (unlike the rest of benchmarksgame). Single file; `ocamlopt` build.
- **`graph500seq`** — Builds internally-defined libraries only (no external opam packages), but has a data-generation step (`gen.exe` must run first to produce `edges.data`) which makes the build script more involved.

### Need external opam packages

These benchmarks require packages that must be installed into the target opam switch before building.

- **`benchmarksgame` (most programs)** — `binarytrees5`, `fasta`, `knucleotide`, `mandelbrot6`, `nbody`, `pidigits5`, `regexredux2`, `revcomp2`, `spectralnorm2` all depend on `zarith` (and some on `str`).
- **`zarith`** — The sandmark `zarith` benchmark itself (`zarith_fact`, `zarith_fib`, `zarith_pi`, `zarith_tak`) requires the `zarith` package.
- **`chameneos`** — Requires `lwt`.
- **`thread-lwt`** — Requires `lwt`.
- **`valet`** — Requires `lwt` and `react`.
- **`sequence`** — Requires `lwt`.
- **`decompress`** — Requires the `decompress` package.
- **`irmin`** — Requires `irmin`, `irmin-pack`, `index`, and related packages.
- **`owl`** — Requires `owl-base`.
- **`yojson`** — Requires `yojson` and `ppx_deriving_yojson`.
- **`mpl`** — Requires several packages (`mtime`, `progress`, etc.).
- **`simple-tests` (partial)** — `ocamlcapi` and `weak_htbl` require C stubs or special build setup; `pingpong_multicore` requires `domainslib`.

### Need multicore / OCaml 5 effects

These benchmarks require `domainslib`, multiple domains, or OCaml 5 effect handlers, and are not meaningful on OCaml 4.x.

- **`multicore-effects`** — Uses OCaml 5 effect handlers (`algorithmic_differentiation`, `eratosthenes`, `queens`, etc.).
- **`multicore-gcroots`** — Tests concurrent GC root registration across domains.
- **`multicore-grammatrix`** — Matrix operations with parallel domains.
- **`multicore-minilight`** — Parallel raytracer variant.
- **`multicore-numerical`** — Parallel versions of numerical benchmarks.
- **`multicore-structures`** — Lock-free data structures (`ms_queue`, `treiber_stack`, etc.); requires `domainslib` / `kcas`.
- **`graph500par`** — Parallel BFS on a Kronecker graph; requires multicore.

### Need external tool binaries or large external data

These benchmarks invoke external tools (theorem provers, compilers) rather than being self-contained OCaml programs.

- **`alt-ergo`** — Invokes the Alt-Ergo SMT solver on `.why` files.
- **`coq`** — Invokes the Coq proof assistant on `.v` files.
- **`cpdf`** — Requires the `cpdf` PDF tool and large PDF inputs.
- **`cubicle`** — Invokes the Cubicle model checker on `.cub` files.
- **`frama-c`** — Invokes the Frama-C C analyser on `.c` files.
- **`menhir`** — Invokes the Menhir parser generator on `.mly` grammar files.
- **`minilight`** — The sandmark dune file only declares a data file alias (`roomfront.ml.txt`); no executable stanza is present, suggesting the benchmark needs a different integration approach.
