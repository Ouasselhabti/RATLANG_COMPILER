open Tds
open Exceptions
open Ast
open Type


 type t1 = Ast.AstTds.programme
 type t2 = Ast.AstType.programme

(* analyser_type_affectable : AstTds.affectable -> AstType.affectable *)
(* Paramètre e : l'affectable à analyser *)
(* Vérifie la bonne utilisation des types et tranforme l'affectable
en un affectable de type AstType.affectable *)
(* Erreur si mauvaise utilisation des identifiants *)
let rec analyser_type_affectable a =
 match a with
 | AstTds.Ident infoast -> 
 begin
 match (info_ast_to_info infoast) with
 | InfoConst _ -> (AstType.Ident(infoast), Int)
 | InfoVar(_,t,_,_) -> (AstType.Ident(infoast), t)
 | _ -> failwith ("Internal error")
 end
 | AstTds.Valeur a1 -> 
 begin
 match (analyser_type_affectable a1) with
 | (na, Pointeur ta) -> (AstType.Valeur(na), ta)
 | _ -> raise(NotAPointer)
 end


let typeinf inf =
 match inf with
 | InfoConst(_,_) -> Type.Int
 | InfoVar(_,t,_,_) -> t
 | _ -> failwith "no retrievable type"

 let typefun inf =
 match inf with 
 | InfoFun(_,retour,params) -> retour,params
 | _ -> failwith "no function type retrievable"
 



let rec analyser_type_expression e =
 (match e with
 | Ast.AstTds.AppelFonction(inf,lp) ->
 (let nlp = List.map (analyser_type_expression) lp in 
 let lt = List.map snd nlp in 
 let lpe = List.map fst nlp in
 let ltr,ltv = (typefun (info_ast_to_info inf)) in
 if (est_compatible_list lt ltv) then
 AstType.AppelFonction(inf, lpe), ltr
 else
 raise (TypesParametresInattendus(lt,ltv)))


 | AstTds.Booleen(truth) ->AstType.Booleen(truth), Bool

 | AstTds.Entier(nb) -> AstType.Entier(nb),Int

 | AstTds.Unaire(unaire, expr) -> 
 (let ne,nt = analyser_type_expression expr in
 if nt = Rat then
 (match unaire with 
 | AstSyntax.Numerateur -> AstType.Unaire(AstType.Numerateur, ne),Int 
 | AstSyntax.Denominateur -> AstType.Unaire(AstType.Denominateur, ne),Int)
 else
 raise (TypeInattendu(nt,Rat)))

 | AstTds.Binaire(bin,expr1,expr2) -> 
 (let ne1,nt1 = analyser_type_expression expr1 in 
 let ne2,nt2 = analyser_type_expression expr2 in
 if not (est_compatible nt1 nt2) then
 raise (TypeBinaireInattendu(bin,nt1,nt2))
 else
 (match nt1 with

 | Bool -> 
 (match bin with 
 | AstSyntax.Equ -> AstType.Binaire(AstType.EquBool,ne1,ne2),Bool
 | _ -> raise (TypeBinaireInattendu(bin,nt1,nt2)))

 | Int -> 
 (match bin with
 | AstSyntax.Equ -> AstType.Binaire(AstType.EquInt, ne1,ne2),Bool
 | AstSyntax.Plus -> AstType.Binaire(AstType.PlusInt, ne1, ne2), Int
 | AstSyntax.Mult -> AstType.Binaire(AstType.MultInt, ne1,ne2), Int
 | AstSyntax.Inf -> AstType.Binaire(AstType.Inf, ne1,ne2), Bool
 | AstSyntax.Fraction -> AstType.Binaire(AstType.Fraction, ne1, ne2), Rat
 | _ -> raise (TypeBinaireInattendu(bin,nt1,nt2)))

 | Rat ->
 (match bin with
 | AstSyntax.Plus -> AstType.Binaire(AstType.PlusRat, ne1, ne2), Rat
 | AstSyntax.Mult -> AstType.Binaire(AstType.MultRat, ne1,ne2), Rat
 | _ -> raise (TypeBinaireInattendu(bin,nt1,nt2)))

 | _ -> raise (TypeBinaireInattendu(bin,nt1,nt2))))


 | AstTds.Affectable a ->
 let (na,ta) = analyser_type_affectable a in
 (AstType.Affectable(na),ta)

 | AstTds.Null -> (Null, Pointeur Undefined)
 | AstTds.New t -> (New(t),Pointeur t)
 | AstTds.Adresse infoast -> 
 begin
 match (info_ast_to_info infoast) with
 | InfoVar(_,t,_,_) -> (Adresse(infoast), Pointeur t)
 | _ -> failwith ("Internal error")
 end

 | AstTds.Tenaire(c,e1,e2) ->
 let nc,tp = analyser_type_expression c in
 if (est_compatible Bool tp) then
 let ne1,nt1 = analyser_type_expression e1 in 
 let ne2,nt2 = analyser_type_expression e2 in
 if not (est_compatible nt1 nt2) then
 raise (TypeInattendu(nt1,nt2))
 else
 AstType.Tenaire(nc,ne1,ne2), nt1
 else 
 raise (TypeInattendu(tp,Bool))
 
 )
 
and analyser_type_instruction i =


 match i with 

 
 | AstTds.Declaration(tp,inf,expr) -> 
 ((Tds.modifier_type_variable tp inf);
 let ne,nt = analyser_type_expression expr in
 if (est_compatible tp nt) then
 AstType.Declaration(inf,ne)
 else
 raise (Exceptions.TypeInattendu(nt,tp)))


 | AstTds.Affectation (a,e) ->
 let (na,ta) = analyser_type_affectable a in
 let (ne,te) = analyser_type_expression e in
 if est_compatible ta te then
 Affectation (na,ne)
 else raise(TypeInattendu (te, ta))


 | AstTds.Affichage expr -> 
 (let e,t = analyser_type_expression expr in
 match t with 
 | Type.Int -> AstType.AffichageInt e
 | Type.Bool -> AstType.AffichageBool e
 | Type.Rat -> AstType.AffichageRat e
 | Type.Pointeur tt -> raise (TypeInattendu(t,tt))
 | Type.Undefined -> failwith "undefined type")


 | AstTds.Conditionnelle(cond,bt,be) -> 
 (let nc,tp = analyser_type_expression cond in
 if (est_compatible Bool tp) then
 AstType.Conditionnelle(nc, analyser_type_bloc bt, analyser_type_bloc be)
 else
 raise (TypeInattendu(tp, Bool)))

 
 | AstTds.TantQue(expr,bloc) ->
 (let nexpr,nt = analyser_type_expression expr in
 (if (est_compatible Bool nt) then 
 AstType.TantQue(nexpr,(analyser_type_bloc bloc))
 else
 raise (TypeInattendu(nt, Bool))))

 
 | AstTds.Retour(expr,inf) -> 
 (let ne,nt = analyser_type_expression expr in 
 (if (est_compatible nt (fst (typefun (info_ast_to_info inf)))) then 
 AstType.Retour(ne,inf)
 else
 raise (TypeInattendu(nt,(fst (typefun (info_ast_to_info inf)))))))


 | AstTds.Empty -> AstType.Empty
 | AstTds.ConditionnelleSimple(c,b) ->
 (let nc,tp = analyser_type_expression c in
 if (est_compatible Bool tp) then
 AstType.ConditionnelleSimple(nc, analyser_type_bloc b)
 else
 raise (TypeInattendu(tp, Bool)))

 | AstTds.Loop(b) -> AstType.Loop( analyser_type_bloc b)
 | AstTds.Break -> AstType.Break
 | AstTds.Continue -> AstType.Continue
 | AstTds.LabeledLoop (inf,b) -> AstType.LabeledLoop(inf,analyser_type_bloc b)
 | AstTds.LabeledBreak (inf) -> AstType.LabeledBreak(inf)
 | AstTds.LabeledContinue (inf) -> AstType.LabeledContinue(inf)
 



and analyser_type_bloc blc = List.map analyser_type_instruction blc



 and getnameinfo inf = 
 match inf with 
 | InfoConst(n,_) -> n
 | InfoFun(n,_,_) -> n
 | InfoVar(n,_,_,_) -> n
 | InfoLoop(n) -> n

and analyser_type_fonction (AstTds.Fonction(tp,infst,nfli,blc)) =
let nvblc = analyser_type_bloc blc in
let nom = getnameinfo (info_ast_to_info infst) in 
AstType.Fonction(info_to_info_ast (InfoFun(nom,tp,(List.map (fst) nfli))), (List.map (snd) nfli), nvblc)
;;


let analyser (AstTds.Programme (fonctions,prog)) =
  let nf = List.map (analyser_type_fonction) fonctions in
  let nb = analyser_type_bloc prog in
  AstType.Programme (nf,nb)