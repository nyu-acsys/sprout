open Printf

(* Define basic types *)
type state = int
type participant = string
type variable = string

(* Define formula type *)
type formula =
  | True
  | False
  | Eq of expr * expr
  | Neq of expr * expr 
  | Lt of expr * expr
  | Leq of expr * expr 
  | Gt of expr * expr
  | Geq of expr * expr 
  | And of formula * formula
  | Or of formula * formula
  | Not of formula

and expr =
  | Const of int
  | Var of variable
  | VarPrime of variable 
  | Plus of expr * expr
  | Minus of expr * expr
  | Times of expr * expr
  | Div of expr * expr
  | Mod of expr * expr

(* Define symbolic transition *)
type symbolic_transition = {
  pre: state;
  sender: participant;
  receiver: participant;
  comm_var: variable;
  predicate: formula;
  post: state;
}

(* Define symbolic protocol *)
type symbolic_protocol = {
  states: state list;
  registers: variable list;
  transitions: symbolic_transition list;
  initial_state: state;
  initial_register_assignment: (variable * int) list;
  final_states: state list;
}

(* Equality functions *)
let rec expr_eq e1 e2 =
  match (e1, e2) with
  | (Const n1, Const n2) -> n1 = n2
  | (Var v1, Var v2) -> v1 = v2
  | (VarPrime v1, VarPrime v2) -> v1 = v2
  | (Plus (a1, b1), Plus (a2, b2)) -> expr_eq a1 a2 && expr_eq b1 b2
  | (Minus (a1, b1), Minus (a2, b2)) -> expr_eq a1 a2 && expr_eq b1 b2
  | (Times (a1, b1), Times (a2, b2)) -> expr_eq a1 a2 && expr_eq b1 b2
  | (Div (a1, b1), Div (a2, b2)) -> expr_eq a1 a2 && expr_eq b1 b2
  | (Mod (a1, b1), Mod (a2, b2)) -> expr_eq a1 a2 && expr_eq b1 b2
  | _ -> false

let rec formula_eq f1 f2 =
  match (f1, f2) with
  | (True, True) | (False, False) -> true
  | (Neq (e1, e2), Neq (e3, e4)) -> expr_eq e1 e3 && expr_eq e2 e4
  | (Eq (e1, e2), Eq (e3, e4)) -> expr_eq e1 e3 && expr_eq e2 e4
  | (Leq (e1, e2), Neq (e3, e4)) -> expr_eq e1 e3 && expr_eq e2 e4
  | (Geq (e1, e2), Neq (e3, e4)) -> expr_eq e1 e3 && expr_eq e2 e4
  | (Lt (e1, e2), Lt (e3, e4)) -> expr_eq e1 e3 && expr_eq e2 e4
  | (Gt (e1, e2), Gt (e3, e4)) -> expr_eq e1 e3 && expr_eq e2 e4
  | (And (a1, b1), And (a2, b2)) -> formula_eq a1 a2 && formula_eq b1 b2
  | (Or (a1, b1), Or (a2, b2)) -> formula_eq a1 a2 && formula_eq b1 b2
  | (Not f1, Not f2) -> formula_eq f1 f2
  | _ -> false

let symbolic_transition_eq t1 t2 =
  t1.pre = t2.pre &&
  t1.sender = t2.sender &&
  t1.receiver = t2.receiver &&
  t1.comm_var = t2.comm_var &&
  formula_eq t1.predicate t2.predicate &&
  t1.post = t2.post

(* Some ugliness to print primes before 1/2 in the case that the variable ends with 1/2 *)
let ends_with_one (s: string) : bool =
  let len = String.length s in
  if len = 0 then
    false  
  else
    s.[len - 1] = '1'  

let ends_with_two (s: string) : bool =
  let len = String.length s in
  if len = 0 then
    false  
  else
    s.[len - 1] = '2'  

let handle_varprime (e: expr) : string = 
  match e with 
  | VarPrime v -> let len = String.length v in 
                  if ends_with_one v then String.sub v 0 (len-1) ^ "'" ^ "1" 
                else if ends_with_two v then String.sub v 0 (len-1) ^ "'" ^ "2" 
              else v ^ "'"
  | _ -> ""

let rec string_of_expr = function
  | Const n -> string_of_int n
  | Var v -> v
  | VarPrime v -> handle_varprime (VarPrime v)
  | Plus (e1, e2) -> "(" ^ string_of_expr e1 ^ " + " ^ string_of_expr e2 ^ ")"
  | Minus (e1, e2) -> "(" ^ string_of_expr e1 ^ " - " ^ string_of_expr e2 ^ ")"
  | Times (e1, e2) -> "(" ^ string_of_expr e1 ^ " * " ^ string_of_expr e2 ^ ")"
  | Div (e1, e2) -> "(" ^ string_of_expr e1 ^ " / " ^ string_of_expr e2 ^ ")"
  | Mod (e1, e2) -> "(" ^ string_of_expr e1 ^ " % " ^ string_of_expr e2 ^ ")"

let rec string_of_formula = function
  | True -> "true"
  | False -> "false"
  | Eq (e1, e2) -> "(" ^ string_of_expr e1 ^ " = " ^ string_of_expr e2 ^ ")"
  | Neq (e1, e2) -> "(" ^ string_of_expr e1 ^ " != " ^ string_of_expr e2 ^ ")"
  | Geq (e1, e2) -> "(" ^ string_of_expr e1 ^ " >= " ^ string_of_expr e2 ^ ")"
  | Leq (e1, e2) -> "(" ^ string_of_expr e1 ^ " <= " ^ string_of_expr e2 ^ ")"
  | Lt (e1, e2) -> "(" ^ string_of_expr e1 ^ " < " ^ string_of_expr e2 ^ ")"
  | Gt (e1, e2) -> "(" ^ string_of_expr e1 ^ " > " ^ string_of_expr e2 ^ ")"
  | And (f1, f2) -> "(" ^ string_of_formula f1 ^ " /\\ " ^ string_of_formula f2 ^ ")"
  | Or (f1, f2) -> "(" ^ string_of_formula f1 ^ " \\/ " ^ string_of_formula f2 ^ ")"
  | Not f -> "! (" ^ string_of_formula f ^ ")"

let symbolic_protocol_eq p1 p2 =
  let print_diff name v1 v2 = 
    printf "Protocols differ in %s:\n  P1: %s\n  P2: %s\n" name v1 v2
  in
  let print_transition_diff t1 t2 =
    if t1.pre <> t2.pre then
      printf "  Pre-state differs: P1: %d, P2: %d\n" t1.pre t2.pre;
    if t1.post <> t2.post then
      printf "  Post-state differs: P1: %d, P2: %d\n" t1.post t2.post;
    if t1.sender <> t2.sender then
      printf "  Sender differs: P1: %s, P2: %s\n" t1.sender t2.sender;
    if t1.receiver <> t2.receiver then
      printf "  Receiver differs: P1: %s, P2: %s\n" t1.receiver t2.receiver;
    if t1.comm_var <> t2.comm_var then
      printf "  Communication variable differs: P1: %s, P2: %s\n" t1.comm_var t2.comm_var;
    if not (formula_eq t1.predicate t2.predicate) then
      printf "  Predicate differs: P1: %s, P2: %s\n" 
        (string_of_formula t1.predicate) (string_of_formula t2.predicate)
  in
  let rec compare_transitions t1 t2 index =
    match (t1, t2) with
    | [], [] -> true
    | [], _ -> 
        printf "Extra transition in P2 at index %d:\n" index;
        List.iteri (fun i t -> 
          printf "  Transition %d: %d->%d, sender: %s, receiver: %s, comm_var: %s, predicate: %s\n"
            (index + i) t.pre t.post t.sender t.receiver t.comm_var (string_of_formula t.predicate)
        ) t2;
        false
    | _, [] -> 
        printf "Extra transition in P1 at index %d:\n" index;
        List.iteri (fun i t -> 
          printf "  Transition %d: %d->%d, sender: %s, receiver: %s, comm_var: %s, predicate: %s\n"
            (index + i) t.pre t.post t.sender t.receiver t.comm_var (string_of_formula t.predicate)
        ) t1;
        false
    | h1::r1, h2::r2 ->
        if not (symbolic_transition_eq h1 h2) then
          (printf "Transition differs at index %d:\n" index;
           print_transition_diff h1 h2;
           false)
        else compare_transitions r1 r2 (index + 1)
  in
  if p1.states <> p2.states then
    (print_diff "states" (String.concat "," (List.map string_of_int p1.states))
                         (String.concat "," (List.map string_of_int p2.states));
     false)
  else if p1.registers <> p2.registers then
    (print_diff "registers" (String.concat "," p1.registers)
                            (String.concat "," p2.registers);
     false)
  else if not (compare_transitions p1.transitions p2.transitions 0) then
    false
  else if p1.initial_state <> p2.initial_state then
    (print_diff "initial_state" (string_of_int p1.initial_state)
                                (string_of_int p2.initial_state);
     false)
  else if p1.initial_register_assignment <> p2.initial_register_assignment then
    (print_diff "initial_register_assignment" 
       (String.concat "," (List.map (fun (v,n) -> sprintf "%s=%d" v n) p1.initial_register_assignment))
       (String.concat "," (List.map (fun (v,n) -> sprintf "%s=%d" v n) p2.initial_register_assignment));
     false)
  else if p1.final_states <> p2.final_states then
    (print_diff "final_states" (String.concat "," (List.map string_of_int p1.final_states))
                               (String.concat "," (List.map string_of_int p2.final_states));
     false)
  else
    true

(* Print functions *)

let rec print_expr = function
  | Const n -> printf "Const(%d)" n
  | Var v -> printf "Var(\"%s\")" v
  | VarPrime v -> printf "VarPrime(\"%s\")" v
  | Plus (e1, e2) -> printf "Plus("; print_expr e1; printf ", "; print_expr e2; printf ")"
  | Minus (e1, e2) -> printf "Minus("; print_expr e1; printf ", "; print_expr e2; printf ")"
  | Times (e1, e2) -> printf "Times("; print_expr e1; printf ", "; print_expr e2; printf ")"
  | Div (e1, e2) -> printf "Div("; print_expr e1; printf ", "; print_expr e2; printf ")"
  | Mod (e1, e2) -> printf "Mod("; print_expr e1; printf ", "; print_expr e2; printf ")"


let rec print_formula = function
  | True -> printf "True"
  | False -> printf "False"
  | Eq (e1, e2) -> printf "Eq("; print_expr e1; printf ", "; print_expr e2; printf ")"
  | Lt (e1, e2) -> printf "Lt("; print_expr e1; printf ", "; print_expr e2; printf ")"
  | Gt (e1, e2) -> printf "Gt("; print_expr e1; printf ", "; print_expr e2; printf ")"
  | Neq (e1, e2) -> printf "Neq("; print_expr e1; printf ", "; print_expr e2; printf ")"
  | Leq (e1, e2) -> printf "Leq("; print_expr e1; printf ", "; print_expr e2; printf ")"
  | Geq (e1, e2) -> printf "Geq("; print_expr e1; printf ", "; print_expr e2; printf ")"  
  | And (f1, f2) -> printf "And("; print_formula f1; printf ", "; print_formula f2; printf ")"
  | Or (f1, f2) -> printf "Or("; print_formula f1; printf ", "; print_formula f2; printf ")"
  | Not f -> printf "Not("; print_formula f; printf ")"


let print_symbolic_transition t =
  printf "{\n";
  printf "  pre = %d;\n" t.pre;
  printf "  sender = \"%s\";\n" t.sender;
  printf "  receiver = \"%s\";\n" t.receiver;
  printf "  comm_var = \"%s\";\n" t.comm_var;
  printf "  predicate = "; print_formula t.predicate; printf ";\n";
  printf "  post = %d;\n" t.post;
  printf "}"

let print_symbolic_protocol p =
  printf "{\n";
  printf "  states = [%s];\n" (String.concat "; " (List.map string_of_int p.states));
  printf "  registers = [%s];\n" (String.concat "; " (List.map (sprintf "\"%s\"") p.registers));
  printf "  transitions = [\n";
  List.iter (fun t -> print_symbolic_transition t; printf ";\n") p.transitions;
  printf "  ];\n";
  printf "  initial_state = %d;\n" p.initial_state;
  printf "  initial_register_assignment = [%s];\n" 
    (String.concat "; " (List.map (fun (v, n) -> sprintf "(\"%s\", %d)" v n) p.initial_register_assignment));
  printf "  final_states = [%s];\n" (String.concat "; " (List.map string_of_int p.final_states));
  printf "}\n"


(* Print functions for visualization *)
  let rec get_string_for_expr = function
  | Const n -> Printf.sprintf "%d" n
  | Var v -> Printf.sprintf "%s" v
  | VarPrime v -> Printf.sprintf "%s'" v (* TODO: unclear if this works as supposed to *)
  | Plus (e1, e2) -> 
      Printf.sprintf "(%s+%s)" (get_string_for_expr e1) (get_string_for_expr e2)
  | Minus (e1, e2) -> 
      Printf.sprintf "(%s-%s)" (get_string_for_expr e1) (get_string_for_expr e2)
  | Times (e1, e2) -> 
      Printf.sprintf "(%s*%s)" (get_string_for_expr e1) (get_string_for_expr e2)
  | Div (e1, e2) -> 
      Printf.sprintf "(%s/%s)" (get_string_for_expr e1) (get_string_for_expr e2)
  | Mod (e1, e2) -> 
      Printf.sprintf "(%s%%%s)" (get_string_for_expr e1) (get_string_for_expr e2)

(* Omitting parentheses not according to precedence but associativity only for /\ and \/ *)
type enum = LastAnd | LastOr | LastDiff

let remove_empty_and_parenthesize s1 s2 op parenL parenR = 
  match s1, s2 with 
    None, None -> None
  | Some s1', None -> Some s1'
  | None, Some s2' -> Some s2'
  | Some s1', Some s2' -> Some (Printf.sprintf "%s%s%s%s%s" parenL s1' op s2' parenR)

(* 2nd parameter gives last operator for omitting parentheses, 
   3rd if all before were /\ because then rx'=rx can be omitted *)
let rec get_string_for_formula = function
  | (True, _, _) -> Some("True")
  | (False, _, _) -> Some("False")
  | (Eq ((VarPrime v: expr), (Var v': expr)), _, true) when v = v' -> None 
  | (Eq ((Var v: expr), (VarPrime v': expr)), _, true) when v = v' -> None
  | (Eq (e1, e2), _, _) -> Some(Printf.sprintf " %s=%s " (get_string_for_expr e1) (get_string_for_expr e2))
  | (Lt (e1, e2), _, _) -> Some(Printf.sprintf " %s<%s " (get_string_for_expr e1) (get_string_for_expr e2))
  | (Gt (e1, e2), _, _) -> Some(Printf.sprintf " %s>%s " (get_string_for_expr e1) (get_string_for_expr e2))
  | (Neq (e1, e2), _, _) -> Some(Printf.sprintf " %s!=%s " (get_string_for_expr e1) (get_string_for_expr e2))
  | (Leq (e1, e2), _,_) -> Some(Printf.sprintf " %s<=%s " (get_string_for_expr e1) (get_string_for_expr e2))
  | (Geq (e1, e2), _, _) -> Some(Printf.sprintf " %s>=%s " (get_string_for_expr e1) (get_string_for_expr e2))
  | (And (f1, f2), LastAnd, v) -> remove_empty_and_parenthesize (get_string_for_formula (f1, LastAnd, v)) (get_string_for_formula (f2, LastAnd, v)) "/\\\\" "" ""
  | (And (f1, f2), _, v) -> remove_empty_and_parenthesize (get_string_for_formula (f1, LastAnd, v)) (get_string_for_formula (f2, LastAnd, v)) "/\\\\" " (" ") "
  | (Or (f1, f2), LastOr, _) -> remove_empty_and_parenthesize (get_string_for_formula (f1, LastOr, false)) (get_string_for_formula (f2, LastOr, false)) "\\\\/" "" ""
  | (Or (f1, f2), _, _) -> remove_empty_and_parenthesize (get_string_for_formula (f1, LastOr, false)) (get_string_for_formula (f2, LastOr, false)) "\\\\/" " (" ") "
  | (Not f, _, _) -> match get_string_for_formula (f, LastDiff, false) with 
                              None -> Some "EmptyNot" (* probably raise error *)
                            | Some s -> Some (Printf.sprintf "~%s" s) 

let get_string_for_option_string = function
    None -> "True"
  | Some s -> s

(* Function for adding unmentioned equalities *)


module VarSet = Set.Make(String)

let varset_of_list ls =
  List.fold_left (fun acc elem -> VarSet.add elem acc) VarSet.empty ls

let rec primed_vars_in_expr (expr : expr) = 
  match expr with 
  | Const _ -> VarSet.empty
  | Var v -> VarSet.empty 
  | VarPrime v -> VarSet.singleton v 
  | Plus(e1, e2) | Minus(e1, e2) | Times(e1, e2) | Div(e1, e2) | Mod(e1, e2) ->
      VarSet.union (primed_vars_in_expr e1) (primed_vars_in_expr e2)

let rec primed_vars_in_formula (f : formula) = 
  match f with 
  | True | False -> VarSet.empty
  | Eq(e1, e2) | Neq(e1, e2) | Lt(e1, e2) | Leq(e1, e2) | Gt(e1, e2) | Geq(e1, e2) ->
      VarSet.union (primed_vars_in_expr e1) (primed_vars_in_expr e2)
  | And(f1, f2) | Or(f1, f2) -> VarSet.union (primed_vars_in_formula f1) (primed_vars_in_formula f2)
  | Not(f) -> primed_vars_in_formula f

let add_unmentioned_equalities prot =
  let update_transition transition =
    let relevant_vars = varset_of_list prot.registers in
    let mentioned_vars = primed_vars_in_formula transition.predicate in
    let unmentioned = VarSet.diff relevant_vars mentioned_vars in
    
    if VarSet.is_empty unmentioned then transition else
      let equalities =
        VarSet.fold (fun v acc -> Eq(VarPrime v, Var v) :: acc) unmentioned [] in
      
      let rec conjoin_equalities equalities = 
        match equalities with
        | [] -> transition.predicate
        | hd :: tl -> And(conjoin_equalities tl, hd)
      in
      { transition with predicate = conjoin_equalities equalities }
  in
  { prot with transitions = List.map update_transition prot.transitions }

(* Other general typechecking passes *)

(* Checking that no free variables occur in transitions *)
let rec var_names_in_expr (expr : expr) = 
  match expr with 
  | Const _ -> VarSet.empty
  | Var v -> VarSet.singleton v
  | VarPrime v -> VarSet.singleton v 
  | Plus(e1, e2) | Minus(e1, e2) | Times(e1, e2) | Div(e1, e2) | Mod(e1, e2) ->
      VarSet.union (var_names_in_expr e1) (var_names_in_expr e2)

let rec var_names_in_formula (f : formula) = 
  match f with 
  | True | False -> VarSet.empty
  | Eq(e1, e2) | Neq(e1, e2) | Lt(e1, e2) | Leq(e1, e2) | Gt(e1, e2) | Geq(e1, e2) ->
      VarSet.union (var_names_in_expr e1) (var_names_in_expr e2)
  | And(f1, f2) | Or(f1, f2) -> VarSet.union (var_names_in_formula f1) (var_names_in_formula f2)
  | Not(f) -> var_names_in_formula f

let allowed_var_names_in_transition (prot : symbolic_protocol) (tr : symbolic_transition) = 
  VarSet.add tr.comm_var (varset_of_list prot.registers)

let var_names_in_transition (tr : symbolic_transition) = 
  VarSet.add tr.comm_var (var_names_in_formula tr.predicate)

let disallowed_var_names_in_transition (prot : symbolic_protocol) (tr : symbolic_transition) = 
  VarSet.diff (var_names_in_transition tr) (allowed_var_names_in_transition prot tr) 

let varset_to_string s : string = 
  VarSet.fold (fun elem acc -> acc ^ " " ^ elem) s "" 

let string_of_transition (tr : symbolic_transition) : string =
  sprintf "(%d) %s->%s:%s{%s} (%d)"
    tr.pre
    tr.sender  
    tr.receiver
    tr.comm_var
    (string_of_formula tr.predicate)
    tr.post

let check_no_disallowed_var_names_in_protocol (prot : symbolic_protocol) : bool = 
  List.fold_left (fun acc tr -> let disallowed_vars = disallowed_var_names_in_transition prot tr in 
                                if VarSet.is_empty disallowed_vars 
                                then acc 
                                else (Printf.eprintf "Variables%s not in scope in transition %s\n" 
                                     (varset_to_string (disallowed_var_names_in_transition prot tr)) 
                                     (string_of_transition tr); false)) 
                  true 
                  prot.transitions 


