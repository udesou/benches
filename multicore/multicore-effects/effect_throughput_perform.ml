(*
 *  This test intends to measure the throughput of an effect handler
 *  block where perform is called, then the continuation resumed
 *  and a value is returned.
 *  It will include:
 *    - new stack creation for the function to be executed
 *    - switching stack to the new stack
 *    - doing the perform and switching stacks back to the old stack
 *    - resuming the continuation
 *    - switching stacks back to the old stack with a value return
 *    - freeing the stack created to evaluate the function
 * (adapted from sandmark multicore-effects/effect_throughput_perform.ml for OCaml 5.2+ Effect API)
 *)

let n_iter = try int_of_string Sys.argv.(1) with _ -> 1_000_000

let now = Sys.time

type _ Effect.t += E : int -> int Effect.t

let g () = Effect.perform (E 1)

let h () =
    let t0 = now () in

    for _ = 1 to n_iter do
        ignore (Sys.opaque_identity(
            Effect.Deep.try_with g ()
              { effc = fun (type a) (eff : a Effect.t) ->
                  match eff with
                  | E x -> Some (fun (k : (a, _) Effect.Deep.continuation) ->
                      Effect.Deep.continue k x)
                  | _ -> None }
        ))
    done;

    let t = (now ()) -. t0 in
    Printf.printf "%i iterations took %f\n%!" n_iter t;
    Printf.printf "%.1fns per iteration\n%!" ((t*.1e9)/. (float_of_int n_iter))

let _ = h ()
