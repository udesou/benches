module MSQueue = Saturn_lockfree.Queue
(* adapted from sandmark multicore-effects/ms_sched.ml for OCaml 5.2+ Effect API;
   Lockfree.MSQueue → Saturn_lockfree.Queue,
   Domain.Sync.cpu_relax → Domain.cpu_relax *)

type _ Effect.t +=
  | Fork  : (unit -> unit) -> unit Effect.t
  | Yield : unit Effect.t
  | Exit  : unit Effect.t

let fork f = Effect.perform (Fork f)
let yield () = Effect.perform Yield
let exit () = Effect.perform Exit

let run_q = MSQueue.create ()

(* A concurrent round-robin scheduler *)
let run main =
  let exiting_flag = Atomic.make false in
  let enqueue k = MSQueue.push run_q k in
  let rec dequeue () =
    match MSQueue.pop_opt run_q with
    | None ->
        if Atomic.get exiting_flag then () else (Domain.cpu_relax (); dequeue ())
    | Some y -> Effect.Deep.continue y ()
  in
  let rec spawn f =
    Effect.Deep.match_with f ()
      { Effect.Deep.retc = (fun () -> dequeue ())
      ; exnc = (fun e ->
          print_string (Printexc.to_string e);
          dequeue ())
      ; effc = fun (type a) (eff : a Effect.t) ->
          match eff with
          | Yield ->
              Some (fun (k : (a, _) Effect.Deep.continuation) ->
                enqueue k; dequeue ())
          | Fork f ->
              Some (fun (k : (a, _) Effect.Deep.continuation) ->
                enqueue k; spawn f)
          | Exit ->
              Some (fun (_k : (a, _) Effect.Deep.continuation) ->
                Atomic.set exiting_flag true; dequeue ())
          | _ -> None }
  in
  spawn main

let start n_domains f =
    let rec spawn_domain n =
      if n > 1 then
        begin
          Domain.spawn (fun _ -> run (fun _ -> ())) |> ignore;
          spawn_domain (n-1)
        end
      else if n == 1 then
        begin
          Domain.spawn (fun _ -> run f) |> Domain.join;
        end
      in spawn_domain n_domains
