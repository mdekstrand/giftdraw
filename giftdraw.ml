open Batteries_uni
open Genlex

let printf = Printf.printf

module M = Map.StringMap
module S = Set.StringSet

exception Cannot_match of string

let mail_command = ref "sendmail -t"
let template = ref "email.txt"
let verbose = ref false
let ccs = RefList.empty ()
let commands = [
  Arg.command ~doc:"specify mailer command" "-mailer"
    (Arg.Set_string mail_command);
  Arg.command ~doc:"mail template file" "-template" (Arg.Set_string template);
  Arg.command ~doc:"be verbose (prints names)" "-v" (Arg.Set verbose);
  Arg.command ~doc:"add a CC person" "-cc" (Arg.String (RefList.push ccs));
]

let debug fmt =
  let print s = if !verbose then print_endline s in
  Printf.ksprintf print fmt

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

let rec draw_names igraph users people =
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
    draw_names igraph users people

let subst params str =
  let sparm s (n,v) =
    let r = Str.regexp **> Str.quote ("@" ^ n ^ "@") in
    Str.global_replace r v s
  in
  List.fold_left sparm str params

let print_name emails (u,recip) =
  let email = M.find u emails in
  let text = File.with_file_in (!template) IO.read_all in
  printf "e-mailing %s <%s>\n%!" u email;
  debug "sending name %s -> %s" u recip;
  let params = [
    "GIVER", u;
    "EMAIL", email;
    "RECIPIENT", recip ] in
  let text = subst params text in
  let outch = Unix.open_process_out (!mail_command) in
  let dispose = IO.close_out in
  let send_mail outch = IO.output outch text 0 (String.length text) in
  ignore (using ~dispose outch send_mail)

let _ = Arg.handle commands

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
let () = File.with_file_in "/dev/urandom" seed_random;;

foreach (M.enum (draw_names igraph users users))
  (print_name email)
