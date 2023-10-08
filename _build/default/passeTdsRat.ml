(* Module de la passe de gestion des identifiants *)
(* doit être conforme à l'interface Passe *)
open Tds
open Exceptions
open Ast

type t1 = Ast.AstSyntax.programme
type t2 = Ast.AstTds.programme
(*******************)

let rec analyse_tds_affectable tds a modif =
  match a with
  | AstSyntax.Valeur a2 -> AstTds.Valeur(analyse_tds_affectable tds a2 modif)
  | AstSyntax.Ident n -> 
  begin 
    match (chercherGlobalement tds n) with
    | Some infoast ->
    begin
      match (info_ast_to_info infoast) with
      | InfoVar (_,_,_,_) -> Ident infoast
      | InfoConst(_,_) -> if modif then raise(MauvaiseUtilisationIdentifiant n) else Ident infoast
      |   _ -> raise(MauvaiseUtilisationIdentifiant n)
    end
    | None -> raise (IdentifiantNonDeclare n)
  end
  
(* analyse_tds_expression : tds -> AstSyntax.expression -> AstTds.expression *)
(* Paramètre tds : la table des symboles courante *)
(* Paramètre e : l'expression à analyser *)
(* Vérifie la bonne utilisation des identifiants et tranforme l'expression
en une expression de type AstTds.expression *)
(* Erreur si mauvaise utilisation des identifiants *)
let rec analyse_tds_expression tds e = 
  match e with
  |AstSyntax.AppelFonction (f,lp) -> 
    begin
      match chercherGlobalement tds f with
      | None -> (*fonction non définie*)
        raise (IdentifiantNonDeclare f)
      | Some info -> 
        begin
          match info_ast_to_info info with
          | InfoFun _ ->
            (* Vérification de la bonne utilisation des identifiants dans l'expression *)
            (* et obtention de l'expression transformée *)
            let liste_np = List.map (fun e -> analyse_tds_expression tds e) lp in
            (* Renvoie de la nouvelle affectation où le nom a été remplacé par l'information
               et l'expression remplacée par l'expression issue de l'analyse *)
            AstTds.AppelFonction(info, liste_np)
          |  _ ->
            (* Modification d'une constante ou d'une fonction *)
            raise (MauvaiseUtilisationIdentifiant f)
        end
    end
  | AstSyntax.Booleen b -> AstTds.Booleen b
  | AstSyntax.Entier i -> AstTds.Entier i
  | AstSyntax.Unaire (u,e) -> AstTds.Unaire (u,(analyse_tds_expression tds e))
  | AstSyntax.Binaire (b,e1,e2) -> AstTds.Binaire(b,(analyse_tds_expression tds e1),(analyse_tds_expression tds e2))
  | AstSyntax.Affectable a -> AstTds.Affectable (analyse_tds_affectable tds a false)
  | AstSyntax.New t -> AstTds.New (t)
  | AstSyntax.Tenaire (e1,e2,e3) -> AstTds.Tenaire ( (analyse_tds_expression tds e1) , (analyse_tds_expression tds e2) , (analyse_tds_expression tds e3) )
  | AstSyntax.Adresse s -> begin 
                              match (chercherGlobalement tds s) with
                                | Some info -> (AstTds.Adresse info)
                                | _ -> raise (IdentifiantNonDeclare s)
                           end
  | AstSyntax.Null -> AstTds.Null



(* analyse_tds_instruction : tds -> info_ast option -> AstSyntax.instruction -> AstTds.instruction *)
(* Paramètre tds : la table des symboles courante *)
(* Paramètre oia : None si l'instruction i est dans le bloc principal,
                   Some ia où ia est l'information associée à la fonction dans laquelle est l'instruction i sinon *)
(* Paramètre i : l'instruction à analyser *)
(* Vérifie la bonne utilisation des identifiants et tranforme l'instruction
en une instruction de type AstTds.instruction *)
(* Erreur si mauvaise utilisation des identifiants *)
let rec analyse_tds_instruction tds oia i =
  match i with
  | AstSyntax.Declaration (t, n, e) ->
      begin
        match chercherLocalement tds n with
        | None ->
            (* L'identifiant n'est pas trouvé dans la tds locale,
            il n'a donc pas été déclaré dans le bloc courant *)
            (* Vérification de la bonne utilisation des identifiants dans l'expression *)
            (* et obtention de l'expression transformée *)
            let ne = analyse_tds_expression tds e in
            (* Création de l'information associée à l'identfiant *)
            let info = InfoVar (n,Undefined, 0, "") in
            (* Création du pointeur sur l'information *)
            let ia = info_to_info_ast info in
            (* Ajout de l'information (pointeur) dans la tds *)
            ajouter tds n ia;
            (* Renvoie de la nouvelle déclaration où le nom a été remplacé par l'information
            et l'expression remplacée par l'expression issue de l'analyse *)
            AstTds.Declaration (t, ia, ne)
        | Some _ ->
            (* L'identifiant est trouvé dans la tds locale,
            il a donc déjà été déclaré dans le bloc courant *)
            raise (DoubleDeclaration n)
      end
  | AstSyntax.Affectation (n,e) ->
      let na = analyse_tds_affectable tds n true in
      let ne = analyse_tds_expression tds e in
      Affectation (na,ne)
  | AstSyntax.Constante (n,v) ->
      begin
        match chercherLocalement tds n with
        | None ->
          (* L'identifiant n'est pas trouvé dans la tds locale,
             il n'a donc pas été déclaré dans le bloc courant *)
          (* Ajout dans la tds de la constante *)
          ajouter tds n (info_to_info_ast (InfoConst (n,v)));
          (* Suppression du noeud de déclaration des constantes devenu inutile *)
          AstTds.Empty
        | Some _ ->
          (* L'identifiant est trouvé dans la tds locale,
          il a donc déjà été déclaré dans le bloc courant *)
          raise (DoubleDeclaration n)
      end
  | AstSyntax.Affichage e ->
      (* Vérification de la bonne utilisation des identifiants dans l'expression *)
      (* et obtention de l'expression transformée *)
      let ne = analyse_tds_expression tds e in
      (* Renvoie du nouvel affichage où l'expression remplacée par l'expression issue de l'analyse *)
      AstTds.Affichage (ne)
  | AstSyntax.Conditionnelle (c,t,e) ->
      (* Analyse de la condition *)
      let nc = analyse_tds_expression tds c in
      (* Analyse du bloc then *)
      let tast = analyse_tds_bloc tds oia t in
      (* Analyse du bloc else *)
      let east = analyse_tds_bloc tds oia e in
      (* Renvoie la nouvelle structure de la conditionnelle *)
      AstTds.Conditionnelle (nc, tast, east)
  | AstSyntax.ConditionnelleSimple (c , b) -> 
    (* Analyse de la condition *)
      let nc = analyse_tds_expression tds c in
      (* Analyse du bloc then *)
      let tast = analyse_tds_bloc tds oia b in
      AstTds.ConditionnelleSimple (nc, tast)
  | AstSyntax.TantQue (c,b) ->
      (* Analyse de la condition *)
      let nc = analyse_tds_expression tds c in
      (* Analyse du bloc *)
      let bast = analyse_tds_bloc tds oia b in
      (* Renvoie la nouvelle structure de la boucle *)
      AstTds.TantQue (nc, bast)
  | AstSyntax.Retour (e) ->
      begin
      (* On récupère l'information associée à la fonction à laquelle le return est associée *)
      match oia with
        (* Il n'y a pas d'information -> l'instruction est dans le bloc principal : erreur *)
      | None -> raise RetourDansMain
        (* Il y a une information -> l'instruction est dans une fonction *)
      | Some ia ->
        (* Analyse de l'expression *)
        let ne = analyse_tds_expression tds e in
        AstTds.Retour (ne,ia)
      end
  | AstSyntax.Break -> AstTds.Break
  | AstSyntax.LabeledBreak s -> begin 
                                  match chercherGlobalement tds s with 
                                    | None -> raise (IdentifiantNonDeclare s)  
                                    | Some info -> AstTds.LabeledBreak info 
                                  end
  | AstSyntax.Loop b -> AstTds.Loop (analyse_tds_bloc tds oia b)
  | AstSyntax.LabeledLoop (s,b) -> begin 
    match chercherGlobalement tds s with 
      | None -> let tds_loop = creerTDSFille tds in
                  let info_loop = info_to_info_ast (InfoLoop(s)) in 
                      ajouter tds_loop s info_loop;
                      AstTds.LabeledLoop (info_loop , (analyse_tds_bloc tds_loop oia b))
                    
      | Some _ -> begin 
                      match chercherLocalement tds s with
                        |None -> raise MasquageNonAutorise
                        |Some _ -> let tds_loop = creerTDSFille tds in
                                      let info_loop = info_to_info_ast (InfoLoop(s)) in 
                                        ajouter tds_loop s info_loop;
                                        AstTds.LabeledLoop (info_loop , (analyse_tds_bloc tds_loop oia b))
      end
    end
  | AstSyntax.Continue -> AstTds.Continue
  | AstSyntax.LabeledContinue s -> begin 
    match chercherGlobalement tds s with 
      | None -> raise (IdentifiantNonDeclare s)
      | Some info -> AstTds.LabeledContinue info 
    end

(* analyse_tds_bloc : tds -> info_ast option -> AstSyntax.bloc -> AstTds.bloc *)
(* Paramètre tds : la table des symboles courante *)
(* Paramètre oia : None si le bloc li est dans le programme principal,
                   Some ia où ia est l'information associée à la fonction dans laquelle est le bloc li sinon *)
(* Paramètre li : liste d'instructions à analyser *)
(* Vérifie la bonne utilisation des identifiants et tranforme le bloc en un bloc de type AstTds.bloc *)
(* Erreur si mauvaise utilisation des identifiants *)
and analyse_tds_bloc tds oia li =
  (* Entrée dans un nouveau bloc, donc création d'une nouvelle tds locale
  pointant sur la table du bloc parent *)
  let tdsbloc = creerTDSFille tds in
  (* Analyse des instructions du bloc avec la tds du nouveau bloc.
     Cette tds est modifiée par effet de bord *)
   let nli = List.map (analyse_tds_instruction tdsbloc oia) li in
   (* afficher_locale tdsbloc ; *) (* décommenter pour afficher la table locale *)
   nli


(* analyse_tds_fonction : tds -> AstSyntax.fonction -> AstTds.fonction *)
(* Paramètre tds : la table des symboles courante *)
(* Paramètre : la fonction à analyser *)
(* Vérifie la bonne utilisation des identifiants et tranforme la fonction
en une fonction de type AstTds.fonction *)
(* Erreur si mauvaise utilisation des identifiants *)
let analyse_tds_fonction maintds (AstSyntax.Fonction(t,n,lp,li))  =
  match chercherGlobalement maintds n with
  |None -> 
    let infoParam t id = 
     let inf = InfoVar(id,t,0,"") in
     info_to_info_ast inf

    in 
    let lnp = List.map (fun (tp,ep) -> (tp, infoParam tp ep)) lp in
            (* Création de l'information associée à l'identfiant *)
            let list_typ_param = List.map fst lp in
            let info = InfoFun (n,t,list_typ_param ) in
            (* Création du pointeur sur l'information *)
            let ia = info_to_info_ast info in
            (* Ajout de l'information (pointeur) dans la tds *)
            ajouter maintds n ia;
            let tdsf = creerTDSFille maintds in 
            let rec infosf liste_ident liste_info = 
               match (liste_ident,liste_info) with
               |[], _ -> []
               |_, [] -> []
               |(_,id)::q1, (_,i)::q2 -> (id,i)::(infosf q1 q2) 
            and ajouter_si_nouveau tds nom i =  
               match chercherLocalement tds nom with
                |None -> ajouter tds nom i
                |Some _ -> raise (DoubleDeclaration nom) (*cas de double declaration de paramétres*)
            in
            List.iter (fun (id,i) -> ajouter_si_nouveau tdsf id i) (infosf lp lnp);
            (*cas de fonction récursive*)
            ajouter tdsf n ia;
            (* Renvoie de la nouvelle déclaration où le nom a été remplacé par l'information
            et l'expression remplacée par l'expression issue de l'analyse *)
            AstTds.Fonction (t, ia, lnp ,analyse_tds_bloc tdsf (Some ia) li)
  | Some _ ->
   (* L'identifiant est trouvé dans la tds locale,
     il a donc déjà été déclaré dans le bloc courant *)
      raise (DoubleDeclaration n)

(* analyser : AstSyntax.programme -> AstTds.programme *)
(* Paramètre : le programme à analyser *)
(* Vérifie la bonne utilisation des identifiants et tranforme le programme
en un programme de type AstTds.programme *)
(* Erreur si mauvaise utilisation des identifiants *)
let analyser (AstSyntax.Programme (fonctions,prog)) =
  let tds = creerTDSMere () in
  let nf = List.map (analyse_tds_fonction tds) fonctions in
  let nb = analyse_tds_bloc tds None prog in
  AstTds.Programme (nf,nb)