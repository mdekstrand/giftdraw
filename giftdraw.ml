open Batteries_uni
open Genlex

module M = Map.StringMap
module S = Set.StringSet

exception Cannot_match of string

let rec parse_block = parser
  | [< 'Kwd "block"; 'String n1; 'String n2; blocks = parse_block >] ->
      (n1,n2) :: blocks
  | [< >] -> []

let rec parse_uspec = parser
  | [< 'Kwd "person"; 'String name; 'String email;
       (users, blocks) = parse_uspec >] ->
      (name,email)::users, blocks
  | [< blocks = parse_block >] ->
      [], blocks
  | [< >] -> [], []

let users, blocks = Stream.of_channel Legacy.stdin
  |> make_lexer ["person"; "block"] |> parse_uspec

let email = List.enum users |> M.of_enum

let igraph = List.enum users /@ (fun (u,_) -> (u,S.singleton u))
  |> M.of_enum
let igraph = List.enum blocks |> fold
  (fun b (u1,u2) ->
    let s1 = M.find u1 b in
    let s2 = M.find u2 b in
    let b' = M.add u1 (S.add u2 s1) b in
    M.add u2 (S.add u1 s2) b')
  igraph

let users = 
  let cmp u1 u2 =
    let c1 = S.cardinal (M.find u1 igraph) in
    let c2 = S.cardinal (M.find u2 igraph) in
    compare c2 c1 in
  List.sort ~cmp (List.map fst users)

let rec seed_random inch =
  try Random.init (input_binary_int inch)
  with BatInnerIO.Overflow "read_i32" -> seed_random inch
let () = File.with_file_in "/dev/urandom" seed_random

let rec draw_names people = 
  try
    let alloc, _ = List.enum people |> fold
        (fun (a,us) u ->
          let blocked = M.find u igraph in
          let candidates = S.diff us blocked in
          if S.is_empty candidates then raise (Cannot_match u);
          let c = S.enum candidates |> Random.choice in
          M.add u c a, S.remove c us)
        (M.empty, (List.enum users |> S.of_enum))
    in alloc
  with Cannot_match p ->
    Printf.fprintf stderr "Cannot match %s, retrying\n%!" p;
    draw_names people
in
foreach (M.enum (draw_names users))
  (fun (u,recip) -> Printf.printf "%s: %s\n" u recip)
