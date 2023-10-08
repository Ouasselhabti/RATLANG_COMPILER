open Ast
open Type

(* Interface d'affichage des arbres abstraits *)
module type PrinterAst =
sig
  module A:Ast

(* string_of_expression :  expression -> string *)
(* transforme une expression en chaîne de caractère *)
val string_of_expression : A.expression -> string

(* string_of_instruction :  instruction -> string *)
(* transforme une instruction en chaîne de caractère *)
val string_of_instruction : A.instruction -> string

(* string_of_fonction :  fonction -> string *)
(* transforme une fonction en chaîne de caractère *)
val string_of_fonction : A.fonction -> string

(* string_of_ast :  ast -> string *)
(* transforme un ast en chaîne de caractère *)
val string_of_programme : A.programme -> string

(* print_ast :  ast -> unit *)
(* affiche un ast *)
val print_programme : A.programme -> unit

end

(*Module d'affiche des AST issus de la phase d'analyse syntaxique *)
module PrinterAstSyntax : PrinterAst with module A = AstSyntax =
struct

  module A = AstSyntax
  open A

  (* Conversion des opérateurs unaires *)
  let string_of_unaire op =
    match op with
    | Numerateur -> "num "
    | Denominateur -> "denom "
    
  (* Conversion des opérateurs binaires *)
  let string_of_binaire b =
    match b with
    | Fraction -> "/ " (* not used *)
    | Plus -> "+ "
    | Mult -> "* "
    | Equ -> "= "
    | Inf -> "< "


  (*Conversion des affectables*)
  let rec string_of_affectable a = 
    match a with 
      | Valeur a2 -> "(* "^(string_of_affectable a2)^")"
      | Ident n -> n 
  (* Conversion des expressions *)
  let rec string_of_expression e =
    match e with
    | AppelFonction (n,le) -> "call "^n^"("^((List.fold_right (fun i tq -> (string_of_expression i)^tq) le ""))^") "^"\n"
    | Booleen b -> if b then "true " else "false "^"\n"
    | Entier i -> (string_of_int i)^" "^"\n"
    | Unaire (op,e1) -> (string_of_unaire op) ^ (string_of_expression e1)^" "^"\n"
    | Binaire (b,e1,e2) ->
        begin
          match b with
          | Fraction -> "["^(string_of_expression e1)^"/"^(string_of_expression e2)^"] "^"\n"
          | _ -> (string_of_expression e1)^(string_of_binaire b)^(string_of_expression e2)^" "^"\n"
        end
    | Affectable a -> (string_of_affectable a)^"\n"
    | New x -> "(new "^(string_of_type x)^")"^"\n"
    | Adresse n -> "& "^n^"\n"
    | Null -> "null"^"\n"
    | Tenaire(e1,e2,e3) -> "( "^( string_of_expression e1)^" ? "^(string_of_expression e2)^" : "^(string_of_expression e3)^" )"^"\n"



  (* Conversion des instructions *)
  let rec string_of_instruction i =
    match i with
    | Declaration (t, n, e) -> "Declaration  : "^(string_of_type t)^" "^n^" = "^(string_of_expression e)^"\n"
    | Affectation (n,e) ->  "Affectation  : "^(string_of_affectable n)^" = "^(string_of_expression e)^"\n"
    | Constante (n,i) ->  "Constante  : "^n^" = "^(string_of_int i)^"\n"
    | Affichage e ->  "Affichage  : "^(string_of_expression e)^"\n"
    | Conditionnelle (c,t,e) ->  "Conditionnelle  : IF "^(string_of_expression c)^"\n"^
                                  "THEN \n"^((List.fold_right (fun i tq -> (string_of_instruction i)^tq) t ""))^
                                  "ELSE \n"^((List.fold_right (fun i tq -> (string_of_instruction i)^tq) e ""))^"\n"
    | ConditionnelleSimple (c,t) -> "Conditionnelle  : IF "^(string_of_expression c)^"\n"^
                                  "THEN \n"^((List.fold_right (fun i tq -> (string_of_instruction i)^tq) t ""))^"\n"

    | TantQue (c,b) -> "TantQue  : TQ "^(string_of_expression c)^"\n"^
                                  "FAIRE \n"^((List.fold_right (fun i tq -> (string_of_instruction i)^tq) b ""))^"\n"
    | Retour (e) -> "Retour  : RETURN "^(string_of_expression e)^"\n"
    | Loop b ->"loop {"^((List.fold_right (fun i tq -> (string_of_instruction i)^tq) b ""))^" }\n"
    | LabeledLoop (s,b) -> s^" : loop {"^((List.fold_right (fun i tq -> (string_of_instruction i)^tq) b ""))^" }\n"
    | Break -> "break;\n"
    | LabeledBreak s -> "break "^s^";\n"
    | Continue -> "continue;\n"
    | LabeledContinue s -> "continue "^s^";\n"

  (* Conversion des fonctions *)
  let string_of_fonction (Fonction(t,n,lp,li)) = (string_of_type t)^" "^n^" ("^((List.fold_right (fun (t,n) tq -> (string_of_type t)^" "^n^" "^tq) lp ""))^") = \n"^
                                        ((List.fold_right (fun i tq -> (string_of_instruction i)^tq) li ""))^"\n"

  (* Conversion d'un programme Rat *)
  let string_of_programme (Programme (fonctions, instruction)) =
    (List.fold_right (fun f tq -> (string_of_fonction f)^tq) fonctions "")^
    (List.fold_right (fun i tq -> (string_of_instruction i)^tq) instruction "")

  (* Affichage d'un programme Rat *)
  let print_programme programme =
    print_string "AST : \n";
    print_string (string_of_programme programme);
    flush_all ()

end
