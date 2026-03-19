(*
 *  This test intends to measure the throughput of an effect handler
 *  block where perform is never called and a value is returned.
 *  It will include:
 *    - new stack creation for the function to be executed
 *    - switching stack to the new stack
 *    - switching stacks back to the old stack with a value return
 *    - freeing the stack created to evaluate the function
 * (adapted from sandmark multicore-effects/effect_throughput_val.ml for OCaml 5.2+ Effect API)
 *)

let n_iter = try int_of_string Sys.argv.(1) with _ -> 1_000_000

let now = Sys.time

type _ Effect.t += E : unit Effect.t

let g () = 1

let h () =
    let t0 = now () in

    for _ = 1 to n_iter do
        ignore (Sys.opaque_identity(
            Effect.Deep.try_with g ()
              { effc = fun (type a) (eff : a Effect.t) ->
                  match eff with
                  | E -> Some (fun _ -> assert false)
                  | _ -> None }
        ))
    done;

    let t = (now ()) -. t0 in
    Printf.printf "%i iterations took %f\n%!" n_iter t;
    Printf.printf "%.1fns per iteration\n%!" ((t*.1e9)/. (float_of_int n_iter))

let _ = h ()
