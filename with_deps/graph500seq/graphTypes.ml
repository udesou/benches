(* Type definitions shared across the graph500seq modules.
   In the original sandmark project this module is provided by a parent
   dune-project scope; here it is defined explicitly for standalone builds. *)

type vertex = int
type weight = float
type edge = vertex * vertex * weight
