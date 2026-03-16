# OxCaml Build Incompatibilities

Tested with OxCaml commit `068b25529286862035eaf827230f7ffa86659c49`.

## Summary

Out of 77 benchmarks, **5 fail to build** with OxCaml.
72 benchmarks build successfully.

## Failures

### 1. mandelbrot6_multicore (multicore-numerical)

**Category:** OxCaml type system incompatibility in benchmark source

OxCaml's `output_bytes` has signature `out_channel -> bytes @ local -> unit`.
The `@ local` annotation makes it incompatible with `Array.iter`'s expected
callback type `'a -> unit`. Stock OCaml's `output_bytes` has no locality
annotation.

```
Error: This expression has type out_channel -> bytes @ local -> unit
       but an expression was expected of type 'a -> unit
```

**Fix:** Would require modifying the source, which would break stock OCaml builds.

### 2–4. chameneos_redux_lwt, thread_ring_lwt_mvar, thread_ring_lwt_stream (sandmark-with-packages)

**Category:** OxCaml type system incompatibility in opam package (lwt)

With dune-configurator now built from source (csexp + dune-configurator both
compile cleanly with OxCaml), the lwt dependency chain resolves. However,
`lwt_unix` itself fails to compile due to OxCaml locality annotations on the
`Unix` module:

```
File "src/unix/lwt_unix.cppo.ml", line 1552, characters 51-60:
Error: This expression has type
         "Unix.file_descr -> Bytes.t -> int -> int -> Unix.msg_flag list -> int"
       but an expression was expected of type
         "Unix.file_descr -> bytes @ local -> int -> int -> Unix.msg_flag list @ local -> int"
```

**Fix:** Would require patching lwt upstream or maintaining an OxCaml fork.

### 5. ydump (sandmark-with-packages)

**Category:** OxCaml type system incompatibility in opam package (yojson)

The `yojson` library's `write_intlit` function gets an OxCaml locality type
error:

```
Error: This expression has type Buffer.t @ local -> string @ local -> unit
       but an expression was expected of type Buffer.t -> string -> unit
```

**Fix:** Would require patching yojson upstream or maintaining an OxCaml fork.

## Fixed

### test_decompress (sandmark-with-packages)

Was failing due to decompress 1.5.3 API changes (not OxCaml-specific):
- `Higher.compress`/`uncompress`: `~i`/`~o` labels removed, now positional args
- `~w` parameter: `De.window` -> `De.Lz77.window`
- `Higher.uncompress` return type: now `(unit, error) result`

Fixed in `test_decompress.ml`. Works with both stock OCaml and OxCaml.

## Working Benchmarks (72)

All benchmarks in these suites build successfully:
- **sandmark-sequential** (18/18): almabench, bdd, binarytrees, hamming, soli, kb, kb_no_exc, lexifi-g2pp, zdd, fannkuchredux, crout_decomposition, qr_decomposition, durand_kerner_aberth, fft, levinson_durbin, naive_multilayer, markbench, sequence_cps
- **sandmark-with-deps** (1/1): graph500seq
- **sandmark-with-packages** (12/16): binarytrees5, fasta3, fasta6, mandelbrot6, nbody, pidigits5, spectralnorm2, zarith_fact, zarith_fib, zarith_pi, zarith_tak, test_decompress
- **multicore-effects** (7/7): all
- **multicore-structures** (7/7): all
- **multicore-numerical** (18/19): all except mandelbrot6_multicore
- **multicore-grammatrix** (2/2): grammatrix, grammatrix_multicore
- **multicore-minilight** (1/1): minilight_multicore
- **graph500par** (1/1): kernel1_run_multicore
- **oxcaml-prefetch** (1/1): oxcaml_prefetch
