(* compute tak function
 * (adapted from sandmark multicore-effects/rec_eff_tak.ml for OCaml 5.2+ Effect API)
 *)

type _ Effect.t += E : unit Effect.t

let rec tak x y z =
  if y < x then tak
    (Effect.Deep.try_with (fun () -> tak (x-1) y z) ()
      { effc = fun (type a) (eff : a Effect.t) ->
          match eff with
          | E -> Some (fun _ -> assert false)
          | _ -> None })
    (Effect.Deep.try_with (fun () -> tak (y-1) z x) ()
      { effc = fun (type a) (eff : a Effect.t) ->
          match eff with
          | E -> Some (fun _ -> assert false)
          | _ -> None })
    (Effect.Deep.try_with (fun () -> tak (z-1) x y) ()
      { effc = fun (type a) (eff : a Effect.t) ->
          match eff with
          | E -> Some (fun _ -> assert false)
          | _ -> None })
  else z

let rec repeat f acc n =
  if n = 1 then let x = f () in (Printf.printf "%d\n%!" x; x)
  else repeat f (acc + (f ())) (n-1)

let run f n = ignore (Sys.opaque_identity (repeat f 0 n))

let _ =
  let iters = try int_of_string Sys.argv.(1) with _ -> 1 in
  let x = try int_of_string Sys.argv.(2) with _ -> 40 in
  let y = try int_of_string Sys.argv.(3) with _ -> 20 in
  let z = try int_of_string Sys.argv.(4) with _ -> 11 in
  (* default output should be 12 *)
  run (fun () -> tak x y z) iters
