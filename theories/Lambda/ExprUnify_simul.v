Require Import Coq.Lists.List.
Require Import ExtLib.Core.RelDec.
Require Import ExtLib.Data.ListNth.
Require Import ExtLib.Data.HList.
Require Import ExtLib.Data.Fun.
Require Import ExtLib.Data.Eq.
Require Import ExtLib.Data.Pair.
Require Import ExtLib.Tactics.
Require Import MirrorCore.EnvI.
Require Import MirrorCore.ExprI.
Require Import MirrorCore.SymI.
Require Import MirrorCore.SubstI3.
Require Import MirrorCore.TypesI.
Require Import MirrorCore.Lambda.ExprCore.
Require Import MirrorCore.Lambda.ExprD.
Require Import MirrorCore.Lambda.ExprLift.
Require Import MirrorCore.Lambda.ExprTac.

Require Import FunctionalExtensionality.

Set Implicit Arguments.
Set Strict Implicit.

Section typed.
  Variable subst : Type.
  Variable typ : Type.
  Variable func : Type.
  Variable RType_typ : RType typ.
  Variable RTypeOk : RTypeOk.
  Variable Typ2_arr : Typ2 _ Fun.
  Variable Typ2Ok_arr : Typ2Ok Typ2_arr.
  Variable RSym_func : RSym func.
  Variable RSymOk_func : RSymOk RSym_func.
  Variable Subst_subst : Subst subst (expr typ func).
  Variable SubstUpdate_subst : SubstUpdate subst (expr typ func).
  Variable SubstOk_subst : SubstOk (Expr_expr) Subst_subst.
  Variable SubstUpdateOk_subst
  : @SubstUpdateOk _ _ _ _ Expr_expr _ SubstUpdate_subst _.
  Local Instance Expr_expr : Expr _ (expr typ func) := Expr_expr.

  Local Instance RelDec_Rty ts : RelDec (Rty ts) :=
  { rel_dec := fun a b => match type_cast ts a b with
                            | Some _ => true
                            | None => false
                          end }.
  Variable EqDec_typ : EqDec typ (@eq typ).

  Section nested.
    Variable ts : list Type.

    (** n is the number of binders that we have gone under **)
    Variable exprUnify : forall (tus tvs : tenv typ) (under : nat) (s : subst)
                                (l r : expr typ func), typ -> option subst.


    Fixpoint exprUnify' (us vs : tenv typ) (n : nat) (s : subst)
             (e1 e2 : expr typ func) (t : typ) {struct e1}
    : option subst :=
      match e1 , e2 with
        | UVar u1 , UVar u2 =>
          if EqNat.beq_nat u1 u2 then Some s
          else
            match lookup u1 s , lookup u2 s with
              | None , None =>
                match set u1 (UVar u2) s with
                  | None =>
                    set u2 (UVar u1) s
                  | Some s => Some s
                end
              | Some e1' , None =>
                set u2 e1' s
              | None , Some e2' =>
                set u1 e2' s
              | Some e1' , Some e2' =>
                exprUnify us vs n s (lift 0 n e1') (lift 0 n e2') t
            end
        | UVar u1 , _ =>
          match lookup u1 s with
            | None =>
              match lower 0 n e2 with
                | None => None
                | Some e2 => set u1 e2 s
              end
            | Some e1' => exprUnify us vs n s (lift 0 n e1') e2 t
          end
        | _ , UVar u2 =>
          match lookup u2 s with
            | None =>
              match lower 0 n e1 with
                | None => None
                | Some e1 => set u2 e1 s
              end
            | Some e2' => exprUnify us vs n s e1 (lift 0 n e2') t
          end
        | Var v1 , Var v2 =>
          if EqNat.beq_nat v1 v2 then Some s else None
        | Inj f1 , Inj f2 =>
          match sym_eqb f1 f2 with
            | Some true => Some s
            | _ => None
          end
        | App e1 e1' , App e2 e2' =>
          match exprUnify_simul' us vs n s e1 e2 with
            | Some (tarr,s') =>
              typ2_match (fun _ => option _) ts tarr
                         (fun d _ => exprUnify' us vs n s' e1' e2' d)
                         None
            | None => None
          end
        | Abs t1 e1 , Abs t2 e2 =>
          (* t1 = t2 since both terms have the same type *)
          typ2_match (F := Fun) (fun _ => _) ts t
                     (fun _ t =>
                        exprUnify' us (t1 :: vs) (S n) s e1 e2 t)
                     None
        | _ , _ => None
      end
    with exprUnify_simul' (tus tvs : tenv typ) (n : nat) (s : subst)
                          (e1 e2 : expr typ func) {struct e1}
    : option (typ * subst) :=
      match e1 , e2 return option (typ * subst) with
        | UVar u1 , UVar u2 =>
          if EqNat.beq_nat u1 u2 then
            match nth_error tus u1 with
              | None => None
              | Some t => Some (t,s)
            end
          else
            match typeof_expr ts tus tvs (UVar u1)
                , typeof_expr ts tus tvs (UVar u2)
            with
              | Some t1 , Some t2 =>
                if t1 ?[ Rty ts ] t2 then
                  match
                    match lookup u1 s , lookup u2 s with
                      | None , None =>
                        match set u1 (UVar u2) s with
                          | None =>
                            set u2 (UVar u1) s
                          | Some s => Some s
                        end
                      | Some e1' , None =>
                        set u2 e1' s
                      | None , Some e2' =>
                        set u1 e2' s
                      | Some e1' , Some e2' =>
                        exprUnify tus tvs n s (lift 0 n e1') (lift 0 n e2') t1
                    end
                  with
                    | Some s => Some (t1,s)
                    | None => None
                  end
                else
                  None
              | _ , _ => None
            end
        | UVar u1 , _ =>
          match lookup u1 s with
            | None =>
              match lower 0 n e2 with
                | None => None
                | Some e2' =>
                  match typeof_expr ts tus tvs (UVar u1)
                      , typeof_expr ts tus tvs e2
                  with
                    | Some t1 , Some t2 =>
                      if t1 ?[ Rty ts ] t2 then
                        match set u1 e2' s with
                          | Some s => Some (t1, s)
                          | None => None
                        end
                      else
                        None
                    | _ , _ => None
                  end
              end
            | Some e1' =>
              match typeof_expr ts tus tvs (UVar u1)
                  , typeof_expr ts tus tvs e2
              with
                | Some t1 , Some t2 =>
                  if t1 ?[ Rty ts ] t2 then
                    match exprUnify tus tvs n s (lift 0 n e1') e2 t1 with
                      | Some s => Some (t1, s)
                      | None => None
                    end
                  else
                    None
                | _ , _ => None
              end
          end
        | _ , UVar u2 =>
          match lookup u2 s with
            | None =>
              match lower 0 n e1 with
                | None => None
                | Some e1' =>
                  match typeof_expr ts tus tvs e1
                      , typeof_expr ts tus tvs (UVar u2)
                  with
                    | Some t1 , Some t2 =>
                      if t1 ?[ Rty ts ] t2 then
                        match set u2 e1' s with
                          | Some s => Some (t1, s)
                          | None => None
                        end
                      else None
                    | _ , _ => None
                  end
              end
            | Some e2' =>
              match typeof_expr ts tus tvs e1
                  , typeof_expr ts tus tvs (UVar u2)
              with
                | Some t1 , Some t2 =>
                  if t1 ?[ Rty ts ] t2 then
                    match exprUnify tus tvs n s e1 (lift 0 n e2') t1 with
                      | Some s => Some (t1, s)
                      | _ => None
                    end
                  else
                    None
                | _ , _ => None
              end
          end
        | Var v1 , Var v2 =>
          if EqNat.beq_nat v1 v2 then
            match typeof_expr ts tus tvs (Var v1)
                , typeof_expr ts tus tvs (Var v2)
            with
              | Some t1 , Some t2 =>
                if t1 ?[ Rty ts ] t2 then Some (t1,s) else None
              | _ , _ => None
            end
          else
            None
        | Inj f1 , Inj f2 =>
          match sym_eqb f1 f2 with
            | Some true =>
              match typeof_sym f1 with
                | Some t => Some (t,s)
                | None => None
              end
            | _ => None
          end
        | App e1 e1' , App e2 e2' =>
          match exprUnify_simul' tus tvs n s e1 e2 with
            | Some (t,s) =>
              typ2_match (fun _ => option (typ * subst)) ts t
                         (fun d r =>
                            match exprUnify' tus tvs n s e1' e2' d with
                              | Some s' => Some (r,s')
                              | None => None
                            end)
                         None
            | None => None
          end
        | Abs t1 e1 , Abs t2 e2 =>
          if t1 ?[ Rty ts ] t2 then
            match exprUnify_simul' tus (t1 :: tvs) (S n) s e1 e2 with
              | Some (t,s) => Some (typ2 t1 t, s)
              | _ => None
            end
          else
            None
        | _ , _ => None
      end%bool.

  End nested.

  Section exprUnify.

    (** Delaying the recursion is important **)
    Fixpoint exprUnify (fuel : nat)
             (ts : list Type) (us vs : tenv typ) (under : nat) (s : subst)
             (e1 e2 : expr typ func) (t : typ) : option subst :=
      match fuel with
        | 0 => None
        | S fuel =>
          exprUnify' ts (fun tus tvs => exprUnify fuel ts tus tvs)
                     us vs under s e1 e2 t
      end.
  End exprUnify.

  Existing Instance SubstUpdate_subst.
  Existing Instance SubstOk_subst.

  Definition unify_sound_ind
    (unify : forall ts (us vs : tenv typ) (under : nat) (s : subst)
                    (l r : expr typ func)
                    (t : typ), option subst) : Prop :=
    forall tu tv e1 e2 s s' t tv',
      unify (@nil Type) tu (tv' ++ tv) (length tv') s e1 e2 t = Some s' ->
      WellFormed_subst (expr := expr typ func) s ->
      WellFormed_subst (expr := expr typ func) s' /\
      forall v1 v2 sD,
        exprD' nil tu (tv' ++ tv) t e1 = Some v1 ->
        exprD' nil tu (tv' ++ tv) t e2 = Some v2 ->
        substD tu tv s = Some sD ->
        exists sD',
             substD (expr := expr typ func) tu tv s' = Some sD'
          /\ forall us vs,
               sD' us vs ->
               sD us vs /\
               forall vs',
                 v1 us (hlist_app vs' vs) = v2 us (hlist_app vs' vs).

  Definition unify_sound := unify_sound_ind.

  Definition unify_sound_mutual
    (unify : forall ts (us vs : tenv typ) (under : nat) (s : subst)
                    (l r : expr typ func)
                    (t : typ), option subst) : Prop :=
    unify_sound unify ->
    forall tu tv e1 e2 s s' t tv',
      (exprUnify' (@nil Type) (@unify nil) tu (tv' ++ tv) (length tv') s e1 e2 t = Some s' ->
      WellFormed_subst (expr := expr typ func) s ->
      WellFormed_subst (expr := expr typ func) s' /\
      forall v1 v2 sD,
        exprD' nil tu (tv' ++ tv) t e1 = Some v1 ->
        exprD' nil tu (tv' ++ tv) t e2 = Some v2 ->
        substD tu tv s = Some sD ->
        exists sD',
             substD (expr := expr typ func) tu tv s' = Some sD'
          /\ forall us vs,
               sD' us vs ->
               sD us vs /\
               forall vs',
                 v1 us (hlist_app vs' vs) = v2 us (hlist_app vs' vs)) /\
      (exprUnify_simul' (@nil Type) (unify nil) tu (tv' ++ tv) (length tv') s e1 e2 = Some (t,s') ->
      WellFormed_subst (expr := expr typ func) s ->
      WellFormed_subst (expr := expr typ func) s' /\
      forall v1 v2 sD,
        exprD' nil tu (tv' ++ tv) t e1 = Some v1 ->
        exprD' nil tu (tv' ++ tv) t e2 = Some v2 ->
        substD tu tv s = Some sD ->
        exists sD',
             substD (expr := expr typ func) tu tv s' = Some sD'
          /\ forall us vs,
               sD' us vs ->
               sD us vs /\
               forall vs',
                 v1 us (hlist_app vs' vs) = v2 us (hlist_app vs' vs)).

  Ltac forward_reason :=
    repeat match goal with
             | H : exists x, _ |- _ =>
               destruct H
             | H : _ /\ _ |- _ => destruct H
             | H' : ?X , H : ?X -> ?Y |- _ =>
               match type of X with
                 | Prop => specialize (H H')
               end
             | H : ?X -> ?Y |- _ =>
               match type of X with
                 | Prop =>
                   let H' := fresh in
                   assert (H' : X) by eauto ;
                   specialize (H H') ;
                   clear H'
               end
           end.

  Lemma lookup_lift
  : forall u s e tu tv tv' t sD v1,
      lookup u s = Some e ->
      WellFormed_subst s ->
      substD tu tv s = Some sD ->
      exprD' nil tu (tv' ++ tv) t (UVar u) = Some v1 ->
      exists v1',
        exprD' nil tu (tv' ++ tv) t (lift 0 (length tv') e) = Some v1' /\
        forall us vs vs',
          sD us vs ->
          v1 us (hlist_app vs' vs) = v1' us (hlist_app vs' vs).
  Proof.
    intros.
    eapply substD_lookup in H; eauto.
    simpl in *. forward_reason.
    generalize (@exprD'_lift typ func RType_typ Typ2_arr _ _ _ _
                             nil tu e nil tv' tv x).
    simpl. change_rewrite H.
    intros; forward.
    autorewrite with exprD_rw in H2. simpl in H2.
    forward.
    inv_all. subst. destruct r.
    eapply nth_error_get_hlist_nth_Some in H6. simpl in H6.
    forward_reason.
    assert (x2 = x) by congruence.
    subst.
    eexists; split; eauto.
    intros.
    unfold Rcast_val,Rcast,Relim; simpl.
    rewrite H2; clear H2.
    eapply H3 in H6. change_rewrite H6.
    specialize (H5 us Hnil vs' vs). simpl in H5.
    change_rewrite H5.
    match goal with
      | |- match _ with eq_refl => match _ with eq_refl => ?X end end = ?Y =>
        change Y with X ; generalize X
    end.
    clear - EqDec_typ.
    destruct x1.
    rewrite (UIP_refl x3). reflexivity.
  Qed.

  Lemma handle_set
  : forall (e0 : expr typ func) (u : uvar) (s s' : subst),
      set u e0 s = Some s' ->
      lookup u s = None ->
      WellFormed_subst s ->
      WellFormed_subst s' /\
      forall (tu : tenv typ) (tv : list typ)
             (t : typ) (tv' : list typ),
        (forall
            (v1 : _)
            (v2 : hlist (typD nil) tu ->
                    hlist (typD nil) (tv' ++ tv) -> typD nil t)
            (sD : hlist (typD nil) tu -> hlist (typD nil) tv -> Prop),
            exprD' nil tu tv t e0 = Some v1 ->
            exprD' nil tu (tv' ++ tv) t (UVar u) = Some v2 ->
            substD tu tv s = Some sD ->
            exists
              sD' : hlist (typD nil) tu -> hlist (typD nil) tv -> Prop,
              substD tu tv s' = Some sD' /\
              (forall (us : hlist (typD nil) tu)
                      (vs : hlist (typD nil) tv),
                 sD' us vs ->
                 sD us vs /\
                 (forall vs' : hlist (typD nil) tv',
                    v1 us vs = v2 us (hlist_app vs' vs)))).
  Proof.
    intros.
    eapply set_sound in H; eauto.
    forward_reason; split; eauto.
    intros.
    autorewrite with exprD_rw in *. simpl in *.
    forward; inv_all; subst.
    destruct r.
    eapply nth_error_get_hlist_nth_Some in H6.
    forward_reason.
    simpl in *.
    specialize (H2 tu tv x _ _ H5 (eq_sym x0) H3).
    forward_reason.
    eexists; split; eauto.
    intros. specialize (H6 _ _ H8).
    forward_reason.
    split; auto. intros.
    unfold Rcast_val, Rcast, Relim. simpl.
    rewrite H4.
    match goal with
      | H : ?X = _ |- context [ ?Y ] =>
        change Y with X ; rewrite H
    end.
    rewrite match_eq_sym_eq. reflexivity.
  Qed.

  Lemma handle_set_lower
  : forall (e0 : expr typ func)
           (u : uvar) (s s' : subst),
      set u e0 s = Some s' ->
      forall (NoUVar : lookup u s = None),
      WellFormed_subst s ->
      WellFormed_subst s' /\
      forall (tu : tenv typ) (tv : list typ)
             (t : typ) (tv' : list typ) (e : expr typ func),
        lower 0 (length tv') e = Some e0 ->
        (forall
            (v1
               v2 : hlist (typD nil) tu ->
                    hlist (typD nil) (tv' ++ tv) -> typD nil t)
            (sD : hlist (typD nil) tu -> hlist (typD nil) tv -> Prop),
            exprD' nil tu (tv' ++ tv) t e = Some v1 ->
            exprD' nil tu (tv' ++ tv) t (UVar u) = Some v2 ->
            substD tu tv s = Some sD ->
            exists
              sD' : hlist (typD nil) tu -> hlist (typD nil) tv -> Prop,
              substD tu tv s' = Some sD' /\
              (forall (us : hlist (typD nil) tu)
                      (vs : hlist (typD nil) tv),
                 sD' us vs ->
                 sD us vs /\
                 (forall vs' : hlist (typD nil) tv',
                    v1 us (hlist_app vs' vs) = v2 us (hlist_app vs' vs)))).
  Proof.
    intros.
    eapply set_sound in H; eauto.
    forward_reason; split; eauto.
    intros.
    autorewrite with exprD_rw in *. simpl in *.
    forward; inv_all; subst.
    eapply nth_error_get_hlist_nth_Some in H6.
    forward_reason.
    simpl in *.
    eapply exprD'_lower with (ts := nil) (tus := tu) (tvs := nil) (tvs'' := tv) in H2; eauto.
    simpl in *.
    forward_reason.
    destruct r.
    eapply H1 in H5; eauto.
    forward_reason. eexists; split; eauto.
    intros. eapply H8 in H9.
    forward_reason; split; auto.
    intros. rewrite H4.
    change_rewrite H10. instantiate (1 := eq_sym x0).
    unfold Rcast_val, Rcast, Relim. simpl.
    rewrite match_eq_sym_eq.
    exact (H6 us Hnil vs' vs).
  Qed.

  Lemma handle_uvar
  : forall
        unify : list Type -> tenv typ ->
                tenv typ ->
                nat -> subst -> expr typ func -> expr typ func -> typ -> option subst,
        unify_sound_ind unify ->
        forall (tu : tenv typ) (tv : list typ) e
               (u : uvar) (s s' : subst) (t : typ) (tv' : list typ),
          match lookup u s with
            | Some e2' =>
              unify nil tu (tv' ++ tv) (length tv') s e
                    (lift 0 (length tv') e2') t
            | None =>
              match lower 0 (length tv') e with
                | Some e1 => set u e1 s
                | None => None
              end
          end = Some s' ->
          WellFormed_subst s ->
          WellFormed_subst s' /\
          (forall
              (v1
                 v2 : hlist (typD nil) tu ->
                      hlist (typD nil) (tv' ++ tv) -> typD nil t)
              (sD : hlist (typD nil) tu -> hlist (typD nil) tv -> Prop),
              exprD' nil tu (tv' ++ tv) t e = Some v1 ->
              exprD' nil tu (tv' ++ tv) t (UVar u) = Some v2 ->
              substD tu tv s = Some sD ->
              exists
                sD' : hlist (typD nil) tu -> hlist (typD nil) tv -> Prop,
                substD tu tv s' = Some sD' /\
                (forall (us : hlist (typD nil) tu)
                        (vs : hlist (typD nil) tv),
                   sD' us vs ->
                   sD us vs /\
                   (forall vs' : hlist (typD nil) tv',
                      v1 us (hlist_app vs' vs) = v2 us (hlist_app vs' vs)))).
  Proof.
    intros.
    consider (lookup u s); intros.
    { eapply H in H2.
      forward_reason.
      split; eauto; intros.
      assert (exists v2',
                exprD' nil tu (tv' ++ tv) t (lift 0 (length tv') e0) = Some v2'
                /\ forall us vs vs',
                     sD us vs ->
                     v2 us (hlist_app vs' vs) = v2' us (hlist_app vs' vs)).
      { eapply substD_lookup in H0; eauto.
        forward_reason.
        simpl in *.
        autorewrite with exprD_rw in H5. simpl in H5.
        forward. inv_all; subst.
        eapply nth_error_get_hlist_nth_Some in H8.
        simpl in *. forward_reason.
        generalize (@exprD'_lift typ func RType_typ Typ2_arr _ _ _ _
                                 nil tu e0 nil tv' tv x).
        simpl.
        match goal with
          | H : ?X = _ |- match ?Y with _ => _ end -> _ =>
            change Y with X ; rewrite H
        end.
        intros; forward.
        assert (t = x) by congruence.
        subst.
        eexists; split; [ eassumption | ].
        intros. eapply H7 in H11.
        unfold Rcast_val, Rcast, Relim.
        destruct r. simpl.
        rewrite H5; clear H5.
        match goal with
          | H : ?X = _ |- context [ ?Y ] =>
            change Y with X ; rewrite H ; clear H
        end.
        specialize (H10 us Hnil vs' vs). simpl in H10.
        rewrite H10.
        match goal with
          | |- match _ with eq_refl => match _ with eq_refl => ?X end end = ?Y =>
            change Y with X ; generalize X
        end.
        clear - EqDec_typ.
        destruct x1.
        rewrite (UIP_refl x3). reflexivity. }
      { forward_reason.
        specialize (H3 _ _ _ H4 H7 H6).
        forward_reason.
        eexists; split; eauto.
        intros. specialize (H9 _ _ H10).
        forward_reason. split; intros; eauto.
        rewrite H11. rewrite H8; eauto. } }
    { forward.
      eapply handle_set_lower in H3; eauto.
      forward_reason.
      split; auto; intros.
      eapply H4 in H2; eauto. }
  Qed.

  Lemma handle_uvar'
  : forall
      unify : list Type -> tenv typ ->
                tenv typ ->
                nat -> subst -> expr typ func -> expr typ func -> typ -> option subst,
        unify_sound_ind unify ->
        forall (tu : tenv typ) (tv : list typ) e
               (u : uvar) (s s' : subst) (t : typ) (tv' : list typ),
          match lookup u s with
            | Some e2' =>
              unify nil tu (tv' ++ tv) (length tv') s
                    (lift 0 (length tv') e2') e t
            | None =>
              match lower 0 (length tv') e with
                | Some e1 => set u e1 s
                | None => None
              end
          end = Some s' ->
          WellFormed_subst s ->
          WellFormed_subst s' /\
          (forall
              (v1
                 v2 : hlist (typD nil) tu ->
                      hlist (typD nil) (tv' ++ tv) -> typD nil t)
              (sD : hlist (typD nil) tu -> hlist (typD nil) tv -> Prop),
              exprD' nil tu (tv' ++ tv) t (UVar u) = Some v1 ->
              exprD' nil tu (tv' ++ tv) t e = Some v2 ->
              substD tu tv s = Some sD ->
              exists
                sD' : hlist (typD nil) tu -> hlist (typD nil) tv -> Prop,
                substD tu tv s' = Some sD' /\
                (forall (us : hlist (typD nil) tu)
                        (vs : hlist (typD nil) tv),
                   sD' us vs ->
                   sD us vs /\
                   (forall vs' : hlist (typD nil) tv',
                      v1 us (hlist_app vs' vs) = v2 us (hlist_app vs' vs)))).
  Proof.
intros.
    consider (lookup u s); intros.
    { eapply H in H2.
      forward_reason.
      split; eauto; intros.
      assert (exists v2',
                exprD' nil tu (tv' ++ tv) t (lift 0 (length tv') e0) = Some v2'
                /\ forall us vs vs',
                     sD us vs ->
                     v1 us (hlist_app vs' vs) = v2' us (hlist_app vs' vs)).
      { eapply substD_lookup in H0; eauto.
        forward_reason.
        simpl in *.
        autorewrite with exprD_rw in H4. simpl in H4.
        forward. inv_all; subst.
        eapply nth_error_get_hlist_nth_Some in H8.
        simpl in *. forward_reason.
        generalize (@exprD'_lift typ func RType_typ Typ2_arr _ _ _ _
                                 nil tu e0 nil tv' tv x).
        simpl.
        match goal with
          | H : ?X = _ |- _ => change_rewrite H
        end.
        intros; forward.
        assert (t = x) by congruence.
        subst.
        eexists; split; [ eassumption | ].
        intros.
        destruct r.
        unfold Rcast_val, Rcast, Relim; simpl.
        rewrite H4; clear H4.
        eapply H7 in H11. change_rewrite H11; clear H11.
        etransitivity; [ | exact (H10 us Hnil vs' vs) ].
        simpl.
        match goal with
          | |- match _ with eq_refl => match _ with eq_refl => ?X end end = ?Y =>
            change Y with X ; generalize X
        end.
        clear - EqDec_typ.
        destruct x1.
        rewrite (UIP_refl x3). reflexivity. }
      { forward_reason.
        specialize (H3 _ _ _ H7 H5 H6).
        forward_reason.
        eexists; split; eauto.
        intros. specialize (H9 _ _ H10).
        forward_reason. split; intros; eauto.
        rewrite <- H11. rewrite H8; eauto. } }
    { forward.
      eapply handle_set_lower in H3; eauto.
      forward_reason.
      split; auto; intros.
      eapply H4 in H2. 2: eauto. 2: eauto. 2: eauto.
      forward_reason. eexists; split; eauto.
      intros. eapply H8 in H9.
      destruct H9; split; auto. }
  Qed.

  Lemma exprD_from_subst : forall tus tvs tvs' s e u t sD eD,
    WellFormed_subst s ->
    substD tus tvs s = Some sD ->
    lookup u s = Some e ->
    exprD' nil tus (tvs' ++ tvs) t (UVar u) = Some eD ->
    exists eD',
      exprD' nil tus (tvs' ++ tvs) t (lift 0 (length tvs') e) = Some eD' /\
      forall us vs vs',
        sD us vs ->
        eD us (hlist_app vs' vs) = eD' us (hlist_app vs' vs).
  Proof.
    intros.
    autorewrite with exprD_rw in H2. simpl in H2.
    forward. inv_all; subst.
    destruct r.
    eapply substD_lookup in H1; eauto.
    forward_reason.
    simpl in H1.
    eapply nth_error_get_hlist_nth_Some in H3.
    simpl in H3. forward_reason.
    assert (x = x0) by congruence. subst.
    generalize (exprD'_lift nil tus e nil tvs' tvs x0).
    simpl. change_rewrite H1.
    forward. eexists; split; eauto.
    intros. eapply H2 in H7; clear H2.
    unfold Rcast_val, Rcast, Relim. simpl.
    etransitivity. eapply H3.
    specialize (H6 us Hnil vs' vs).
    simpl in H6. etransitivity; [ | eapply H6 ].
    change_rewrite H7.
    clear - EqDec_typ.
    destruct x2.
    rewrite (UIP_refl x3). reflexivity.
  Qed.

  (** NOTE: The exact statement of exprUnify_simul' prevents Coq from
   ** reducing it with [simpl]
   **)
  Lemma exprUnify_simul'_eq
  : forall ts u tus tvs n s e1 e2,
      exprUnify_simul' ts u tus tvs n s e1 e2 =
      match e1 , e2 return option (typ * subst) with
        | UVar u1 , UVar u2 =>
          if EqNat.beq_nat u1 u2 then
            match nth_error tus u1 with
              | None => None
              | Some t => Some (t,s)
            end
          else
            match typeof_expr ts tus tvs (UVar u1)
                  , typeof_expr ts tus tvs (UVar u2)
            with
              | Some t1 , Some t2 =>
                if t1 ?[ Rty ts ] t2 then
                  match
                    match lookup u1 s , lookup u2 s with
                      | None , None =>
                        match set u1 (UVar u2) s with
                          | None =>
                            set u2 (UVar u1) s
                          | Some s => Some s
                        end
                      | Some e1' , None =>
                        set u2 e1' s
                      | None , Some e2' =>
                        set u1 e2' s
                      | Some e1' , Some e2' =>
                        u tus tvs n s (lift 0 n e1') (lift 0 n e2') t1
                    end
                  with
                    | Some s => Some (t1,s)
                    | None => None
                  end
                else
                  None
              | _ , _ => None
            end
        | UVar u1 , _ =>
          match lookup u1 s with
            | None =>
              match lower 0 n e2 with
                | None => None
                | Some e2' =>
                  match typeof_expr ts tus tvs (UVar u1)
                      , typeof_expr ts tus tvs e2
                  with
                    | Some t1 , Some t2 =>
                      if t1 ?[ Rty ts ] t2 then
                        match set u1 e2' s with
                          | Some s => Some (t1, s)
                          | None => None
                        end
                      else
                        None
                    | _ , _ => None
                  end
              end
            | Some e1' =>
              match typeof_expr ts tus tvs (UVar u1)
                  , typeof_expr ts tus tvs e2
              with
                | Some t1 , Some t2 =>
                  if t1 ?[ Rty ts ] t2 then
                    match u tus tvs n s (lift 0 n e1') e2 t1 with
                      | Some s => Some (t1, s)
                      | None => None
                    end
                  else
                    None
                | _ , _ => None
              end
          end
        | _ , UVar u2 =>
          match lookup u2 s with
            | None =>
              match lower 0 n e1 with
                | None => None
                | Some e1' =>
                  match typeof_expr ts tus tvs e1
                      , typeof_expr ts tus tvs (UVar u2)
                  with
                    | Some t1 , Some t2 =>
                      if t1 ?[ Rty ts ] t2 then
                        match set u2 e1' s with
                          | Some s => Some (t1, s)
                          | None => None
                        end
                      else None
                    | _ , _ => None
                  end
              end
            | Some e2' =>
              match typeof_expr ts tus tvs e1
                    , typeof_expr ts tus tvs (UVar u2)
              with
                | Some t1 , Some t2 =>
                  if t1 ?[ Rty ts ] t2 then
                    match u tus tvs n s e1 (lift 0 n e2') t1 with
                      | Some s => Some (t1, s)
                      | _ => None
                    end
                  else
                    None
                | _ , _ => None
              end
          end
        | Var v1 , Var v2 =>
          if EqNat.beq_nat v1 v2 then
            match typeof_expr ts tus tvs (Var v1)
                  , typeof_expr ts tus tvs (Var v2)
            with
              | Some t1 , Some t2 =>
                if t1 ?[ Rty ts ] t2 then Some (t1,s) else None
              | _ , _ => None
            end
          else
            None
        | Inj f1 , Inj f2 =>
          match sym_eqb f1 f2 with
            | Some true =>
              match typeof_sym f1 with
                | Some t => Some (t,s)
                | None => None
              end
            | _ => None
          end
        | App e1 e1' , App e2 e2' =>
          match exprUnify_simul' ts u tus tvs n s e1 e2 with
            | Some (t,s) =>
              typ2_match (fun _ => option (typ * subst)) ts t
                         (fun d r =>
                            match exprUnify' ts u tus tvs n s e1' e2' d with
                              | Some s' => Some (r,s')
                              | None => None
                            end)
                         None
            | None => None
          end
        | Abs t1 e1 , Abs t2 e2 =>
          if t1 ?[ Rty ts ] t2 then
            match exprUnify_simul' ts u tus (t1 :: tvs) (S n) s e1 e2 with
              | Some (t,s) => Some (typ2 t1 t, s)
              | _ => None
            end
          else
            None
        | _ , _ => None
      end%bool.
  Proof.
    destruct e1; try reflexivity.
  Defined.

  Lemma Open_App_equal
  : forall ts tus tvs t u f f' x x' A B,
      f A B = f' A B ->
      x A B = x' A B ->
      @Open_App typ _ _ ts tus tvs t u f x A B =
      @Open_App typ _ _ ts tus tvs t u f' x' A B.
  Proof.
    unfold Open_App.
    clear. intros.
    unfold Open_App, OpenT, ResType.OpenT.
    intros.
    repeat first [ rewrite eq_Const_eq | rewrite eq_Arr_eq ].
    repeat match goal with
             | H : ?X = _ , H' : ?Y = _ |- _ =>
               change Y with X in H' ; rewrite H in H'
           end.
    inv_all; subst.
    rewrite H. rewrite H0. reflexivity.
  Qed.

  Lemma handle_uvar_simul
  : forall u s s' t e tv tu tv' unify
           (unifyOk : unify_sound unify),
      match lookup u s with
        | Some e2' =>
          match typeof_expr nil tu (tv' ++ tv) e with
            | Some t1 =>
              match typeof_expr nil tu (tv' ++ tv) (UVar u) with
                | Some t2 =>
                  if t1 ?[ Rty nil ] t2
                  then
                    match
                      unify nil tu (tv' ++ tv) (length tv') s
                            e (lift 0 (length tv') e2') t1
                    with
                      | Some s0 => Some (t1, s0)
                      | None => None
                    end
                  else None
                | None => None
              end
            | None => None
          end
        | None =>
          match lower 0 (length tv') e with
            | Some e' =>
              match typeof_expr nil tu (tv' ++ tv) e with
                | Some t1 =>
                  match typeof_expr nil tu (tv' ++ tv) (UVar u) with
                    | Some t2 =>
                      if t1 ?[ Rty nil ] t2
                      then
                        match set u e' s with
                          | Some s0 => Some (t1, s0)
                          | None => None
                        end
                      else None
                    | None => None
                  end
                | None => None
              end
            | None => None
          end
      end = Some (t, s') ->
      WellFormed_subst s ->
      WellFormed_subst s' /\
      (forall sD : hlist (typD nil) tu -> hlist (typD nil) tv -> Prop,
         typeof_expr nil tu (tv' ++ tv) e <> None ->
         typeof_expr nil tu (tv' ++ tv) (UVar u) <> None ->
         substD tu tv s = Some sD ->
         exists v1 v2 : OpenT nil tu (tv' ++ tv) (typD nil t),
           exprD' nil tu (tv' ++ tv) t e = Some v1 /\
           exprD' nil tu (tv' ++ tv) t (UVar u) = Some v2 /\
           (exists sD' : hlist (typD nil) tu -> hlist (typD nil) tv -> Prop,
              substD tu tv s' = Some sD' /\
              (forall (us : hlist (typD nil) tu) (vs : hlist (typD nil) tv),
                 sD' us vs ->
                 sD us vs /\
                 (forall vs' : hlist (typD nil) tv',
                    v1 us (hlist_app vs' vs) = v2 us (hlist_app vs' vs))))).
  Proof.
    intros.
    do 3 match goal with
           | H : match _ with
                   | Some _ => match ?X with _ => _ end
                   | None => match _ with Some _ => match ?Y with _ => _ end | None => _ end
                 end = _
             |- _ =>
             change Y with X in H ; consider X; intros; forward
         end.
    generalize (fun e => handle_uvar unifyOk tu tv e u s).
    consider (lookup u s); intros.
    { forward. inv_all. subst.
      destruct H2.
      eapply H5 in H4; eauto; clear H5.
      forward_reason; split; auto.
      intros.
      eapply ExprFacts.typeof_expr_exprD' in H; eauto.
      eapply ExprFacts.typeof_expr_exprD' in H1; eauto.
      forward_reason.
      do 2 eexists; split; eauto. }
    { specialize (H5 e s' t1 tv').
      forward. inv_all; subst.
      forward_reason.
      split; eauto.
      intros.
      eapply ExprFacts.typeof_expr_exprD' in H1; eauto.
      eapply ExprFacts.typeof_expr_exprD' in H; eauto.
      forward_reason.
      destruct H2.
      do 2 eexists.
      split; eauto. }
  Qed.

  Lemma handle_uvar_simul'
  : forall u s s' t e tv tu tv' unify
           (unifyOk : unify_sound unify),
      match lookup u s with
        | Some e2' =>
          match typeof_expr nil tu (tv' ++ tv) (UVar u) with
            | Some t1 =>
              match typeof_expr nil tu (tv' ++ tv) e with
                | Some t2 =>
                  if t1 ?[ Rty nil ] t2
                  then
                    match
                      unify nil tu (tv' ++ tv) (length tv') s
                            (lift 0 (length tv') e2') e t1
                    with
                      | Some s0 => Some (t1, s0)
                      | None => None
                    end
                  else None
                | None => None
              end
            | None => None
          end
        | None =>
          match lower 0 (length tv') e with
            | Some e' =>
              match typeof_expr nil tu (tv' ++ tv) (UVar u) with
                | Some t1 =>
                  match typeof_expr nil tu (tv' ++ tv) e with
                    | Some t2 =>
                      if t1 ?[ Rty nil ] t2
                      then
                        match set u e' s with
                          | Some s0 => Some (t1, s0)
                          | None => None
                        end
                      else None
                    | None => None
                  end
                | None => None
              end
            | None => None
          end
      end = Some (t, s') ->
      WellFormed_subst s ->
      WellFormed_subst s' /\
      (forall sD : hlist (typD nil) tu -> hlist (typD nil) tv -> Prop,
         typeof_expr nil tu (tv' ++ tv) (UVar u) <> None ->
         typeof_expr nil tu (tv' ++ tv) e <> None ->
         substD tu tv s = Some sD ->
         exists v1 v2 : OpenT nil tu (tv' ++ tv) (typD nil t),
           exprD' nil tu (tv' ++ tv) t (UVar u) = Some v1 /\
           exprD' nil tu (tv' ++ tv) t e = Some v2 /\
           (exists sD' : hlist (typD nil) tu -> hlist (typD nil) tv -> Prop,
              substD tu tv s' = Some sD' /\
              (forall (us : hlist (typD nil) tu) (vs : hlist (typD nil) tv),
                 sD' us vs ->
                 sD us vs /\
                 (forall vs' : hlist (typD nil) tv',
                    v1 us (hlist_app vs' vs) = v2 us (hlist_app vs' vs))))).
  Proof.
    intros.
    do 3 match goal with
           | H : match _ with
                   | Some _ => match ?X with _ => _ end
                   | None => match _ with Some _ => match ?Y with _ => _ end | None => _ end
                 end = _
             |- _ =>
             change Y with X in H ; consider X; intros; forward
         end.
    generalize (fun e => handle_uvar' unifyOk tu tv e u s).
    consider (lookup u s); intros.
    { forward. inv_all. subst.
      destruct H2.
      eapply H5 in H4; eauto; clear H5.
      forward_reason; split; auto.
      intros.
      eapply ExprFacts.typeof_expr_exprD' in H; eauto.
      eapply ExprFacts.typeof_expr_exprD' in H1; eauto.
      forward_reason.
      do 2 eexists; split; eauto. }
    { specialize (H5 e s' t1 tv').
      forward. inv_all; subst.
      forward_reason.
      split; eauto.
      intros.
      eapply ExprFacts.typeof_expr_exprD' in H1; eauto.
      eapply ExprFacts.typeof_expr_exprD' in H; eauto.
      forward_reason.
      destruct H2.
      do 2 eexists.
      split; eauto. }
  Qed.

  Lemma exprUnify'_sound_mutual
  : forall (unify : forall ts (us vs : tenv typ) (under : nat) (s : subst)
                           (l r : expr typ func)
                           (t : typ), option subst)
           (unifyOk : unify_sound unify),
    forall tu tv e1 e2 s s' t tv',
      (exprUnify' (@nil Type) (@unify nil) tu (tv' ++ tv) (length tv') s e1 e2 t = Some s' ->
      WellFormed_subst (expr := expr typ func) s ->
      WellFormed_subst (expr := expr typ func) s' /\
      forall v1 v2 sD,
        exprD' nil tu (tv' ++ tv) t e1 = Some v1 ->
        exprD' nil tu (tv' ++ tv) t e2 = Some v2 ->
        substD tu tv s = Some sD ->
        exists sD',
             substD (expr := expr typ func) tu tv s' = Some sD'
          /\ forall us vs,
               sD' us vs ->
               sD us vs /\
               forall vs',
                 v1 us (hlist_app vs' vs) = v2 us (hlist_app vs' vs)) /\
      (exprUnify_simul' (@nil Type) (unify nil) tu (tv' ++ tv) (length tv') s e1 e2 = Some (t,s') ->
      WellFormed_subst (expr := expr typ func) s ->
      WellFormed_subst (expr := expr typ func) s' /\
      forall sD,
        typeof_expr nil tu (tv' ++ tv) e1 <> None ->
        typeof_expr nil tu (tv' ++ tv) e2 <> None ->
        substD tu tv s = Some sD ->
        exists v1 v2,
          exprD' nil tu (tv' ++ tv) t e1 = Some v1 /\
          exprD' nil tu (tv' ++ tv) t e2 = Some v2 /\
          exists sD',
             substD (expr := expr typ func) tu tv s' = Some sD'
          /\ forall us vs,
               sD' us vs ->
               sD us vs /\
               forall vs',
                 v1 us (hlist_app vs' vs) = v2 us (hlist_app vs' vs)).
  Proof.
    intros unify unifyOk tu tv.
    induction e1.
    { (** Var **)
      split.
      { destruct e2; try solve [ simpl; congruence | eapply handle_uvar; eauto ].
        simpl.
        forward.
        inv_all; subst.
        split; auto. intros.
        change_rewrite H in H0.
        inv_all; subst. eauto. }
      { rewrite exprUnify_simul'_eq.
        destruct e2; try solve [ simpl; congruence | eapply handle_uvar_simul with (e := Var v); eauto ].
        forward. inv_all; subst. destruct H3.
        split; auto.
        intros.
        eapply ExprFacts.typeof_expr_exprD' in H2; eauto.
        destruct H2.
        do 2 eexists; split; eauto. } }
    { (** Inj **)
      simpl. split.
      { destruct e2; intros; try solve [ congruence | eapply handle_uvar; eauto ].
        { generalize (sym_eqbOk f f0).
          forward. inv_all; subst.
          split; auto.
          intros. eexists; split; eauto.
          match goal with
            | H : ?X = _ , H' : ?Y = _ |- _ =>
              change Y with X in H' ; rewrite H in H'
          end.
          inv_all; subst. intuition. } }
      { unfold exprUnify_simul'.
        destruct e2; intros; try solve [ congruence | eapply handle_uvar_simul with (e := Inj f); eauto ].
        { generalize (sym_eqbOk f f0).
          forward; inv_all; subst.
          autorewrite with exprD_rw.
          split; auto; intros.
          remember (funcAs f0 t) as oF.
          destruct oF.
          { simpl. do 2 eexists; split; eauto. }
          { exfalso. unfold funcAs in HeqoF.
            revert HeqoF.
            match goal with
              | |- context [ @symD ?A ?B ?C ?D ?E ?F ] =>
                generalize (@symD A B C D E F)
            end.
            rewrite H2. rewrite type_cast_refl; eauto.
            compute. congruence. } } } }
    { (** App **)
      simpl; split.
      { destruct e2; try solve [ congruence | eapply handle_uvar; eauto ].
        { forward. subst.
          destruct (IHe1_1 e2_1 s s0 t0 tv'); clear IHe1_1; eauto.
          clear H. eapply H3 in H0; clear H3; eauto.
          destruct H0.
          destruct (typ2_match_case nil t0); eauto.
          { forward_reason.
            rewrite H3 in *; clear H3.
            unfold Relim in H2. red in x1. subst.
            rewrite eq_Const_eq in H2.
            destruct (IHe1_2 e2_2 s0 s' x tv'); clear IHe1_2; eauto.
            clear H4. forward_reason.
            split; auto.
            autorewrite with exprD_rw. simpl.
            intros; forward.
            eapply H0 in H7; eauto using exprD_typeof_not_None.
            forward_reason.
            forward_exprD.
            specialize (H4 _ _ _ H12 H9 H15).
            forward_reason.
            eexists; split; eauto.
            intros.
            eapply H10 in H13; clear H10.
            destruct H13. eapply H16 in H10; clear H16.
            forward_reason; split; auto.
            repeat match goal with
                     | H : ?X = _ , H' : ?Y = _ |- _ =>
                       change X with Y in H ; rewrite H in H'; inv_all; subst
                   end.
            intros. eapply Open_App_equal; eauto. }
          { rewrite H3 in H2. congruence. } } }
      { rewrite exprUnify_simul'_eq.
        destruct e2; try solve [ congruence ].
        { intros; forward; subst.
          destruct (typ2_match_case nil t0); eauto.
          { forward_reason.
            rewrite H in *.
            rewrite eq_Const_eq in *.
            red in x1. subst. simpl Relim in *.
            forward. inv_all; subst.
            edestruct IHe1_1 as [ Hz Hx ]; eapply Hx in H1; clear Hx Hz IHe1_1; eauto.
            forward_reason.
            edestruct IHe1_2 as [ Hx Hz ]; eapply Hx in H2; clear Hx Hz IHe1_2; eauto.
            forward_reason. split; auto. simpl.
            intros. forward.
            eapply H10 in H7; try congruence; clear H10.
            forward_reason.
            autorewrite with exprD_rw. simpl.
            repeat match goal with
                     | H : ?X = _ |- context [ ?Y ] =>
                       change Y with X ; rewrite H
                   end.
            forward_exprD.
            intros; subst.
            unfold type_of_apply in *.
            rewrite typ2_match_zeta in * by eauto.
            rewrite eq_Const_eq in *. forward.
            red in r. red in r0. subst. subst.
            eapply ExprFacts.typeof_expr_exprD' in H6; eauto.
            eapply ExprFacts.typeof_expr_exprD' in H8; eauto.
            forward_reason.
            repeat match goal with
                     | H : ?X = _ |- context [ ?Y ] =>
                       change Y with X ; rewrite H
                   end.
            do 2 eexists; split; [ | split ]; auto.
            specialize (H4 _ _ _ H6 H8 H12).
            forward_reason.
            eexists; split; eauto.
            intros.
            eapply H16 in H17; clear H16; destruct H17.
            eapply H13 in H16; clear H13; destruct H16.
            split; auto.
            intros.
            eapply Open_App_equal; eauto. }
          { exfalso. rewrite H in *. congruence. } }
        { intros. eapply handle_uvar_simul with (e := App e1_1 e1_2); eauto. } } }
    { (** Abs **)
      split.
      { simpl; destruct e2; intros; try solve [ congruence | eapply handle_uvar; eauto ].
        match goal with
          | H : typ2_match _ ?Ts ?t _ _ = _ |- _ =>
            arrow_case Ts t; try congruence
        end.
        { red in x1. subst.
          autorewrite with exprD_rw. simpl.
          do 2 rewrite H1.
          unfold Relim in H.
          clear H1.
          rewrite eq_Const_eq in H.
          destruct (IHe1 e2 s s' x0 (t :: tv')) as [ Hx Hy ] ; clear Hy.
          apply Hx in H; clear Hx; eauto. forward_reason.
          unfold Relim.
          split; auto. intros.
          repeat rewrite eq_option_eq in *.
          forward.
          inv_all; subst. destruct r; destruct r0.
          eapply H1 in H4; eauto.
          forward_reason.
          eexists; split; eauto.
          intros. eapply H5 in H7; clear H5.
          forward_reason. split; auto. intros.
          revert H7. clear.
          unfold Open_App, OpenT, ResType.OpenT.
          repeat first [ rewrite eq_Const_eq | rewrite eq_Arr_eq ].
          repeat match goal with
                   | H : ?X = _ , H' : ?Y = _ |- _ =>
                     change Y with X in H' ; rewrite H in H'
                 end.
          inv_all; subst.
          intro.
          match goal with
            | |- match ?X with _ => _ end = match ?Y with _ => _ end =>
              change Y with X ; generalize X
          end.
          intros. eapply match_eq_match_eq with (pf := e) (F := fun x => x).
          eapply functional_extensionality.
          intros. specialize (H7 (Hcons (Rcast_val eq_refl x1) vs')).
          auto. } }
      { rewrite exprUnify_simul'_eq.
        destruct e2; try solve [ congruence | intros; eapply handle_uvar_simul with (e := Abs t e1); eauto ].
        forward. inv_all; subst.
        destruct H.
        destruct (IHe1 e2 s s' t2 (t :: tv')) as [ Hx Hy ] ; clear Hx.
        eapply Hy in H2; clear Hy; eauto.
        forward_reason. split; auto.
        simpl; intros. forward.
        simpl in H0.
        eapply H0 in H4; try congruence.
        forward_reason.
        generalize (exprD_typeof_eq _ _ _ _ _ H4 H2).
        generalize (exprD_typeof_eq _ _ _ _ _ H7 H3).
        intros; subst. subst.
        autorewrite with exprD_rw. simpl.
        repeat rewrite typ2_match_zeta by eauto.
        repeat rewrite type_cast_refl by eauto.
        Cases.rewrite_all_goal.
        repeat rewrite eq_option_eq.
        do 2 eexists; split; eauto. split; eauto.
        eexists; split; eauto.
        intros.
        eapply H9 in H10; clear H9.
        forward_reason; split; auto.
        intros.
        unfold OpenT, ResType.OpenT.
        repeat first [ rewrite eq_Const_eq | rewrite eq_Arr_eq ].
        match goal with
          | |- match ?X with _ => _ end = _ =>
            eapply match_eq_match_eq with (pf := X) (F := fun x => x)
        end.
        eapply functional_extensionality.
        intros. exact (H10 (Hcons (Rcast_val (Rrefl nil t) x2) vs')). } }
    { (** UVar **)
      split.
      { simpl; destruct e2; intros; try solve [ congruence | eapply handle_uvar'; eauto ].
        consider (EqNat.beq_nat u u0).
        { intros; inv_all; subst.
          split; auto. intros. change_rewrite H in H1.
          inv_all; subst.
          eauto. }
        { intro XXX; clear XXX.
          consider (lookup u s); consider (lookup u0 s); intros.
          { eapply unifyOk in H2.
            forward_reason. split; auto.
            intros.
            eapply lookup_lift in H1; eauto.
            eapply lookup_lift in H; eauto.
            forward_reason.
            eapply H3 in H; clear H3; eauto.
            forward_reason. eexists; split; eauto.
            intros. eapply H3 in H9.
            forward_reason. split; auto.
            intros. rewrite H8; eauto. rewrite H7; eauto. }
          { eapply handle_set in H2; eauto.
            forward_reason; split; auto; intros.
            eapply substD_lookup in H1; eauto.
            forward_reason. simpl in *.
            autorewrite with exprD_rw in H4. simpl in H4.
            forward.
            destruct r. inv_all; subst.
            eapply nth_error_get_hlist_nth_Some in H8. simpl in *.
            forward_reason.
            assert (x2 = x) by congruence.
            subst.
            eapply H3 in H1; eauto.
            forward_reason; eexists; split; eauto.
            intros. eapply H8 in H10; clear H8.
            forward_reason; split; eauto.
            unfold Rcast_val, Rcast, Relim. simpl.
            intros. rewrite H4; clear H4.
            eapply H7 in H8; clear H7; change_rewrite H8.
            rewrite <- H10.
            match goal with
              | |- match _ with eq_refl => match _ with eq_refl => ?X end end = ?Y =>
                change Y with X ; generalize X
            end.
            clear - EqDec_typ.
            destruct x1.
            rewrite (UIP_refl x3). reflexivity. }
          { eapply handle_set in H2; eauto.
            forward_reason; split; auto; intros.
            eapply substD_lookup in H; eauto.
            forward_reason. simpl in *.
            autorewrite with exprD_rw in H5. simpl in H5.
            forward.
            destruct r. inv_all; subst.
            eapply nth_error_get_hlist_nth_Some in H8. simpl in *.
            forward_reason.
            assert (x2 = x) by congruence.
            subst.
            eapply H3 in H; eauto.
            forward_reason; eexists; split; eauto.
            intros. eapply H8 in H10; clear H8.
            forward_reason; split; eauto.
            unfold Rcast_val, Rcast, Relim. simpl.
            intros. rewrite H5; clear H5.
            eapply H7 in H8; clear H7; change_rewrite H8.
            rewrite <- H10.
            symmetry.
            match goal with
              | |- match _ with eq_refl => match _ with eq_refl => ?X end end = ?Y =>
                change Y with X ; generalize X
            end.
            clear - EqDec_typ.
            destruct x1.
            rewrite (UIP_refl x3). reflexivity. }
          { consider (set u (UVar u0) s); intros.
            { inv_all; subst.
              eapply handle_set in H2; eauto.
              forward_reason; split; auto.
              intros.
              specialize (exprD'_lower nil tv' tv (UVar u0) t eq_refl H5).
              simpl. intros; forward_reason.
              eapply H3 in H6; eauto.
              forward_reason; eexists; split; eauto.
              intros. eapply H9 in H10; eauto.
              forward_reason; split; auto.
              intros. rewrite <- H11.
              symmetry.
              exact (H8 us Hnil vs' vs). }
            { clear H2. rename H3 into H2.
              inv_all; subst.
              eapply handle_set in H2; eauto.
              forward_reason; split; auto.
              intros.
              specialize (exprD'_lower nil tv' tv (UVar u) t eq_refl H4).
              simpl. intros; forward_reason.
              eapply H3 in H6; eauto.
              forward_reason; eexists; split; eauto.
              intros. eapply H9 in H10; eauto.
              forward_reason; split; auto.
              intros. rewrite <- H11.
              exact (H8 us Hnil vs' vs). } } } }
      { rewrite exprUnify_simul'_eq.
        destruct e2; try solve [ congruence | intros; eapply handle_uvar_simul'; eauto ].
        consider (EqNat.beq_nat u u0).
        { intros; subst.
          forward. inv_all; subst.
          split; eauto. simpl. intros.
          autorewrite with exprD_rw. simpl.
          match goal with
            | |- exists x y, match ?X with _ => _ end = _ /\
                             match ?Y with _ => _ end = _ /\ _ =>
              change Y with X ; consider X; intros
          end.
          { eapply nth_error_get_hlist_nth_Some in H4.
            forward_reason. destruct s. simpl in *.
            assert (x0 = t) by congruence.
            subst.
            repeat rewrite type_cast_refl by eauto.
            do 2 eexists; split; eauto. }
          { exfalso.
            eapply nth_error_get_hlist_nth_None in H4.
            congruence. } }
        { intro XXX; clear XXX.
          forward. inv_all; subst.
          destruct H2.
          consider (lookup u s); consider (lookup u0 s); intros.
          { eapply unifyOk in H4.
            forward_reason. split; auto.
            intros. clear H6 H7.
            eapply ExprFacts.typeof_expr_exprD' in H; eauto.
            eapply ExprFacts.typeof_expr_exprD' in H0; eauto.
            forward_reason.
            eapply lookup_lift in H2; eauto.
            eapply lookup_lift in H3; eauto.
            forward_reason.
            eapply H5 in H8; [ | eauto | eauto ].
            do 2 eexists; split; eauto. split; eauto.
            forward_reason.
            eexists; split; eauto. intros.
            eapply H9 in H10; clear H9.
            forward_reason; split; auto.
            intros.
            rewrite H7; eauto.
            rewrite H6; eauto. }
          { eapply handle_set in H4; eauto.
            forward_reason; split; auto; intros.
            clear H6 H7.
            eapply ExprFacts.typeof_expr_exprD' in H; eauto.
            eapply ExprFacts.typeof_expr_exprD' in H0; eauto.
            forward_reason.
            do 2 eexists; split; [ eassumption | split; [ eassumption | ] ].
            eapply substD_lookup in H3; eauto. forward_reason.
            simpl in H3.
            autorewrite with exprD_rw in H; simpl in H.
            forward. inv_all; subst. destruct r.
            apply nth_error_get_hlist_nth_Some in H7. simpl in H7.
            forward_reason.
            assert (x1 = x4) by congruence. subst.
            eapply H5 in H3; eauto.
            forward_reason. eexists; split; eauto.
            intros. eapply H7 in H10.
            forward_reason; split; auto.
            intros. unfold Rcast_val, Rcast, Relim. simpl.
            rewrite H.
            eapply H6 in H10; clear H6.
            change_rewrite H10.
            rewrite <- H11.
            clear - EqDec_typ. destruct x3.
            rewrite (UIP_refl x). reflexivity. }
          { eapply handle_set in H4; eauto.
            forward_reason; split; auto; intros.
            clear H6 H7.
            eapply ExprFacts.typeof_expr_exprD' in H; eauto.
            eapply ExprFacts.typeof_expr_exprD' in H0; eauto.
            forward_reason.
            do 2 eexists; split; [ eassumption | split; [ eassumption | ] ].
            eapply substD_lookup in H2; eauto. forward_reason.
            simpl in H2.
            autorewrite with exprD_rw in H0; simpl in H0.
            forward. inv_all; subst. destruct r.
            apply nth_error_get_hlist_nth_Some in H7. simpl in H7.
            forward_reason.
            assert (x1 = x4) by congruence. subst.
            eapply H5 in H8; eauto.
            forward_reason. eexists; split; eauto.
            intros. eapply H8 in H10.
            forward_reason; split; auto.
            intros. unfold Rcast_val, Rcast, Relim. simpl.
            rewrite H0.
            eapply H6 in H10; clear H6.
            change_rewrite H10.
            rewrite <- H11.
            clear - EqDec_typ. destruct x3.
            rewrite (UIP_refl x0). reflexivity. }
          { consider (set u (UVar u0) s); intros.
            { inv_all; subst.
              eapply handle_set in H4; eauto.
              forward_reason; split; auto.
              intros. clear H6 H7.
              eapply ExprFacts.typeof_expr_exprD' in H; eauto.
              eapply ExprFacts.typeof_expr_exprD' in H0; eauto.
              forward_reason.
              specialize (exprD'_lower nil tv' tv (UVar u0) t eq_refl H0).
              intros; forward_reason.
              simpl in *. eapply H5 in H8; eauto.
              forward_reason.
              do 2 eexists; split; [ eassumption | split; [ eassumption | ] ].
              eexists; split; [ eassumption | ].
              intros.
              eapply H9 in H10; forward_reason; split; auto.
              intros.
              specialize (H7 us Hnil vs' vs); simpl in H7.
              rewrite <- H11. auto. }
            { clear H4. rename H5 into H4.
              inv_all; subst.
              eapply handle_set in H4; eauto.
              forward_reason; split; auto.
              intros. clear H6 H7.
              eapply ExprFacts.typeof_expr_exprD' in H; eauto.
              eapply ExprFacts.typeof_expr_exprD' in H0; eauto.
              forward_reason.
              specialize (exprD'_lower nil tv' tv (UVar u) t eq_refl H).
              intros; forward_reason.
              simpl in *. eapply H5 in H8; eauto.
              forward_reason.
              do 2 eexists; split; [ eassumption | split; [ eassumption | ] ].
              eexists; split; [ eassumption | ].
              intros.
              eapply H9 in H10; forward_reason; split; auto.
              intros.
              specialize (H7 us Hnil vs' vs); simpl in H7.
              rewrite <- H11. auto. } } } } }
  Qed.

  Theorem exprUnify'_sound
  : forall unify,
      unify_sound_ind unify ->
      unify_sound_ind (fun ts => exprUnify' ts (unify ts)).
  Proof.
    intros.
    red. intros.
    eapply exprUnify'_sound_mutual in H.
    destruct H.
    eauto.
  Qed.

  Theorem exprUnify_sound : forall fuel, unify_sound (exprUnify fuel).
  Proof.
    induction fuel; simpl; intros; try congruence.
    eapply exprUnify'_sound. eassumption.
  Qed.

End typed.
