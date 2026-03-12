type tree =
  | Leaf of string
  | Br of tree * string * tree

let rec make n s =
  if n <= 0 then Leaf s
  else Br (make (n-1) s, s, make (n-2) s)

let stop = Atomic.make false

let go counter str =
  let t = make 28 str in
  Atomic.incr counter;
  while not (Atomic.get stop) do Sys.poll_actions () done;
  ignore (Sys.opaque_identity t)

let () =
  let counter = Atomic.make 0 in
  let str = String.make 10 'j' in
  let n = 8 in
  let ds = List.init n (fun _ -> (Domain.Safe.spawn[@alert "-do_not_spawn_domains"]) (fun () -> go counter str)) in
  while Atomic.get counter < n do Sys.poll_actions () done;
  for i = 1 to 10 do
    Gc.full_major ();
    print_endline "gc"
  done;
  Atomic.set stop true;
  List.iter Domain.join ds