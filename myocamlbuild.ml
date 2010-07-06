(* ocamlbuild plugin for building Batteries.  
 * Copyright (C) 2010 Michael Ekstrand
 * 
 * Portions (hopefully trivial) from build/myocamlbuild.ml and the
 * Gallium wiki. *)

open Ocamlbuild_plugin

let ocamlfind x = S[A"ocamlfind"; A x]

let packs = String.concat "," ["batteries"; "camlp4"]

let pkg_flags = [A"-package"; A packs; A"-syntax"; A"camlp4o"]
let syn_flags = [A"-syntax"; A"camlp4o"]

let _ = dispatch begin function
  | Before_options ->
      (* Set up to use ocamlfind *)
      Options.ocamlc     := ocamlfind "ocamlc";
      Options.ocamlopt   := ocamlfind "ocamlopt";
      Options.ocamldep   := ocamlfind "ocamldep";
      Options.ocamldoc   := ocamlfind "ocamldoc";
      Options.ocamlmktop := ocamlfind "ocamlmktop"
  | After_rules ->
      (* When one links an OCaml program, one should use -linkpkg *)
      flag ["ocaml"; "link"; "program"] & A"-linkpkg";

      flag ["ocaml"; "compile"] & S [S pkg_flags; S syn_flags];
      flag ["ocaml"; "ocamldep"] & S [S pkg_flags; S syn_flags];
      flag ["ocaml"; "doc"] & S [S pkg_flags; S syn_flags];
      flag ["ocaml"; "link"] & S pkg_flags;
      flag ["ocaml"; "infer_interface"] & S[A"-package"; A packs];
  | _ -> ()
end
