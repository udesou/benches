(* compute fib recursively
 * with each recursion in its own fiber
 * (adapted from sandmark multicore-effects/rec_eff_fib.ml for OCaml 5.2+ Effect API)
 *)

type _ Effect.t += E : unit Effect.t

let rec fib n =
  match n with
  | 0 -> 0
  | 1 -> 1
  | n ->
    Effect.Deep.try_with (fun () -> fib (n-1)) ()
      { effc = fun (type a) (eff : a Effect.t) ->
          match eff with
          | E -> Some (fun _ -> assert false)
          | _ -> None }
    + Effect.Deep.try_with (fun () -> fib (n-2)) ()
      { effc = fun (type a) (eff : a Effect.t) ->
          match eff with
          | E -> Some (fun _ -> assert false)
          | _ -> None }

let rec repeat f acc n =
  if n = 1 then let x = f () in (Printf.printf "%d\n%!" x; x)
  else repeat f (acc + (f ())) (n-1)

let run f n = ignore (Sys.opaque_identity (repeat f 0 n))

let _ =
  let iters = try int_of_string Sys.argv.(1) with _ -> 4 in
  let n = try int_of_string Sys.argv.(2) with _ -> 40 in
  (* default output should be 102334155 *)
  run (fun () -> fib n) iters
