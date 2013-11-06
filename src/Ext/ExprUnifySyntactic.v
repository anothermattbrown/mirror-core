Require Import List.
Require Import ExtLib.Core.RelDec.
Require Import ExtLib.Data.ListNth.
Require Import ExtLib.Tactics.Consider.
Require Import ExtLib.Tactics.Injection.
Require Import ExtLib.Tactics.EqDep.
Require Import ExtLib.Tactics.Cases.
Require Import MirrorCore.EnvI.
Require Import MirrorCore.SymI.
Require Import MirrorCore.Subst.
Require Import MirrorCore.Ext.Types.
Require Import MirrorCore.Ext.ExprCore.
Require Import MirrorCore.Ext.ExprT.
Require Import MirrorCore.Ext.ExprD.
Require Import MirrorCore.Ext.ExprLift.

(** TODO **)
Require Import FunctionalExtensionality.

Set Implicit Arguments.
Set Strict Implicit.

Section typed.
  Variable subst : Type.
  Variable types : Types.types.
  Variable func : Type.
  Variable RSym_func : RSym (typD types) func.
  Variable RelDec_eq_func : RelDec (@eq func).
  Variable Subst_subst : Subst subst (expr func).
  Variable SubstOk_subst : SubstOk (Expr_expr RSym_func) Subst_subst.
  Variable RelDec_Correct_eq_func : RelDec_Correct RelDec_eq_func.

  Section nested.

  (** n is the number of binders that we have gone under **)
  Variable exprUnify : forall (us vs : tenv typ) (under : nat) (s : subst)
                              (l r : expr func), typ -> option subst.

  Fixpoint exprUnify' (us vs : tenv typ) (n : nat) (s : subst)
           (e1 e2 : expr func) (t : typ) {struct e1}
  : option subst.
  refine (
    match e1 , e2 with
      | UVar u1 , UVar u2 =>
        if EqNat.beq_nat u1 u2 then Some s
        else
          match Subst.lookup u1 s , Subst.lookup u2 s with
            | None , None =>
              match Subst.set u1 (UVar u2) s with
                | None =>
                  Subst.set u2 (UVar u1) s
                | Some s => Some s
              end
            | Some e1' , None =>
              Subst.set u2 e1' s
            | None , Some e2' =>
              Subst.set u1 e2' s
            | Some e1' , Some e2' =>
              exprUnify us vs n s (lift 0 n e1') (lift 0 n e2') t
          end
      | UVar u1 , _ =>
        match Subst.lookup u1 s with
          | None =>
            match lower 0 n e2 with
              | None => None
              | Some e2 => Subst.set u1 e2 s
            end
          | Some e1' => exprUnify us vs n s (lift 0 n e1') e2 t
        end
      | _ , UVar u2 =>
        match Subst.lookup u2 s with
          | None =>
            match lower 0 n e1 with
              | None => None
              | Some e1 => Subst.set u2 e1 s
            end
          | Some e2' => exprUnify us vs n s e1 (lift 0 n e2') t
        end
      | Var v1 , Var v2 =>
        if EqNat.beq_nat v1 v2 then Some s else None
      | Inj f1 , Inj f2 =>
        if f1 ?[ eq ] f2 then Some s else None
      | App e1 e1' , App e2 e2' =>
        match typeof_expr us vs e1 , typeof_expr us vs e2 with
          | Some (tyArr l r) , Some (tyArr l' r') =>
            if l ?[ eq ] l' && r ?[ eq ] r' && t ?[ eq ] r then
              match exprUnify' us vs n s e1 e2 (tyArr l t) with
                | None => None
                | Some s' =>
                  exprUnify' us vs n s' e1' e2' l
              end
            else
              None
          | _ , _ => None
        end
      | Abs t1 e1 , Abs t2 e2 =>
        (* t1 = t2 since both terms have the same type *)
        match t with
          | tyArr _ t =>
            exprUnify' us (t1 :: vs) (S n) s e1 e2 t
          | _ => None
        end
      | _ , _ => None
    end)%bool.
  Defined.
  End nested.

  Section exprUnify.

    Fixpoint exprUnify (fuel : nat) (us vs : tenv typ) (under : nat) (s : subst)
             (e1 e2 : expr func) (t : typ) : option subst :=
      match fuel with
        | 0 => None
        | S fuel =>
          exprUnify' (exprUnify fuel) us vs under s e1 e2 t
      end.
  End exprUnify.

  Definition unify_sound_ind
    (unify : forall (us vs : tenv typ) (under : nat) (s : subst) (l r : expr func)
                    (t : typ), option subst) : Prop :=
    forall tu tv e1 e2 s s' t tv',
      WellTyped_expr tu (tv' ++ tv) e1 t ->
      WellTyped_expr tu (tv' ++ tv) e2 t ->
      WellTyped_subst (SubstOk := SubstOk_subst) tu tv s ->
      unify tu (tv' ++ tv) (length tv') s e1 e2 t = Some s' ->
         WellTyped_subst (SubstOk := SubstOk_subst) tu tv s'
      /\ (forall u v,
            WellTyped_env tu u ->
            WellTyped_env tv v ->
            substD (SubstOk := SubstOk_subst) u v s' ->
               substD (SubstOk := SubstOk_subst) u v s
            /\ forall v',
                 WellTyped_env tv' v' ->
                 exprD u (v' ++ v) e1 t = exprD u (v' ++ v) e2 t).

  Definition unify_sound := unify_sound_ind.

  Lemma handle_set : forall
    (unify : tenv typ -> tenv typ -> nat -> subst ->
             expr func -> expr func -> typ -> option subst),
    unify_sound_ind unify ->
    forall (tu : tenv typ) (tv : list typ) (u : uvar)
           (s s' : subst) (t : typ) (tv' : list typ),
      WellTyped_expr tu (tv' ++ tv) (UVar u) t ->
      WellTyped_subst tu tv s ->
      forall e e' : expr func,
        WellTyped_expr tu (tv' ++ tv) e t ->
        lower 0 (length tv') e = Some e' ->
        lookup u s = None ->
        set u e' s = @Some subst s' ->
        WellTyped_subst tu tv s' /\
        (forall u0 v : @env typ (typD types),
           @WellTyped_env types tu u0 ->
           @WellTyped_env types tv v ->
           substD u0 v s' ->
           substD u0 v s /\
           (forall v' : @env typ (typD types),
              @WellTyped_env types tv' v' ->
              exprD u0 (v' ++ v) (UVar u) t =
              exprD u0 (v' ++ v) e t)).
  Proof.
    intros.
    split.
    { eapply WellTyped_set; eauto.
      simpl. red. generalize (typeof_expr_lower _ tu e nil tv' tv).
      simpl. intro. rewrite <- H6; eauto. }
    { intros.
      generalize H3. intro. eapply substD_set in H8; eauto.
      destruct H8; split; auto. intros.
      rewrite WellTyped_expr_UVar in H0.
      eapply WellTyped_env_typeof_env in H6. subst.
      unfold typeof_env in H0. rewrite nth_error_map in H0.
      autorewrite with exprD_rw. unfold lookupAs.
      destruct (nth_error u0 u); try congruence.
      specialize (H10 _ eq_refl).
      inv_all; subst.
      generalize (exprD_lower _ u0 nil v' v e). simpl.
      cutrewrite (length v' = length tv'). intro X; eapply X in H9.
      etransitivity. 2: symmetry; eassumption. destruct s0; simpl.
      rewrite typ_cast_typ_refl. eauto.
      eapply WellTyped_env_typeof_env in H11. subst.
      rewrite typeof_env_length. auto. }
  Qed.

  Lemma handle_uvar : forall
     unify : tenv typ ->
             tenv typ -> nat -> subst -> expr func -> expr func -> typ -> option subst,
   unify_sound_ind unify ->
   forall (tu : tenv typ) (tv : list typ) (u : uvar)
     (s s' : subst) (t : typ) (tv' : list typ),
   WellTyped_expr  tu (tv' ++ tv) (UVar u) t ->
   WellTyped_subst tu tv s ->
   forall e : expr func,
   WellTyped_expr tu (tv' ++ tv) e t ->
   match lookup u s with
   | Some e2' =>
       unify tu (tv' ++ tv) (@length typ tv') s e
         (lift 0 (@length typ tv') e2') t
   | None =>
       match lower 0 (@length typ tv') e with
       | Some e1 => set u e1 s
       | None => @None subst
       end
   end = @Some subst s' ->
   WellTyped_subst tu tv s' /\
   (forall u0 v : @env typ (typD types),
    WellTyped_env tu u0 ->
    WellTyped_env tv v ->
    substD u0 v s' ->
    substD u0 v s /\
    (forall v' : @env typ (typD types),
     WellTyped_env tv' v' ->
     exprD u0 (v' ++ v) e t =
     exprD u0 (v' ++ v) (UVar u) t)).
  Proof.
    intros.
    consider (lookup u s); intros.
    { eapply H in H4; eauto using WellTyped_lookup.
      { destruct H4; split; auto.
        intros. specialize (H5 _ _ H6 H7 H8). destruct H5; split; auto.
        intros. specialize (H9 _ H10).
        autorewrite with exprD_rw.
        unfold lookupAs.
        eapply substD_lookup in H3; eauto.
        destruct H3. destruct x. destruct H3. simpl in *. rewrite H3.
        assert (x = t).
        { rewrite WellTyped_expr_UVar in H0.
          eapply WellTyped_env_typeof_env in H6. subst.
          unfold typeof_env in H0.
          rewrite nth_error_map in H0. rewrite H3 in *. inv_all.
          simpl in *. auto. }
        subst. rewrite typ_cast_typ_refl. etransitivity. eapply H9.
        generalize (exprD_lift _ u0 nil v' v e0 t). simpl.
        cutrewrite (length v' = length tv').
        { intro X. etransitivity. eapply X. auto. }
        { eapply WellTyped_env_typeof_env in H10. subst.
          rewrite typeof_env_length. auto. } }
      { eapply WellTyped_lookup in H3. 2: eauto.
        unfold WellTyped_expr in *.
        simpl in *. rewrite H0 in *.
        destruct H3. intuition; inv_all; subst.
        generalize (typeof_expr_lift _ tu nil tv' tv e0); simpl.
        intros. etransitivity; eauto. } }
    { match goal with
        | _ : match ?X with _ => _ end = _ |- _ =>
          consider X; try congruence; intros
      end.
      eapply handle_set in H5; eauto. intuition.
      destruct (H7 _ _ H5 H8 H9); auto.
      destruct (H7 _ _ H5 H8 H9); auto.
      symmetry; eauto. }
  Qed.

  Lemma handle_uvar2 : forall
     unify : tenv typ ->
             tenv typ -> nat -> subst -> expr func -> expr func -> typ -> option subst,
   unify_sound_ind unify ->
   forall (tu : tenv typ) (tv : list typ) (u : uvar)
     (s s' : subst) (t : typ) (tv' : list typ),
   WellTyped_expr tu (tv' ++ tv) (UVar u) t ->
   WellTyped_subst tu tv s ->
   forall e : expr func,
   WellTyped_expr tu (tv' ++ tv) e t ->
   match lookup u s with
   | Some e2' =>
       unify tu (tv' ++ tv) (@length typ tv') s
         (lift 0 (@length typ tv') e2') e t
   | None =>
       match lower 0 (@length typ tv') e with
       | Some e1 => set u e1 s
       | None => @None subst
       end
   end = @Some subst s' ->
   WellTyped_subst tu tv s' /\
   (forall u0 v : @env typ (typD types),
    WellTyped_env tu u0 ->
    WellTyped_env tv v ->
    substD u0 v s' ->
    substD u0 v s /\
    (forall v' : @env typ (typD types),
     WellTyped_env tv' v' ->
     exprD u0 (v' ++ v) (UVar u) t =
     exprD u0 (v' ++ v) e t)).
  Proof.
    intros.
    consider (lookup u s); intros.
    { eapply H in H4; eauto using WellTyped_lookup.
      { destruct H4; split; auto.
        intros. specialize (H5 _ _ H6 H7 H8). destruct H5; split; auto.
        intros. specialize (H9 _ H10).
        autorewrite with exprD_rw.
        unfold lookupAs.
        eapply substD_lookup in H3; eauto.
        destruct H3. destruct x. destruct H3. simpl in *. rewrite H3.
        assert (x = t).
        { rewrite WellTyped_expr_UVar in H0.
          eapply WellTyped_env_typeof_env in H6. subst.
          unfold typeof_env in H0.
          rewrite nth_error_map in H0. rewrite H3 in *. inv_all.
          simpl in *. auto. }
        subst. rewrite typ_cast_typ_refl. symmetry.  etransitivity. symmetry.
        eapply H9.
        generalize (exprD_lift _ u0 nil v' v e0 t). simpl.
        cutrewrite (length v' = length tv').
        { intro X. etransitivity. eapply X. auto. }
        { eapply WellTyped_env_typeof_env in H10. subst.
          rewrite typeof_env_length. auto. } }
      { eapply WellTyped_lookup in H3. 2: eauto.
        unfold WellTyped_expr in *.
        simpl in *. rewrite H0 in *.
        destruct H3; intuition; inv_all; subst.
        generalize (typeof_expr_lift _ tu nil tv' tv e0); simpl.
        intros. etransitivity; eassumption. } }
    { match goal with
        | _ : match ?X with _ => _ end = _ |- _ =>
          consider X; try congruence; intros
      end.
      eapply handle_set in H5; eauto. }
  Qed.

  Lemma WellTyped_from_subst : forall tu tv tv' s e t u,
    WellTyped_subst tu tv s ->
    WellTyped_expr tu (tv' ++ tv) (UVar u) t ->
    Subst.lookup u s = Some e ->
    WellTyped_expr tu (tv' ++ tv) (lift 0 (length tv') e) t.
  Proof.
    intros.
    rewrite WellTyped_expr_UVar in H0.
    eapply WellTyped_lookup in H1. 2: eauto.
    rewrite H0 in *. destruct H1; intuition; inv_all; subst.
    red in H3. simpl in H3.
    red.
    etransitivity.
    eapply (typeof_expr_lift _ tu nil tv' tv e).
    eapply H3.
  Qed.

  Lemma exprD_from_subst : forall us vs vs' s e u t,
    substD us vs s ->
    Subst.lookup u s = Some e ->
    nth_error (typeof_env us) u = Some t ->
    exprD us (vs' ++ vs) (UVar u) t =
    exprD us (vs' ++ vs) (lift 0 (length vs') e) t.
  Proof.
    intros.
    rewrite exprD_UVar.
    unfold lookupAs.
    generalize H0.
    eapply substD_lookup in H0; eauto.
    destruct H0. intuition.
    rewrite nth_error_typeof_env in *.
    rewrite H3 in *. destruct x; inv_all; subst. simpl in *.
    rewrite typ_cast_typ_refl.
    symmetry. etransitivity. eapply (exprD_lift _ us nil vs' vs).
    eapply H4.
  Qed.

  Lemma nth_error_from_WellTyped_UVar : forall tu tv u us t,
    WellTyped_expr tu tv (UVar u) t ->
    WellTyped_env (types := types) tu us ->
    nth_error (typeof_env us) u = Some t.
  Proof.
    intros.
    rewrite WellTyped_expr_UVar in *.
    rewrite WellTyped_env_typeof_env in *. subst. auto.
  Qed.

  Lemma exprUnify'_sound : forall unify,
                             unify_sound_ind unify ->
                             unify_sound_ind (exprUnify' unify).
  Proof.
    Opaque rel_dec.
    red. induction e1; simpl; intros.
    { destruct e2; try congruence; eauto using handle_uvar.
      { consider (EqNat.beq_nat v v0); intros; try congruence.
        inv_all; subst. intuition. } }
    {  destruct e2; try congruence; eauto using handle_uvar.
       forward. }
    { destruct e2; try congruence; eauto using handle_uvar.
      { repeat match goal with
                 | H : match ?X with _ => _ end = _ |- _ =>
                   (consider X; try congruence); [ intros ]
                 | H : not (match ?X with _ => _ end = _) |- _ =>
                   (consider X; try congruence); [ intros ]
                 | H : _ /\ _ |- _ => destruct H
                 | H : not (Some _ = None) |- _ => clear H
               end.
        subst.
        eapply WellTyped_expr_App in H0.
        eapply WellTyped_expr_App in H1.
        do 2 destruct H0. do 2 destruct H1.
        unfold WellTyped_expr in *. rewrite H4 in *.
        repeat match goal with
                 | H : _ /\ _ |- _ => destruct H
                 | H : _ = _ , H' : _ = _ |- _ =>
                   match H with
                     | H' => fail 1
                     | _ => rewrite H in H'
                   end
                 | |- _ => progress (inv_all; subst)
               end.
        simpl in *.
        change typ_eqb with (@rel_dec _ (@eq typ) _) in *.
        consider (t4 ?[ eq ] x0); try congruence.
        consider (t4 ?[ eq ] x2); try congruence.
        intros; inv_all; subst. subst.
        eapply IHe1_1 in H8; try congruence; eauto.
        destruct H8.
        eapply IHe1_2 in H9; try congruence; eauto.
        split.
        { intuition. }
        { intros. destruct H9.
          specialize (H13 u v H8 H11 H12). destruct H13.
          specialize (H5 u v H8 H11 H13). intuition.
          assert (tu = typeof_env u) by (eapply WellTyped_env_typeof_env; assumption).
          assert (tv = typeof_env v) by (eapply WellTyped_env_typeof_env; assumption).
          assert (tv' = typeof_env v') by (eapply WellTyped_env_typeof_env; assumption).
          subst.
          autorewrite with exprD_rw.
          repeat rewrite typeof_env_app in *.
          repeat match goal with
                   | H : _ |- _ => rewrite H
                 end. reflexivity.
          eapply WellTyped_env_typeof_env; reflexivity.
          eapply WellTyped_env_typeof_env; reflexivity. } } }
    { destruct e2; try congruence; eauto using handle_uvar.
      { destruct t0; try congruence.
        specialize (IHe1 e2 s s' t0_2 (t :: tv')). simpl in *.
        eapply WellTyped_expr_Abs in H0. eapply WellTyped_expr_Abs in H1.
        repeat match goal with
                 | H : exists x, _ |- _ => destruct H
                 | H : _ /\ _ |- _ => destruct H
               end.
        inversion H0; clear H0; subst. inversion H1; clear H1; subst.
        destruct (IHe1 H5 H4 H2 H3); clear IHe1.
        split; auto.
        intros.
        assert (tu = typeof_env u) by (eapply WellTyped_env_typeof_env; assumption).
        assert (tv = typeof_env v) by (eapply WellTyped_env_typeof_env; assumption).
        specialize (H1 u v H6 H7 H8).
        intuition.
        autorewrite with exprD_rw.
        assert (tv' = typeof_env v') by (eapply WellTyped_env_typeof_env; assumption); subst.
        gen_refl.
        generalize (@typeof_expr_eq_exprD_False _ _ _ u t1 (v' ++ v) e1 x).
        generalize (@typeof_expr_eq_exprD_False _ _ _ u t1 (v' ++ v) e2 x).
        unfold typecheck_expr, WellTyped_expr in *.
        erewrite typeof_env_app. simpl in *.
        rewrite H5. rewrite H4.
        repeat rewrite rel_dec_eq_true by eauto with typeclass_instances.
        intros. unfold exprD in *. simpl in *. remember (split_env (v' ++ v)).
        destruct s0.
        simpl in *.
        repeat rewrite exprD'_Abs.
        rewrite typ_cast_typ_refl.
        specialize (H9 eq_refl). specialize (H10 eq_refl).
        generalize typeof_expr_exprD'. unfold WellTyped_expr.
        intro XXX. rewrite XXX in H4. rewrite XXX in H5.
        assert (typeof_env v' ++ typeof_env v = x0).
        { rewrite <- typeof_env_app.
          generalize (@split_env_projT1 _ _ (v' ++ v)).
          rewrite <- Heqs0. simpl. intro. symmetry. exact H13. }
        subst.
        destruct H4; destruct H5; intuition.
        rewrite H4 in *. rewrite H5 in *.
        f_equal.
        eapply functional_extensionality; intros.
        inv_all; subst.
        specialize (H12 (existT _ t1 x2 :: v')). simpl in H12.
        rewrite <- Heqs0 in *. simpl in *.
        rewrite H5 in *. rewrite H4 in *.
        assert (WellTyped_env (t1 :: typeof_env v') (existT (typD types nil) t1 x2 :: v')).
        { constructor; auto. }
        apply H12 in H13. inv_all. auto. } }
    { destruct e2; eauto using handle_uvar2.
      { consider (EqNat.beq_nat u u0); intros; inv_all; subst.
        { intuition. }
        { consider (lookup u s); consider (lookup u0 s); intros.
          { eapply H in H6; eauto using WellTyped_from_subst.
            destruct H6; split; auto.
            intros. specialize (H7 u1 v H8 H9 H10).
            intuition. specialize (H12 _ H7).
            rewrite WellTyped_env_typeof_env in H7. subst.
            rewrite typeof_env_length in *.
            etransitivity. etransitivity. 2: eapply H12.
            cut (nth_error (typeof_env u1) u = Some t);
              eauto using exprD_from_subst, nth_error_from_WellTyped_UVar.
            symmetry.
            cut (nth_error (typeof_env u1) u0 = Some t);
              eauto using exprD_from_subst, nth_error_from_WellTyped_UVar. }
          { generalize H5. eapply WellTyped_lookup in H5; eauto.
            destruct H5. destruct H5.
            generalize H6.
            eapply WellTyped_set in H6; eauto.
            { intros. split; auto.
              intros.
              eapply substD_set in H8; eauto.
              intuition.
              erewrite exprD_from_subst; eauto using nth_error_from_WellTyped_UVar.
              rewrite exprD_UVar.
              rewrite WellTyped_expr_UVar in *.
              unfold lookupAs.
              eapply WellTyped_env_typeof_env in H10. subst.
              rewrite nth_error_typeof_env in H1.
              destruct (nth_error u1 u0); try congruence.
              specialize (H14 _ eq_refl).
              destruct s0; simpl in *; inv_all; subst.
              rewrite typ_cast_typ_refl.
              etransitivity.
              eapply (exprD_lift _ u1 nil v' v e t). auto. }
            { red in H0; simpl in *.
              rewrite H0 in H5; inv_all; subst; auto. } }
          { generalize H4. eapply WellTyped_lookup in H4; eauto.
            destruct H4.
            assert (x = t); subst.
            { red in H1. simpl in *. rewrite H1 in *.
              intuition; inv_all; auto. }
            { destruct H4.
              red in H7. simpl in H7.
              generalize H6. eapply WellTyped_set in H6; eauto.
              intros. split; auto.
              intros.
              eapply substD_set in H8; eauto.
              intuition.
              symmetry.
              erewrite exprD_from_subst. 2: eassumption. 2: eassumption.
              2: eapply nth_error_from_WellTyped_UVar.
              2: eapply H1. 2: eassumption.
              symmetry.
              rewrite exprD_UVar.
              rewrite WellTyped_expr_UVar in *.
              unfold lookupAs.
              eapply WellTyped_env_typeof_env in H10. subst.
              rewrite nth_error_typeof_env in *.
              destruct (nth_error u1 u); try congruence.
              specialize (H14 _ eq_refl).
              destruct s0; simpl in *; inv_all; subst.
              rewrite typ_cast_typ_refl.
              symmetry.
              etransitivity.
              eapply (exprD_lift _ u1 nil v' v e t). auto. } }
          { consider (set u (UVar u0) s); intros; inv_all; subst.
            { eapply handle_uvar2; eauto.
              rewrite H5. rewrite lower_lower'. simpl. auto. }
            { eapply handle_uvar; eauto.
              rewrite H4. rewrite lower_lower'. simpl. auto. } } } } }
  Qed.

  Theorem exprUnify_sound : forall fuel, unify_sound (exprUnify fuel).
  Proof.
    induction fuel; simpl; intros; try congruence.
    eapply exprUnify'_sound. eassumption.
  Qed.

End typed.
