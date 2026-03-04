# benches

Standalone benchmark sources used by `running-ng`.

This repo is intended to be referenced from `running-ng` configs via absolute paths in suite `programs.<benchmark>.path`.

## Directory Layout

Benchmarks are organised into two top-level groups:

```text
benches/
  simple/         # stdlib / unix only; single build script, no generated data
  with_deps/      # require dune multi-library builds or generated input data
```

Each benchmark lives in its own subfolder:

```text
benches/
  simple/
    <benchmark-name>/
      <benchmark-name>.ml          # source (or multiple .ml files)
      <benchmark-name>.build.sh    # builds the binary via ocamlopt or dune

  with_deps/
    <benchmark-name>/
      <source files ...>
      <benchmark-name>.build.sh       # builds the benchmark binary
      <benchmark-name>.build.deps.sh  # generates runtime-independent input data
```

### `build.deps.sh` convention

For benchmarks in `with_deps/` that require pre-generated input data (e.g. a
graph edge list), a companion `<benchmark>.build.deps.sh` script handles data
generation.  The main `build.sh` calls it automatically before building the
binary.

Key properties:
- `build.deps.sh` receives the same env vars as `build.sh` (in particular
  `OCAML_EXECUTABLE` and `RUNNING_OCAML_BENCH_DIR`).
- Generated data files are placed in the benchmark directory and are
  **runtime-version-independent**: the script skips generation if the file
  already exists, so data is produced once and reused across all compiler
  versions in a sweep.

## Integration With `running-ng`

For `OCamlBenchmarkSuite`, when `path` points to a directory, `running-ng` uses build mode.

Conventions used by default:

- build script: `<benchmark-name>.build.sh`
- output binary: `<benchmark-name>-<runtime-name>`

So benchmark `binarytrees` with runtime `ocaml-local` produces:

- `simple/binarytrees/binarytrees-ocaml-local`

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

### fannkuchredux

- **Source:** sandmark `benchmarks/benchmarksgame/fannkuchredux.ml`
- **Build:** ocamlopt (stdlib only), compiled with `-noassert -unsafe` as in sandmark
- **Args:** `<N>` — permutation length; config uses `11`
- **Description:** Counts the maximum number of flips needed to sort a permutation, and sums the sign of each intermediate permutation (Pfannkuchen benchmark). Pure computation with no allocation; useful as a control benchmark where GC has negligible impact.

### numerical-analysis

Six benchmarks sharing `benches/numerical-analysis/`. Each has its own build script; two require two source files compiled in order.

#### crout_decomposition

- **Source:** sandmark `benchmarks/numerical-analysis/crout_decomposition.ml` (originally OCamlPro's ocamlbench-repo)
- **Build:** ocamlopt (stdlib only)
- **Args:** _(none)_
- **Description:** Crout matrix decomposition (LU factorisation variant) on a fixed matrix. Dense linear algebra; exercises float array allocation.

#### qr_decomposition

- **Source:** sandmark `benchmarks/numerical-analysis/qr_decomposition.ml` (originally OCamlPro's ocamlbench-repo)
- **Build:** ocamlopt (stdlib only)
- **Args:** _(none)_
- **Description:** QR decomposition via Gram-Schmidt on a fixed matrix. Dense linear algebra; similar allocation profile to `crout_decomposition`.

#### durand_kerner_aberth

- **Source:** sandmark `benchmarks/numerical-analysis/durand_kerner_aberth.ml` (originally OCamlPro's ocamlbench-repo)
- **Build:** ocamlopt (stdlib only)
- **Args:** _(none)_ — optional percentage of coefficient array (default 100); runs 10 iterations
- **Description:** Finds all roots of a polynomial simultaneously using the Durand–Kerner / Weierstrass method. Complex-number arithmetic on float arrays.

#### fft

- **Source:** sandmark `benchmarks/numerical-analysis/fft.ml` (originally OCamlPro's ocamlbench-repo)
- **Build:** ocamlopt + `unix.cmxa` (uses `Unix.times` for timing output)
- **Args:** _(none)_ — optional array size (default 1048576)
- **Description:** Cooley–Tukey FFT followed by inverse FFT on a complex float array. In-place computation; exercises large float array allocation and cache effects.

#### levinson_durbin

- **Source:** sandmark `benchmarks/numerical-analysis/levinson_durbin.ml` + `levinson_durbin_dataset.ml`
- **Build:** ocamlopt (stdlib only), two-file: dataset compiled first
- **Args:** _(none)_
- **Description:** Levinson–Durbin recursion for autoregressive modelling of Japanese vowel sound data. Exercises float array allocation with a real-world-sized numerical dataset.

#### naive_multilayer

- **Source:** sandmark `benchmarks/numerical-analysis/naive_multilayer.ml` + `naive_multilayer_dataset.ml`
- **Build:** ocamlopt (stdlib only), two-file: dataset compiled first
- **Args:** _(none)_
- **Description:** Naive multilayer neural network (forward pass + backpropagation) on the UCI Ionosphere dataset. Dense matrix operations; exercises both float array allocation and functional list structure.

---

## with_deps benchmarks

### graph500seq

- **Source:** sandmark `benchmarks/graph500seq/`
- **Build:** dune (multi-library), in `with_deps/graph500seq/`
- **Args:** `<edges-file>` — absolute path to `edges.data`; generated by `build.deps.sh` at `/home/udesou/benches/with_deps/graph500seq/edges.data`
- **Description:** Graph500 Kernel 1 (BFS-reachable subgraph construction) on a Kronecker random graph. Builds a sparse adjacency representation from a large array of edges. Memory-intensive pointer chasing; exercises the major GC heavily.
- **graphTypes:** In sandmark, `GraphTypes` is provided by a parent dune-project scope. Here it is defined explicitly in `graphTypes.ml` (`type vertex = int`, `type weight = float`, `type edge = vertex * vertex * weight`).
- **Data generation:** `graph500seq.build.deps.sh` builds `gen.exe` with dune and runs it (`-scale 21 -edgefactor 16`) to produce `edges.data` (~64M edges). This is done once and reused across all runtime versions since the data is OCaml-version-independent.
- **Timeout:** 300 s (longer than simple benchmarks due to data loading + graph construction).

---

## TODO — Benchmarks Not Yet Added

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
