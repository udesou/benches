# benches

Standalone benchmark sources used by `running-ng`.

This repo is intended to be referenced from `running-ng` configs via absolute paths in suite `programs.<benchmark>.path`.

## Directory Layout

Benchmarks are organised into three top-level groups:

```text
benches/
  simple/         # stdlib / unix only; single build script, no generated data
  with_deps/      # require dune multi-library builds or generated input data
  with_packages/  # require external opam packages (zarith, lwt, decompress, yojson, …)
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

## Cleaning Build Artifacts

```bash
cd ~/benches && make clean
```

The `Makefile` provides three targets:

- **`clean`** — runs both `clean-dune` and `clean-with-deps`, then removes compiled objects (`.o`, `.a`, `.so`, `.cmi`, `.cmx`, `.cmxa`, `.cmo`, `.cma`, `.cmt`, `.cmti`, `.annot`, `.opt`) and tagged benchmark binaries (`*-ocaml-*`, `*-oxcaml-*`).
- **`clean-dune`** — removes `_build` and `_build-running` directories (dune build caches).
- **`clean-with-deps`** — removes generated input data (e.g. `graph500seq/edges.data`).

**When to clean:** After changing compiler flags (e.g. adding `--enable-multidomain` to an OxCaml runtime), stale cached binaries may mask the change. Run `make clean` to force a rebuild on the next benchmark run.

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
- **Args:** `<words-file>` — absolute path to `words.txt`; use `/home/udesou/benches/simple/zdd/words.txt`
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

### sequence_cps

- **Source:** sandmark `benchmarks/sequence/sequence_cps.ml` (originally OCamlPro's ocamlbench-repo)
- **Build:** ocamlopt (stdlib only)
- **Args:** `<N>` — sequence length; config uses `10000`
- **Description:** Builds a lazy CPS-style sequence of integers 0…N, then maps, filters, and folds it to compute a sum. Exercises higher-order function application and minor heap allocation in a functional pipeline; no external libraries required.

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

## with_packages benchmarks

Benchmarks in `with_packages/` require external opam packages. **No manual package installation is needed** — each build script auto-installs the required packages via `_opam_auto_install()`.

### How auto-install works

Each `<benchmark>.build.sh` in `with_packages/` contains a `_opam_auto_install()` function that:

1. **opam-managed compiler** (lives under `~/.opam/<switch>/bin/ocaml`): installs packages directly into that switch.
2. **External/custom compiler** (built from source): derives a stable switch name from the compiler path + version hash, creates a per-version opam switch with a minimal local repo (so any version string — release or dev — is accepted), and installs packages there.
3. **Explicit override**: if `OPAM_SWITCH` is set (via `build_env` in the YAML config), uses that switch directly.

The auto-created switches and installed packages are cached and reused across runs.

### Overriding the opam switch

To force a specific switch, add `build_env` to the suite in the YAML config:

```yaml
sandmark-with-packages:
  type: OCamlBenchmarkSuite
  build_env:
    OPAM_SWITCH: "my-custom-switch"
  programs:
    fasta3: ...
```

`OPAM_SWITCH` takes precedence over all auto-detection.

### benchmarksgame

Seven programs sharing `benches/with_packages/benchmarksgame/`. Each has its own build script; all use dune and link against `zarith`, `str`, and `unix`.

- **binarytrees5** — Args: `21`. Allocates and traverses binary trees of depth 21 using Zarith big integers for node values. GC-intensive short-lived allocation.
- **fasta3** — Args: `25000000`. Generates a DNA sequence of 25M characters using cumulative probability tables. Exercises sequential array access.
- **fasta6** — Args: `25000000`. Alternative fasta generator; same input size, different internal algorithm.
- **mandelbrot6** — Args: `16000`. Renders a 16000×16000 Mandelbrot set image in PBM format. Pure floating-point; no GC pressure.
- **nbody** — Args: `50000000`. N-body planetary simulation (5 bodies, 50M steps). Pure floating-point; tests float unboxing.
- **pidigits5** — Args: `10000`. Computes 10000 digits of π using the Stern-Brocot tree algorithm via Zarith arbitrary-precision integers.
- **spectralnorm2** — Args: `5500`. Approximates the spectral norm of an infinite matrix. Dense floating-point; exercises float arrays.

### zarith

Four programs sharing `benches/with_packages/zarith/`. Each has its own build script; all use dune.

- **zarith_fact** — Args: `40 1000000`. Computes factorial of 40, repeated 1M times. Exercises Zarith multiplication. Needs `zarith`.
- **zarith_fib** — Args: `Z 40`. Fibonacci of 40 using Zarith big integers. Exercises Zarith addition. Needs `zarith`, `num`.
- **zarith_pi** — Args: `10000`. Computes 10000 π digits via the Stern-Brocot streaming algorithm. Exercises Zarith division/comparison. Needs `zarith`.
- **zarith_tak** — Args: `Z 2500`. Tak function with n=2500 using Zarith integers. Exercises recursive calls with big-integer arithmetic. Needs `zarith`, `num`.

### chameneos_redux_lwt

- **Source:** sandmark `benchmarks/chameneos/`
- **Build:** dune + `lwt.unix`
- **Args:** `<meetings>` — number of colour-changing meetings; config uses `600000`
- **Description:** Simulates chameneos creatures meeting in a waiting room and swapping colours, implemented with Lwt lightweight threads. Exercises Lwt cooperative scheduling and mvar synchronisation.

### thread_ring_lwt_mvar / thread_ring_lwt_stream

Both in `benches/with_packages/thread-lwt/`; shared dune file.

- **Source:** sandmark `benchmarks/thread-lwt/`
- **Build:** dune + `lwt`, `lwt.unix`
- **Args:** `<N>` — number of ring-pass iterations; config uses `20000`
- **thread_ring_lwt_mvar** — Token passed around a ring of 503 Lwt threads via `Lwt_mvar`. Exercises mvar hand-off latency.
- **thread_ring_lwt_stream** — Same ring, but using `Lwt_stream` channels. Slightly higher allocation than the mvar variant.

### test_decompress

- **Source:** sandmark `benchmarks/decompress/test_decompress.ml`
- **Build:** dune + `bigstringaf`, `checkseum.ocaml`, `decompress.zl`
- **Args:** _(none)_ — defaults to 64 compress/decompress iterations on 32 KB of data
- **Description:** Microbenchmark for the `decompress` pure-OCaml zlib implementation. Compresses then decompresses a block of data in a loop. Exercises allocation of `Bigarray`-backed buffers and the functional zipper-style stream API.

### ydump

- **Source:** sandmark `benchmarks/yojson/ydump.ml`
- **Build:** dune + `yojson`, `camlp-streams`
- **Args:** `-c <json-file>` — compact-print a JSON file; config uses the bundled `sample.json` (absolute path required since run cwd is a temp dir)
- **Description:** Parses and pretty-prints a JSON document using the Yojson library. Exercises OCaml's `Buffer`-based output, recursive tree traversal, and moderate allocation from parsing.

## multicore benchmarks

Benchmarks that require OCaml 5.x and the `Effect` module. Source is in `multicore/`; the flat layout mirrors `simple/` (each benchmark in its own subfolder, with an optional `build.deps.sh` for generated data).

Use `OCamlMulticoreBenchmarkSuite` (instead of `OCamlBenchmarkSuite`) in running-ng configs. This suite type enforces OCaml >= 5 at build/run time and raises a clear error if you attempt to sweep with an older compiler.

### multicore/multicore-effects

Single-file effect benchmarks compiled with `ocamlopt`. Adapted from sandmark `benchmarks/multicore-effects/` for the OCaml 5.2+ `Effect` module API (sandmark's originals use the pre-5.2 `effect` keyword syntax, which is not accepted by OCaml 5.2+).

#### algorithmic_differentiation

- **Source:** sandmark `benchmarks/multicore-effects/algorithmic_differentiation.ml` (adapted)
- **Build:** ocamlopt (stdlib only)
- **Args:** `<iterations>` — default 100
- **Description:** Reverse-mode automatic differentiation using deep effect handlers (`Add` and `Mult` effects). Exercises deep effect handler dispatch, continuation resumption, and float array allocation.

#### rec_eff_fib / rec_seq_fib

- **Source:** sandmark `benchmarks/multicore-effects/rec_eff_{fib,seq_fib}.ml` (adapted)
- **Build:** ocamlopt (stdlib only)
- **Args:** `<iters> <n>` — default `4 40` (expected output per iter: 102334155)
- **Description:** Recursive Fibonacci. `rec_eff_fib` installs a `try_with` effect handler at each recursive call site (handler is never triggered; effect `E` is never performed) — tests the overhead of handler installation compared to the pure-recursive `rec_seq_fib` baseline.

#### rec_eff_tak / rec_seq_tak

- **Source:** sandmark `benchmarks/multicore-effects/rec_eff_{tak,seq_tak}.ml` (adapted)
- **Build:** ocamlopt (stdlib only)
- **Args:** `<iters> <x> <y> <z>` — default `1 40 20 11` (expected output per iter: 12)
- **Description:** Takeuchi function. Same handler-overhead comparison pattern as rec_{eff,seq}_fib; three handler installations per recursive call.

#### rec_eff_ack / rec_seq_ack

- **Source:** sandmark `benchmarks/multicore-effects/rec_eff_{ack,seq_ack}.ml` (adapted)
- **Build:** ocamlopt (stdlib only)
- **Args:** `<iters> <m> <n>` — default `2 3 11` (expected output per iter: 16381)
- **Description:** Ackermann function. Same pattern; tests effect handler overhead on a deeply recursive, stack-intensive computation.

### multicore/multicore-structures

Lock-free concurrent data structures implemented with OCaml 5 stdlib `Atomic`. No external packages required — the sandmark originals referenced `kcas`, but all atomic operations (`Atomic.t`, `Atomic.get`, `Atomic.set`, `Atomic.compare_and_set`) are available in the stdlib since OCaml 5.0. Each test program is compiled together with its data-structure module using `ocamlfind -package unix`.

**Data structure modules** (in the benchmark directory, compiled alongside each test):
- `ms_queue.ml` — Michael–Scott lock-free MPMC queue using `Atomic.t` and CAS loops.
- `treiber_stack.ml` — Treiber lock-free LIFO stack using `Atomic.t`.
- `spsc_queue.ml` — Wait-free bounded SPSC queue with cache-line padding.

#### test_queue_sequential

- **Source:** sandmark `benchmarks/multicore-structures/test_queue_sequential.ml`
- **Build:** ocamlfind + unix (stdlib Atomic, no domainslib)
- **Args:** `<items>` — number of items to enqueue/dequeue
- **Description:** Sequentially enqueues then dequeues `<items>` integers through the MS queue. Checks that no items are lost and reports throughput (items/ms).

#### test_queue_parallel

- **Source:** sandmark `benchmarks/multicore-structures/test_queue_parallel.ml`
- **Build:** ocamlfind + unix
- **Args:** `<items>`
- **Description:** One domain enqueues `<items>` integers while a second domain concurrently dequeues. Exercises the MS queue's CAS-based enqueue/dequeue paths under concurrent access.

#### test_stack_sequential

- **Source:** sandmark `benchmarks/multicore-structures/test_stack_sequential.ml`
- **Build:** ocamlfind + unix
- **Args:** `<items>`
- **Description:** Sequential push/pop stress test on the Treiber stack.

#### test_stack_parallel

- **Source:** sandmark `benchmarks/multicore-structures/test_stack_parallel.ml`
- **Build:** ocamlfind + unix
- **Args:** `<items>`
- **Description:** Concurrent push (one domain) / pop (another domain) on the Treiber stack.

#### test_spsc_queue_sequential

- **Source:** sandmark `benchmarks/multicore-structures/test_spsc_queue_sequential.ml`
- **Build:** ocamlfind + unix
- **Args:** `<items>` — items per run; repeats 1000 times
- **Description:** Sequential enqueue/dequeue cycle on the SPSC queue. Reports ns/item throughput.

#### test_spsc_queue_parallel

- **Source:** sandmark `benchmarks/multicore-structures/test_spsc_queue_parallel.ml`
- **Build:** ocamlfind + unix
- **Args:** `<items>`
- **Description:** One domain enqueues while another dequeues via the SPSC queue. Exercises the wait-free fast path.

#### test_spsc_queue_pingpong_parallel

- **Source:** sandmark `benchmarks/multicore-structures/test_spsc_queue_pingpong_parallel.ml`
- **Build:** ocamlfind + unix
- **Args:** `<num_threads> <num_messages>`
- **Description:** Creates a ring of `<num_threads>` domains, each connected to the next by an SPSC queue. `Ping` messages circulate until a `Bye` terminates each thread. Measures inter-domain message-passing latency through a chain of SPSC queues.

### multicore/multicore-numerical

Parallel versions of classic numerical benchmarks using `domainslib`. Each multicore benchmark has a corresponding sequential baseline. All compiled with `ocamlfind -package domainslib` (or stdlib-only for sequentials). First argument is always `<num_domains>`.

#### mandelbrot6_multicore

- **Source:** sandmark `benchmarks/multicore-numerical/mandelbrot6_multicore.ml`
- **Build:** ocamlfind + domainslib
- **Args:** `<num_domains> <width>` — default `1 200`
- **Description:** Parallel Mandelbrot set renderer. Uses `Task.parallel_for` over rows; each domain computes a horizontal strip. Outputs PBM binary format to stdout. Based on benchmarksgame Mandelbrot #6.

#### nbody_multicore / nbody

- **Source:** sandmark `benchmarks/multicore-numerical/{nbody_multicore,nbody}.ml`
- **Build:** ocamlfind + domainslib (multicore); ocamlopt stdlib (sequential)
- **Args:** `<num_domains> <n> <num_bodies>` — default `1 500 1024`; sequential: `<n> <num_bodies>` — default `500 1024`
- **Description:** N-body gravitational simulation. Parallel version uses `Task.parallel_for` for the velocity-update inner loop and `Task.parallel_for_reduce` for energy computation.

#### floyd_warshall_multicore / floyd_warshall

- **Source:** sandmark `benchmarks/multicore-numerical/{floyd_warshall_multicore,floyd_warshall}.ml`
- **Build:** ocamlfind + domainslib; stdlib
- **Args:** `<num_domains> <n>` — default `1 4`; sequential: `<n>` — default `4`
- **Description:** All-pairs shortest path (Floyd–Warshall). The outer `k` loop is sequential (dependency), inner `i` loop parallelised with `Task.parallel_for`. Uses an algebraic `edge` type (`Value of int | Infinity`).

#### game_of_life_multicore / game_of_life

- **Source:** sandmark `benchmarks/multicore-numerical/{game_of_life_multicore,game_of_life}.ml`
- **Build:** ocamlfind + domainslib; stdlib
- **Args:** `<num_domains> <n_times> <board_size>` — default `1 2 1024`; sequential: `<n_times> <board_size>` — default `2 1024`
- **Description:** Conway's Game of Life on a `board_size × board_size` grid, iterated `n_times` steps. Row updates parallelised with `Task.parallel_for`.

#### binarytrees5_multicore

- **Source:** sandmark `benchmarks/multicore-numerical/binarytrees5_multicore.ml`
- **Build:** ocamlfind + domainslib
- **Args:** `<num_domains> <max_depth>` — default `1 10`
- **Description:** Binary tree construction and checksum benchmark (benchmarksgame binary-trees #5). Uses `Task.async`/`Task.await` to parallelise tree checks across depths and domains. Exercises GC allocation and domain-local work stealing.

#### spectralnorm2_multicore

- **Source:** sandmark `benchmarks/multicore-numerical/spectralnorm2_multicore.ml`
- **Build:** ocamlfind + domainslib
- **Args:** `<num_domains> <n>` — default `1 2000`
- **Description:** Spectral norm of the infinite matrix A where `A[i,j] = 1/((i+j)*(i+j+1)/2+i+1)`. Power iteration using `Task.parallel_for` for matrix-vector products. Based on benchmarksgame spectral-norm #2.

#### fannkuchredux_multicore

- **Source:** sandmark `benchmarks/multicore-numerical/fannkuchredux_multicore.ml`
- **Build:** ocamlfind + domainslib
- **Args:** `<workers> <n>` — default `10 7`
- **Description:** Fannkuch-redux (permutation counting). Divides the factorial permutation space into `workers` chunks and uses `Task.parallel_for` to count flip operations in parallel.

#### quicksort_multicore / quicksort

- **Source:** sandmark `benchmarks/multicore-numerical/{quicksort_multicore,quicksort}.ml`
- **Build:** ocamlfind + domainslib; stdlib
- **Args:** `<num_domains> <n>` — default `1 2000`; sequential: `<n>` — default `2000`
- **Description:** Parallel quicksort using `Task.async`/`Task.await` to spawn recursive subproblems. Depth-bounded spawning (halves remaining depth budget at each partition).

#### mergesort_multicore / mergesort

- **Source:** sandmark `benchmarks/multicore-numerical/{mergesort_multicore,mergesort}.ml`
- **Build:** ocamlfind + domainslib; stdlib
- **Args:** `<num_domains> <n>` — default `1 1024`; sequential: `<n>` — default `1024`
- **Description:** Parallel merge sort using `Task.async`/`Task.await`. Falls back to bubble sort below threshold (32 elements). Uses an in-place double-buffer merge strategy.

#### matrix_multiplication_multicore / matrix_multiplication

- **Source:** sandmark `benchmarks/multicore-numerical/{matrix_multiplication_multicore,matrix_multiplication}.ml`
- **Build:** ocamlfind + domainslib; stdlib
- **Args:** `<num_domains> <size>` — default `1 1024`; sequential: `<size>` — default `1024`
- **Description:** Dense integer matrix multiplication. Row-parallel using `Task.parallel_for` over the output rows.

#### matrix_multiplication_tiling_multicore

- **Source:** sandmark `benchmarks/multicore-numerical/matrix_multiplication_tiling_multicore.ml`
- **Build:** ocamlfind + domainslib
- **Args:** `<num_domains> <size>` — default `1 1024`
- **Description:** Tiled matrix multiplication using explicit `Domainslib.Chan`-based task distribution rather than `parallel_for`. Tile size is 64. The channel-based dispatch is chosen because the loop has decreasing work per iteration, which makes static `parallel_for` chunking suboptimal.

#### LU_decomposition_multicore / LU_decomposition

- **Source:** sandmark `benchmarks/multicore-numerical/{LU_decomposition_multicore,LU_decomposition}.ml`
- **Build:** ocamlfind + domainslib; stdlib
- **Args:** `<num_domains> <mat_size>` — default `1 1200`; sequential: `<mat_size>` — default `1200`
- **Description:** In-place LU decomposition of a random float matrix. Uses `Task.parallel_for` for row elimination and `Domain.DLS` for domain-local random state. Stores L and U in packed form.

#### nqueens_multicore / nqueens

- **Source:** sandmark `benchmarks/multicore-numerical/{nqueens_multicore,nqueens}.ml`
- **Build:** ocamlfind + domainslib; stdlib
- **Args:** `<num_domains> <board_size>` — default `2 13`; sequential: `<board_size>` — default `13`
- **Description:** N-queens solver. Parallel version spawns a `Task.async` for each valid queen placement at each row, aggregating results with `Task.await`.

#### evolutionary_algorithm_multicore / evolutionary_algorithm

- **Source:** sandmark `benchmarks/multicore-numerical/{evolutionary_algorithm_multicore,evolutionary_algorithm}.ml`
- **Build:** ocamlfind + domainslib; stdlib
- **Args:** `<num_domains> <n> <lambda>` — default `4 1000 1000`; sequential: `<n> <lambda>` — default `1000 1000`
- **Description:** Minimal genetic algorithm optimising the Onemax fitness function. Parallel version uses `Task.parallel_for` to evaluate and mutate the population in each generation. Uses `Domain.DLS` for domain-local random state.

### multicore/multicore-grammatrix

Gram matrix benchmark from the Yamanishi laboratory. Compiled with `ocamlfind`; requires a `data/` subdirectory with CSV input files (bundled). The benchmark reads feature vectors from a CSV (space-separated floats) and computes the symmetric Gram matrix via dot products. Default input is `data/tox21_nrar_ligands_std_rand_01.csv` (7026 samples).

A shared helper module `utls.ml` is compiled alongside the main benchmark in each build.

#### grammatrix

- **Source:** sandmark `benchmarks/multicore-grammatrix/grammatrix.ml` + `utls/utls.ml`
- **Build:** ocamlfind + unix (sequential)
- **Args:** `<ncores> <input_file>` — default `1 data/tox21_nrar_ligands_std_rand_01.csv`
- **Description:** Sequential Gram matrix computation. Reads feature vectors, computes the full N×N symmetric matrix in O(N²) dot products, then prints a corner summary. The `ncores` argument is accepted but ignored (present for interface parity with the multicore version).

#### grammatrix_multicore

- **Source:** sandmark `benchmarks/multicore-grammatrix/grammatrix_multicore.ml` + `utls/utls.ml`
- **Build:** ocamlfind + domainslib + unix
- **Args:** `<num_domains> <chunk_size> <input_file>` — default `4 16 data/tox21_nrar_ligands_std_rand_01.csv`
- **Description:** Parallel Gram matrix computation using explicit `Domainslib.Chan`-based task distribution. Work chunks of `<chunk_size>` rows are sent through a bounded channel; each domain fetches and processes chunks until a `Quit` message is received. Channel-based dispatch is preferred over `parallel_for` here because earlier rows have more work (triangular iteration), so pre-computing and queuing chunks in decreasing-work order improves load balance. **Note:** the benchmark must be run from the `multicore-grammatrix/` directory so that the `data/` relative path resolves correctly.

### multicore/oxcaml-prefetch (OxCaml only)

Multicore GC stress test using OxCaml-specific APIs. **Requires an OxCaml compiler** (Jane Street's OCaml fork) — will not compile with stock OCaml.

#### oxcaml_prefetch

- **Source:** custom benchmark (not from sandmark)
- **Build:** ocamlopt (stdlib only)
- **Args:** _(none)_
- **Description:** Spawns 8 domains using `Domain.Safe.spawn` (OxCaml API), each building a large binary tree of depth 28 with 10-byte string leaves. After all domains have built their trees, the main domain runs 10 `Gc.full_major` cycles. Exercises concurrent major GC marking across multiple domains with a large shared live set. Uses `Sys.poll_actions` for cooperative domain coordination and `Atomic` for synchronisation.
- **OxCaml APIs used:** `Domain.Safe.spawn`, `Sys.poll_actions`
- **Suite type:** `OCamlOxcamlBenchmarkSuite` — fails with an error if the runtime is not `type: OxCaml`.

### multicore/multicore-minilight

Parallel global illumination renderer (MiniLight 1.5.2). A Monte Carlo path tracer with an octree spatial index. All nine source modules are compiled together in dependency order using `ocamlfind -package domainslib`. Only the parallel entry point (`minilight_multicore`) is provided; the sequential variant is omitted because its `camera.ml` has a different API signature.

Compilation order: `vector3f → triangle → surfacePoint → spatialIndex → scene → image → rayTracer → camera → minilight_multicore`

#### minilight_multicore

- **Source:** sandmark `benchmarks/multicore-minilight/parallel/` (all modules)
- **Build:** ocamlfind + domainslib (9-module compilation)
- **Args:** `<scene_file>` — path to a MiniLight scene description (e.g. `roomfront.ml.txt`, bundled)
- **Description:** Parallel path tracer. Each frame's pixel rows are distributed across domains using `Task.parallel_for` inside `Camera.frame`. Uses `Domain.DLS` for per-domain `Random.State` to avoid contention. Renders progressively, printing progress to stderr and saving PPM output to `<scene_file>.ppm`. **Note:** the renderer runs until interrupted; for benchmarking, wrap with a timeout or limit iterations in the scene file.

### multicore/graph500par

Parallel Graph500 Kronecker graph generator and BFS kernel. Two executables are built from shared library modules; `gen` must be run first to produce an edge-list data file that `kernel1_run_multicore` then reads.

Compilation order for both executables: `graphTypes → sparseGraph → generate → [gen | kernel1Par → kernel1_run_multicore]`

#### gen

- **Source:** sandmark `benchmarks/graph500par/gen.ml` (+ `generate.ml`, `sparseGraph.ml`, `graphTypes.ml`)
- **Build:** ocamlfind + domainslib + unix
- **Args:** `[-scale SCALE] [-edgefactor EDGE_FACTOR] [-ndomains NUM_DOMAINS] OUTPUT_FILE` — defaults `scale=12 edgefactor=16 ndomains=1`
- **Description:** Kronecker graph generator implementing the Graph500 specification. Generates `2^scale` vertices and `edgefactor * 2^scale` edges using a probabilistic bit-setting algorithm with random permutations. Edge generation uses `Task.parallel_for`. Writes the edge list to `OUTPUT_FILE` via `Marshal`.

#### kernel1_run_multicore

- **Source:** sandmark `benchmarks/graph500par/kernel1_run_multicore.ml` (+ `kernel1Par.ml`, `generate.ml`, `sparseGraph.ml`, `graphTypes.ml`)
- **Build:** ocamlfind + domainslib + unix
- **Args:** `[-ndomains NUM_DOMAINS] EDGE_LIST_FILE`
- **Description:** Graph500 Kernel 1 — parallel construction of a sparse adjacency-list representation. Reads the pre-generated edge list from `EDGE_LIST_FILE`, removes self-loops, finds the maximum vertex label using `Task.parallel_for_reduce`, and builds the sparse graph using `Task.parallel_for` with lock-free `Atomic.t`-based adjacency lists. Reports I/O and construction time.

---

## TODO — Benchmarks Not Yet Added

### Need external opam packages (not yet integrated)

These benchmarks were not added because their dependencies are complex or unusual.

- **`valet`** — Requires `lwt`, `react`, and `uuidm`; unusual event-loop structure.
- **`simple-tests` (partial)** — `ocamlcapi` and `weak_htbl` require C stubs or special build setup; `pingpong_multicore` requires `domainslib`.
- **`irmin`** — Requires `irmin`, `irmin-pack`, `index`, and related packages.
- **`owl`** — Requires `owl-base`.
- **`mpl`** — Requires several packages (`mtime`, `progress`, etc.).

### Need multicore / OCaml 5 effects

These benchmarks require `domainslib`, multiple domains, or OCaml 5 effect handlers, and are not meaningful on OCaml 4.x.

- **`multicore-effects` (partial)** — `algorithmic_differentiation`, `rec_eff_fib`, `rec_seq_fib`, `rec_eff_tak`, `rec_seq_tak`, `rec_eff_ack`, `rec_seq_ack` are in `multicore/multicore-effects/`. Remaining: `queens` requires multi-shot continuations (`Obj.clone_continuation` / `Effect.Deep.clone_continuation`), which were removed in OCaml 5.2 and have no stdlib replacement yet; `eratosthenes` and `test_sched` require the external `lockfree` package.
- **`multicore-grammatrix`** — Added to `multicore/multicore-grammatrix/`.
- **`multicore-minilight`** — Added to `multicore/multicore-minilight/`.
- **`multicore-numerical`** — Added to `multicore/multicore-numerical/`.
- **`multicore-structures`** — Added to `multicore/multicore-structures/`; uses OCaml 5 stdlib `Atomic` (no `kcas` required).
- **`graph500par`** — Added to `multicore/graph500par/`.

### Need C stubs or mixed OCaml/C build

These benchmarks require compiling C foreign stubs alongside OCaml code, which is not yet supported by the simple `ocamlopt` build scripts used here. They may be revisited once a mixed-language build strategy is in place.

- **`multicore-gcroots`** — Tests concurrent GC root registration across domains. The sandmark version wraps internal OCaml GC C APIs (`caml_register_generational_global_root`, etc.) via a C stub library (`globrootsprim`). A pure-OCaml rewrite using `Gc.minor()`/`Gc.full_major()` across domains could approximate the intent, but would not be the same benchmark.

### Need external tool binaries or large external data

These benchmarks invoke external tools (theorem provers, compilers) rather than being self-contained OCaml programs.

- **`alt-ergo`** — Invokes the Alt-Ergo SMT solver on `.why` files.
- **`coq`** — Invokes the Coq proof assistant on `.v` files.
- **`cpdf`** — Requires the `cpdf` PDF tool and large PDF inputs.
- **`cubicle`** — Invokes the Cubicle model checker on `.cub` files.
- **`frama-c`** — Invokes the Frama-C C analyser on `.c` files.
- **`menhir`** — Invokes the Menhir parser generator on `.mly` grammar files.
- **`minilight`** — The sandmark dune file only declares a data file alias (`roomfront.ml.txt`); no executable stanza is present, suggesting the benchmark needs a different integration approach.
