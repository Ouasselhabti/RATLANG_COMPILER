(* (* Module de la passe de gestion des types *)
module PassePlacementRat : Passe.Passe with type t1 = Ast.AstType.programme and type t2 = Ast.AstPlacement.programme =
struct

  open Tds
  open Exceptions
  open Ast
  open AstPlacement
  open Type

  type t1 = Ast.AstType.programme
  type t2 = Ast.AstPlacement.programme

(* Analyse le placement d'un instuction et renvoie la nouvelle instruction *)
let rec analyse_placement_instruction base reg i =
  (match i with
  | AstType.Declaration (info, _) ->    
            begin (match (info_ast_to_info info) with 
            | InfoVar(_,t,_)-> modifier_adresse_variable base reg info; (Type.getTaille t)   
            |_ -> assert false)
            end
  | AstType.Conditionnelle (c,t,e) -> 
         let  tc = analyse_placement_bloc base reg t in 
          let ec = analyse_placement_bloc base reg e in 
          Ast.Placement.Conditionnelle (c,tc,ec)
            
  | AstType.TantQue (c,b) -> 
     ( let bc = (analyse_placement_bloc base reg b) in 
      Ast.Placement.TantQue(c,bc))
  | AstType.Loop(b) -> 
    (let bc = analyse_placement_bloc base reg b in 
    Ast.Placement.Loop(bc))

  |AstType.LabeledLoop(c,b) ->
    (let bc = analyse_placement_bloc base reg b in 
    Ast.Placement.LabeledLoop(c,bc))

  |AstType.ConditionnelleSimple(c,b) ->
      (let bc = analyse_placement_bloc base reg b in 
    Ast.Placement.ConditionnelleSimple(c,bc))

  | AstType.Empty -> AstPlacement.Empty 
  |  AstType.Break -> AstPlacement.Break
  |  AstType.LabeledBreak(s) -> AstPlacement.LabeledBreak(s)
  |  AstType.Continue -> AstPlacement.Continue
  |  AstType.LabeledContinue(s) -> AstPlacement.LabeledContinue(s)
  |  AstType.AffichageInt(n) -> AstPlacement.AffichageInt(n)
  | AstType.AffichageRat (r)-> AstPlacement.AffichageRat(r)
  | AstType.AffichageBool -> AstPlacement.AffichageBool)

(* Analyse le placement d'un bloc et renvoie le nouveau bloc *)
and analyse_placement_bloc add reg blc =
match blc with 
| [] -> [],0
| i::q ->
  (let nins = analyse_dep_instruction add reg i in 
  let lstinstr,taille = (analyser_dep_bloc (add + gettaille(nins)) reg q) in 
  (nins::lstinstr),(taille+gettaille(nins)))



(* Analyse le placement d'une fonction et renvoie la nouvelle fonction *)
let analyse_placement_fonction (AstType.Fonction(n,lp,li,e)) = 
  let calcul param d =
    match info_ast_to_info param with
    | InfoVar(_,t,_,_) ->  
        let nd = d-getTaille t in 
        modifier_adresse_variable nd "LB" param;
        nd
    | _ -> failwith ""
  in
  let _ = List.fold_right calcul lp 0 in
  let _ = analyse_placement_bloc li 3 "LB" in
  Fonction(n, lp, li, e)

  


(* Analyse le placement d'un programme et renvoie le nouveau programme *)

let rec analyser p = 
  (match p with 
  |AstType.Programme (defTypes,fonction,p1) ->  let nf = analyse_placement_fonction fonction in 
  let np = analyser p1 in
  Programme (defTypes,nf,np)
  | Ast.AstType.Bloc b -> 
      analyse_placement_bloc 0 "SB" b;
      Ast.AstPlacement.Bloc(b))
end
*)