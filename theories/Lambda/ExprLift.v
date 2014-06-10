Require Import Coq.Lists.List.
Require Import ExtLib.Core.RelDec.
Require Import ExtLib.Structures.Applicative.
Require Import ExtLib.Data.Nat.
Require Import ExtLib.Data.HList.
Require Import ExtLib.Data.Option.
Require Import ExtLib.Data.Eq.
Require Import ExtLib.Tactics.
Require Import MirrorCore.SymI.
Require Import MirrorCore.EnvI.
Require Import MirrorCore.Lambda.TypesI2.
Require Import MirrorCore.Lambda.Expr.

Set Implicit Arguments.
Set Strict Implicit.

Section raw_types.
  Context {typ func : Type}.

  Fixpoint lower (skip : nat) (_by : nat) (e : expr typ func) {struct e}
  : option (expr typ func) :=
    match e with
      | Var v => if v ?[ lt ] skip then Some (Var v)
                 else if (v - skip) ?[ lt ] _by then None
                      else Some (Var (v - _by))
      | Inj f => Some (Inj f)
      | UVar u => Some (UVar u)
      | App a b =>
        ap (ap (pure App) (lower skip _by a)) (lower skip _by b)
      | Abs t a =>
        ap (pure (Abs t)) (lower (S skip) _by a)
    end.

  Fixpoint lift (skip : nat) (_by : nat) (e : expr typ func) {struct e}
  : expr typ func :=
    match e with
      | Var v => Var (if v ?[ lt ] skip then v else (v + _by))
      | Inj f => Inj f
      | UVar u => UVar u
      | App a b =>
        App (lift skip _by a) (lift skip _by b)
      | Abs t a =>
        Abs t (lift (S skip) _by a)
    end.

  Fixpoint vars_to_uvars (e : expr typ func) (skip add : nat) : expr typ func :=
    match e with
      | Var v =>
        if v ?[ lt ] skip then Var v
        else UVar (v - skip + add)
      | UVar _
      | Inj _ => e
      | App l r => App (vars_to_uvars l skip add) (vars_to_uvars r skip add)
      | Abs t e => Abs t (vars_to_uvars e (S skip) add)
    end.

End raw_types.

Section types.
  Context {func : Type}.
  Context {RType_typD : RType}.
  Context {Typ2_Fun : Typ2 RType_typD Fun}.
  Context {RSym_func : RSym typD func}.

  (** Reasoning principles **)
  Context {RTypeOk_typD : @RTypeOk _}.
  Context {Typ2Ok_Fun : Typ2Ok Typ2_Fun}.
  Context {RSymOk_func : RSymOk RSym_func}.

  Theorem typeof_expr_lower
  : forall ts tus e tvs tvs' tvs'' e',
      lower (length tvs) (length tvs') e = Some e' ->
      typeof_expr ts tus (tvs ++ tvs'') e' =
      typeof_expr ts tus (tvs ++ tvs' ++ tvs'') e.
  Proof.
    intros ts tus e tvs tvs' tvs''; revert tvs.
    induction e; simpl; intros; simpl in *; forward; inv_all; subst; auto.
    { consider (v ?[ lt ] length tvs); intros; forward; inv_all; subst.
      { simpl.
        repeat rewrite ListNth.nth_error_app_L by omega. reflexivity. }
      { simpl.
        repeat rewrite ListNth.nth_error_app_R by omega.
        f_equal. omega. } }
    { eapply IHe1 in H. eapply IHe2 in H0.
      simpl. rewrite H0. rewrite H. reflexivity. }
    { simpl. specialize (IHe (t :: tvs)).
      simpl in *. eapply IHe in H.
      destruct H. reflexivity. }
  Qed.

  Theorem exprD'_lower
  : forall ts tus tvs tvs' tvs'' e t val e',
      lower (length tvs) (length tvs') e = Some e' ->
      exprD' ts tus (tvs ++ tvs' ++ tvs'') t e = Some val ->
      exists val',
        exprD' ts tus (tvs ++ tvs'') t e' = Some val' /\
        forall us vs vs' vs'',
          val us (hlist_app vs (hlist_app vs' vs'')) =
          val' us (hlist_app vs vs'').
  Proof.
    intros ts tus tvs tvs' tvs'' e. revert tvs.
    induction e; simpl; intros;
    autorewrite with exprD_rw in *; simpl in *; forward; inv_all; subst.
    { consider (v ?[ lt ] length tvs); intros; forward.
      { inv_all; subst.
        autorewrite with exprD_rw. simpl.
        generalize H.
        eapply nth_error_get_hlist_nth_appL with (F := typD ts) (tvs' := tvs' ++ tvs'') in H.
        intro.
        eapply nth_error_get_hlist_nth_appL with (F := typD ts) (tvs' := tvs'') in H0.
        forward_reason; Cases.rewrite_all_goal.
        destruct x0; simpl in *.
        rewrite H3 in *. rewrite H1 in *. inv_all; subst.
        simpl in *. rewrite H2. eexists; split; eauto.
        intros. simpl. rewrite H6. rewrite H4. reflexivity. }
      { inv_all; subst.
        autorewrite with exprD_rw. simpl.
        consider (nth_error_get_hlist_nth (typD ts) (tvs ++ tvs'') (v - length tvs')); intros.
        { destruct s.
          eapply nth_error_get_hlist_nth_appR in H1; [ simpl in * | omega ].
          destruct H1 as [ ? [ ? ? ] ].
          eapply nth_error_get_hlist_nth_appR in H1; [ simpl in * | omega ].
          eapply nth_error_get_hlist_nth_appR in H3; [ simpl in * | omega ].
          forward_reason.
          replace (v - length tvs' - length tvs)
             with (v - length tvs - length tvs') in H3 by omega.
          rewrite H1 in *. inv_all; subst. rewrite H2.
          eexists; split; eauto. intros.
          rewrite H4. rewrite H6. rewrite H5. reflexivity. }
        { exfalso.
          rewrite nth_error_get_hlist_nth_None in H3.
          eapply nth_error_get_hlist_nth_Some in H1. destruct H1. clear H1.
          simpl in *.
          repeat rewrite ListNth.nth_error_app_R in * by omega.
          replace (v - length tvs' - length tvs)
             with (v - length tvs - length tvs') in H3 by omega.
          congruence. } } }
    { autorewrite with exprD_rw. rewrite H0. simpl. eauto. }
    { autorewrite with exprD_rw.
      generalize H4.
      eapply typeof_expr_lower in H4; rewrite H4; clear H4.
      rewrite H0. simpl. intro.
      eapply IHe1 in H; eauto.
      eapply IHe2 in H4; eauto.
      forward_reason.
      Cases.rewrite_all_goal.
      eexists; split; eauto. intros.
      unfold Open_App.
      match goal with
        | |- match ?X with _ => _ end _ _ _ _ =
             match ?Y with _ => _ end _ _ _ _ =>
          change Y with X ; generalize X
      end; intros.
      unfold OpenT.
      repeat first [ rewrite eq_Const_eq | rewrite eq_Arr_eq ].
      clear - H4 H5. destruct e; simpl.
      rewrite H5. rewrite H4. reflexivity. }
    { autorewrite with exprD_rw in *; simpl in *.
      destruct (typ2_match_case ts t0).
      { destruct H1 as [ ? [ ? [ ? ? ] ] ].
        rewrite H1 in *; clear H1.
        generalize dependent (typ2_cast ts x x0).
        destruct x1. simpl in *. intros.
        specialize (IHe (t :: tvs)). simpl in *.
        repeat first [ rewrite eq_option_eq in *
                     | rewrite eq_Const_eq in *
                     | rewrite eq_Arr_eq in * ].
        forward; inv_all; subst.
        eapply IHe in H2; eauto.
        forward_reason; Cases.rewrite_all_goal.
        simpl. eexists; split; eauto.
        intros. eapply FunctionalExtensionality.functional_extensionality.
        intros.
        specialize (H2 us (Hcons x2 vs)).
        simpl in H2. rewrite H2. reflexivity. }
      { rewrite H1 in *. congruence. } }
    { autorewrite with exprD_rw. rewrite H1. simpl.
      rewrite H2. eauto. }
  Qed.

  Theorem typeof_expr_lift
  : forall ts tus e tvs tvs' tvs'',
      typeof_expr ts tus (tvs ++ tvs' ++ tvs'') (lift (length tvs) (length tvs') e) =
      typeof_expr ts tus (tvs ++ tvs'') e.
  Proof.
    intros ts tus e tvs; revert tvs; induction e; simpl; intros;
    Cases.rewrite_all_goal; auto.
    { consider (v ?[ lt ] length tvs); intros.
      { repeat rewrite ListNth.nth_error_app_L by auto.
        reflexivity. }
      { repeat rewrite ListNth.nth_error_app_R by omega.
        f_equal. omega. } }
    { specialize (IHe (t :: tvs)). simpl in *.
      rewrite IHe. reflexivity. }
  Qed.

  Theorem exprD'_lift
  : forall ts tus e tvs tvs' tvs'' t,
      match exprD' ts tus (tvs ++ tvs'') t e with
        | None => True
        | Some val =>
          match exprD' ts tus (tvs ++ tvs' ++ tvs'') t (lift (length tvs) (length tvs') e) with
            | None => False
            | Some val' => True
          end
      end.
  Proof.
    induction e; simpl; intros; autorewrite with exprD_rw; simpl;
    forward; inv_all; subst; Cases.rewrite_all_goal; auto.
    { consider (v ?[ lt ] length tvs); intros.
      { generalize H.
        eapply nth_error_get_hlist_nth_appL with (tvs' := tvs' ++ tvs'') (F := typD ts) in H; eauto with typeclass_instances.
        intro.
        eapply nth_error_get_hlist_nth_appL with (tvs' := tvs'') (F := typD ts) in H3; eauto with typeclass_instances.
        forward_reason.
        revert H2. Cases.rewrite_all_goal. destruct x1.
        simpl in *.
        destruct r. rewrite H6 in *. rewrite H0 in *.
        inv_all; subst. simpl in *.
        rewrite type_cast_refl; eauto. congruence. }
      { eapply nth_error_get_hlist_nth_appR in H0; [ simpl in * | omega ].
        forward_reason.
        consider (nth_error_get_hlist_nth (typD ts) (tvs ++ tvs' ++ tvs'')
           (v + length tvs')); intros.
        { destruct s. forward.
          eapply nth_error_get_hlist_nth_appR in H2; [ simpl in * | omega ].
          forward_reason.
          eapply nth_error_get_hlist_nth_appR in H2; [ simpl in * | omega ].
          forward_reason.
          replace (v + length tvs' - length tvs - length tvs')
             with (v - length tvs) in H2 by omega.
          rewrite H0 in *. inv_all; subst. congruence. }
        { rewrite nth_error_get_hlist_nth_None in H2.
          eapply nth_error_get_hlist_nth_Some in H0. destruct H0.
          clear H0. simpl in *.
          repeat rewrite ListNth.nth_error_app_R in H2 by omega.
          replace (v + length tvs' - length tvs - length tvs')
             with (v - length tvs) in H2 by omega.
          congruence. } } }
    { revert H3. rewrite typeof_expr_lift. rewrite H.
      specialize (IHe1 tvs tvs' tvs'' (typ2 t0 t)).
      specialize (IHe2 tvs tvs' tvs'' t0).
      forward. }
    { destruct (typ2_match_case ts t0).
      { destruct H1 as [ ? [ ? [ ? ? ] ] ].
        rewrite H1 in *; clear H1.
        generalize dependent (typ2_cast ts x x0).
        destruct x1. simpl.
        intros. rewrite eq_option_eq in *.
        forward. inv_all; subst.
        specialize (IHe (t :: tvs) tvs' tvs'' x0).
        revert IHe. simpl. Cases.rewrite_all_goal.
        auto. }
      { rewrite H1 in *. congruence. } }
  Qed.

  Theorem vars_to_uvars_typeof_expr
  : forall ts tus e tvs tvs' t,
      typeof_expr ts tus (tvs ++ tvs') e = Some t ->
      typeof_expr ts (tus ++ tvs') tvs (vars_to_uvars e (length tvs) (length tus))
      = Some t.
  Proof.
    induction e; simpl; intros; auto.
    { consider (v ?[ lt ] length tvs); intros.
      { simpl. rewrite ListNth.nth_error_app_L in H; auto. }
      { simpl. rewrite ListNth.nth_error_app_R in H; auto. 2: omega.
        rewrite ListNth.nth_error_app_R; try omega.
        replace (v - length tvs + length tus - length tus) with (v - length tvs)
          by omega.
        auto. } }
    { forward. erewrite IHe1; eauto. erewrite IHe2; eauto. }
    { forward. eapply (IHe (t :: tvs) tvs') in H.
      simpl in *.
      rewrite H in *. auto. }
    { apply ListNth.nth_error_weaken; auto. }
  Qed.

  Lemma nth_error_get_hlist_nth_rwR
  : forall {T} (F : T -> _) tus tvs' n,
      n >= length tus ->
      match nth_error_get_hlist_nth F tvs' (n - length tus) with
        | None => True
        | Some (existT t v) =>
          exists val,
          nth_error_get_hlist_nth F (tus ++ tvs') n = Some (@existT _ _ t val) /\
          forall a b,
            v a = val (hlist_app b a)
      end.
  Proof.
    clear. intros.
    forward. subst.
    consider (nth_error_get_hlist_nth F (tus ++ tvs') n).
    { intros.
      eapply nth_error_get_hlist_nth_appR in H; eauto.
      destruct s. simpl in *. rewrite H1 in *.
      destruct H as [ ? [ ? ? ] ]. inv_all; subst.
      eexists; split; eauto. }
    { intros.
      exfalso.
      eapply nth_error_get_hlist_nth_Some in H1.
      eapply nth_error_get_hlist_nth_None in H0.
      forward_reason. simpl in *.
      eapply ListNth.nth_error_length_ge in H0.
      clear H1. eapply ListNth.nth_error_length_lt in x0.
      rewrite app_length in H0. omega. }
  Qed.

End types.