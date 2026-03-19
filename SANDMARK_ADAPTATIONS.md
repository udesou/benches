# Sandmark Benchmark Adaptations

Changes made to benchmark source files when porting from
[sandmark](https://github.com/ocaml-bench/sandmark). These are not
incompatibilities (see `BENCHMARK_INCOMPATIBILITIES.md`) but deliberate
edits required for the benchmarks to build or run correctly outside the
sandmark dune project.

---

## multicore-effects: Effect API migration (OCaml 5.2+)

**Affects:** all benchmarks in `multicore/multicore-effects/`

**Sandmark originals use the pre-5.2 `effect` keyword syntax**, which was
part of the early multicore OCaml prototype and is a parse error in OCaml
5.2+:

```ocaml
(* sandmark — does not compile in OCaml 5.2+ *)
effect E : int -> int
let g () = perform (E 1)
match g () with
| effect (E x) k -> continue k x
| x -> x
```

All ported files use the OCaml 5.2+ `Effect` module API instead:

```ocaml
(* benches — OCaml 5.2+ *)
type _ Effect.t += E : int -> int Effect.t
let g () = Effect.perform (E 1)
Effect.Deep.try_with g ()
  { effc = fun (type a) (eff : a Effect.t) ->
      match eff with
      | E x -> Some (fun (k : (a, _) Effect.Deep.continuation) ->
          Effect.Deep.continue k x)
      | _ -> None }
```

The translation is mechanical:

| Sandmark (old API) | benches (OCaml 5.2+) |
|---|---|
| `effect E : t` | `type _ Effect.t += E : t Effect.t` |
| `perform (E v)` | `Effect.perform (E v)` |
| `match f () with \| effect (E x) k -> continue k x \| v -> v` | `Effect.Deep.try_with f () { effc = fun (type a) (eff : a Effect.t) -> match eff with \| E x -> Some (fun (k : (a,_) Effect.Deep.continuation) -> Effect.Deep.continue k x) \| _ -> None }` |
| `match f () with \| effect E k -> ... \| v -> v` (unit effect) | same pattern; `E` matches without payload |
| Multi-handler (`retc`/`exnc` needed) | `Effect.Deep.match_with` instead of `try_with` |

### Ported files

- `algorithmic_differentiation.ml`
- `rec_eff_fib.ml`, `rec_seq_fib.ml`
- `rec_eff_tak.ml`, `rec_seq_tak.ml`
- `rec_eff_ack.ml`, `rec_seq_ack.ml`
- `effect_throughput_val.ml`
- `effect_throughput_perform.ml`
- `effect_throughput_perform_drop.ml`
- `eratosthenes.ml`

### Not ported — `Obj.clone_continuation` removed in OCaml 5.x

Two sandmark benchmarks use `Obj.clone_continuation`, which was part of
the multicore prototype and has **no equivalent in OCaml 5.x's `Effect`
module**:

- **`effect_throughput_clone.ml`** — measures continuation-cloning
  throughput. The feature being benchmarked (`Obj.clone_continuation`)
  does not exist in OCaml 5.x; there is no faithful port.

- **`queens.ml`** — implements backtracking via cloned continuations
  (`Obj.clone_continuation k` to re-enter the same choice point with
  different values). OCaml 5.x continuations are one-shot; there is no
  public `clone_continuation` API. A port would require restructuring the
  algorithm (e.g. explicit choice stack or a non-determinism monad),
  which changes what the benchmark measures.

Note: `Effect.Deep.clone_continuation` was proposed but removed before
OCaml 5.0 shipped due to safety concerns. There is no timeline for it
being re-added to the stdlib.

### Ported with package change — `lockfree` → `saturn_lockfree`

- **`ms_sched.ml` / `test_sched.ml`** — ported to
  `with_packages/test_sched/`. Three mechanical changes from the sandmark
  original:

  1. `module MSQueue = Lockfree.MSQueue` →
     `module MSQueue = Saturn_lockfree.Queue`.
     `saturn_lockfree` is the successor package; `Saturn_lockfree.Queue`
     is the Michael–Scott queue. Note `pop` was renamed: use `pop_opt`
     (returns `'a option`, same semantics).

  2. `Domain.Sync.cpu_relax ()` → `Domain.cpu_relax ()`.
     The `Domain.Sync` submodule was removed in OCaml 5.x;
     `Domain.cpu_relax` is available at the top level since OCaml 5.0.

  3. Effect syntax migration — same as the other ported files (`Fork`,
     `Yield`, `Exit` effects rewritten with `type _ Effect.t +=` and
     `Effect.Deep.match_with`).

  The benchmark lives in `with_packages/` because it depends on
  `saturn_lockfree`. Both source files are compiled together with
  `ocamlfind -package saturn_lockfree -linkpkg` (no dune needed).

---

## simple-tests/weak_htbl.ml: OCaml 5.x compatibility

**Affects:** `simple/simple-tests/weak_htbl.ml`

Two changes from the sandmark original:

### 1. `Pervasives.compare` → `compare`

`Pervasives` was removed in OCaml 5.x (it was already a deprecated alias for
`Stdlib`). Five occurrences in the `SS`, `SI`, `SSP`, `SSL`, `SSA` module
definitions replaced with bare `compare`.

### 2. Ephemeron iteration stubs (`iter`/`fold`/etc. removed in OCaml 5.x)

OCaml 5.x removed `iter`, `fold`, `filter_map_inplace`, `to_seq`,
`to_seq_keys`, `to_seq_values` from `Ephemeron.K{1,2,n}.Make`. These were
dropped because iterating over a weak hash table is semantically
problematic — live entries can disappear between GC cycles.

The sandmark `Test` functor used `H.iter` to verify correctness. Two changes
were made:

1. A local `HashS` signature replaces the `Hashtbl.S` parameter for `Test`,
   listing only what `Test` actually uses: `create`, `clear`, `add`,
   `replace`, `remove`, `find`, `iter`.

2. An `EphCompat` functor wraps `Ephemeron.K{1,2,n}.Make` modules and adds
   a no-op `iter`. The correctness assertions in `Test(WS)(...)` will
   vacuously pass (iterating zero live entries), which is the most faithful
   port achievable without adding a shadow table.

Also added the missing `to_seq*`/`add_seq`/`replace_seq`/`of_seq` methods to
the `HofM` (generic hash-over-map) wrapper to satisfy the full `Hashtbl.S`
signature in OCaml 5.x.

---

## decompress: API update to 1.5.3

**Affects:** `with_packages/decompress/test_decompress.ml`

The `decompress` library changed its API in version 1.5.3:

| Change | sandmark | benches |
|---|---|---|
| `~i`/`~o` labels | labeled (`~i:buf ~o:buf`) | positional |
| Window type | `De.window` | `De.Lz77.window` |
| `uncompress` return | `unit` | `(unit, error) result` |

---

## graph500seq / graph500par: `graphTypes.ml` extracted

**Affects:** `with_deps/graph500seq/`, `multicore/graph500par/`

In sandmark, the `GraphTypes` module (`type vertex = int`,
`type weight = float`, `type edge = vertex * vertex * weight`) is defined
in a parent dune scope shared by both the generator and kernel
executables. Outside of sandmark's dune project, this scope does not
exist.

**Fix:** a small `graphTypes.ml` is added to each benchmark directory and
compiled first. The file is otherwise identical to the type definitions
inlined in sandmark's dune configuration.

---

## benchmarksgame: input file path via `argv[1]`

**Affects:** `with_deps/benchmarksgame/knucleotide.ml`, `knucleotide3.ml`,
`revcomp2.ml`, `regexredux2.ml`

In sandmark, all four benchmarks open their input file with a hardcoded
relative filename (`"input25000000.txt"` or `"input5000000.txt"`),
relying on the benchmark being run from the sandmark build directory:

```ocaml
(* sandmark *)
let kinput = open_in "input25000000.txt" in
```

Outside sandmark, `running-ng` runs benchmarks from a temporary directory,
so the relative path fails. Each file was changed to accept an optional
absolute path as `argv[1]`, falling back to the hardcoded name for
standalone use:

```ocaml
(* benches *)
let kinput = open_in (if Array.length Sys.argv > 1 then Sys.argv.(1) else "input25000000.txt") in
```

The input files themselves are generated by `benchmarksgame.build.deps.sh`
(which builds `fasta3.exe` and runs it) and placed in the benchmark
directory. Running-ng passes the absolute path via the `args` field in the
suite config.

---

## minilight (sequential): spurious `domainslib` dependency dropped

**Affects:** `simple/minilight/dune`

Sandmark's `multicore-minilight/sequential/` dune file lists
`(libraries domainslib)` despite none of the 9 sequential source files
importing or using it. The dependency was inherited from the parallel
version's dune and never cleaned up.

The ported dune omits `domainslib` entirely, keeping the build stdlib-only
and compatible with OCaml 4.x and 5.x without requiring domainslib to be
installed.

**Source files:** identical to sandmark.

---

## owl/owl_gc: `owl` → `owl-base` in dune

**Affects:** `with_packages/owl/dune`

Sandmark's dune uses `(libraries owl unix)`, which pulls in the full `owl`
package including CBLAS and LAPACK C bindings. `owl_gc.ml` does not use any
BLAS/LAPACK operations — the matrix multiplications in `Mat.dot` are
exercising GC behaviour via `Bigarray` allocation, not numerical performance.

The ported dune uses `(libraries owl-base unix)`. `owl-base` is the pure
OCaml subset of Owl that provides identical module APIs (`Owl`,
`Owl_dense_matrix_d`, `Owl_dense_ndarray_d`) without C stubs, making the
benchmark buildable on any platform without a BLAS installation.

**Source file:** identical to sandmark.

---

## simple-tests/capi: `(modes native)` added to dune

**Affects:** `simple/capi/dune`

`ocamlcapi.ml` declares 7-argument externals with two C symbol names (bytecode
and native):

```ocaml
external test_many_args_alloc : int -> ... -> int =
  "test_many_args_noalloc_bc" "test_many_args_alloc_nc"
```

The bytecode symbol (`_bc`) is not defined in `ocamlcapi.c` — only the
native symbol (`_nc`) is. Sandmark's dune avoids this because the
top-level project controls the build modes. Outside of that context, dune
defaults to building both native and bytecode, causing the bytecode link to
fail with an undefined symbol.

**Fix:** `(modes native)` is added to both the `(library ocamlcapi)` and
`(executable capi)` stanzas. This matches what sandmark's dune effectively
produces and is correct — these benchmarks are only meaningful when compiled
natively.

**Source files:** identical to sandmark. (`test-capi.ml` is not ported — it
is not listed in sandmark's dune stanzas and has a hyphen in its filename.)

---

## irmin/replay.ml: skipped — trace file not available

**Affects:** `sandmark/benchmarks/irmin/replay.ml`

**Not ported.** The benchmark replays a Tezos mainnet commit trace using
`irmin-bench.traces`. The trace file path is hardcoded in the source:

```ocaml
replay_trace_path = "/tmp/irmin-data/data4_100066commits.repr";
```

This file is approximately 6.5 GB and must be downloaded separately via
irmin-bench's trace download tooling — it cannot be bundled and there is
no fallback for a missing file. The dependency stack (`irmin-pack`,
`irmin-tezos`, `irmin-bench.traces`) is also the full Tezos storage
ecosystem.

**What would be needed to port it:**
- Modify `replay.ml` to accept the trace path as `argv[2]` instead of
  hardcoding it (trivial source change).
- Add a `replay.build.deps.sh` that downloads the trace via
  `irmin-bench`'s download tooling (~6.5 GB, one-time).
- Add to `with_packages/` with auto-install of `irmin-pack irmin-tezos
  irmin-bench`.

**`irmin_mem_rw.ml` (also in the sandmark directory) is not built** by
sandmark's own dune — it was apparently abandoned. It uses an in-memory
Irmin store with no trace file, but its `Irmin.Info.v` API is
incompatible with irmin 3.x and would require adaptation.
