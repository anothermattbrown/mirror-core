Require Import Coq.Classes.Morphisms.
Require Import Coq.PArith.BinPos.
Require Import Coq.Relations.Relations.
Require Import Coq.FSets.FMapPositive.
Require Import ExtLib.Core.RelDec.
Require Import ExtLib.Data.Positive.
Require Import ExtLib.Data.HList.
Require Import ExtLib.Data.Option.
Require Import ExtLib.Data.Pair.
Require Import ExtLib.Recur.Relation.
Require Import ExtLib.Recur.GenRec.
Require Import ExtLib.Tactics.
Require Import MirrorCore.SubstI.
Require Import MirrorCore.Lemma.
Require Import MirrorCore.VarsToUVars.
Require Import MirrorCore.Instantiate.
Require Import MirrorCore.Util.Forwardy.
Require Import MirrorCore.RTac.Core.
Require Import MirrorCore.RTac.CoreK.
Require Import MirrorCore.Lambda.Expr.
Require Import MirrorCore.Lambda.ExprTac.
Require Import MirrorCore.Lambda.ExprUnify.
Require Import MirrorCore.Lambda.AppN.
Require Import MirrorCore.Lambda.ExprSubstitute.

Set Implicit Arguments.
Set Strict Implicit.

Section setoid.
  Context {typ : Type}.
  Context {func : Type}.
  Context {RType_typD : RType typ}.
  Context {Typ2_Fun : Typ2 RType_typD Fun}.
  Context {RSym_func : RSym func}.

  (** Reasoning principles **)
  Context {RTypeOk_typD : RTypeOk}.
  Context {Typ2Ok_Fun : Typ2Ok Typ2_Fun}.
  Context {RSymOk_func : RSymOk RSym_func}.
  Context {Typ0_Prop : Typ0 _ Prop}.
  Context {RelDec_eq_typ : RelDec (@eq typ)}.
  Context {RelDec_Correct_eq_typ : RelDec_Correct RelDec_eq_typ}.

  Let tyArr : typ -> typ -> typ := @typ2 _ _ _ _.

  Variable Rbase : Type.
  Variable Req : Rbase -> Rbase -> bool.

  Inductive R : Type :=
  | Rinj (r : Rbase)
  | Rrespects (l r : R)
  | Rpointwise (t : typ) (r : R).

  Variable RbaseD : Rbase -> forall t : typ, option (typD t -> typD t -> Prop).

  Hypothesis RbaseD_single_type
  : forall r t1 t2 rD1 rD2,
      RbaseD r t1 = Some rD1 ->
      RbaseD r t2 = Some rD2 ->
      t1 = t2.

  (** This is due to universe problems! **)
  Definition respectful :=
    fun (A B : Type) (R : A -> A -> Prop) (R' : B -> B -> Prop) (f g : A -> B) =>
      forall x y : A, R x y -> R' (f x) (g y).
  Definition pointwise_relation :=
    fun (A B : Type) (R : B -> B -> Prop) (f g : A -> B) =>
      forall a : A, R (f a) (g a).

  Fixpoint RD (r : R) (t : typ) : option (typD t -> typD t -> Prop) :=
    match r with
      | Rinj r => RbaseD r t
      | Rrespects l r =>
        typ2_match (F:=Fun) (fun T => option (T -> T -> Prop)) t
                   (fun lt rt =>
                      match RD l lt , RD r rt with
                        | Some l , Some r => Some (respectful l r)
                        | _ , _ => None
                      end)
                   None
      | Rpointwise _t r =>
        typ2_match (F:=Fun) (fun T => option (T -> T -> Prop)) t
                   (fun lt rt =>
                      match type_cast t _t with
                        | Some _ =>
                          match RD r rt with
                            | Some r => Some (pointwise_relation (A:=typD lt) r)
                            | _ => None
                          end
                        | None => None
                      end)
                   None
    end.

  Theorem RD_single_type
  : forall r t1 t2 rD1 rD2,
      RD r t1 = Some rD1 ->
      RD r t2 = Some rD2 ->
      t1 = t2.
  Proof.
    clear - RbaseD_single_type Typ2Ok_Fun.
    induction r; simpl; intros.
    { eapply RbaseD_single_type; eauto. }
    { arrow_case_any; try congruence.
      red in x1. subst.
      destruct (typ2_match_case t1); forward_reason.
      { rewrite H2 in H. clear H1 H2.
        red in x3. subst.
        simpl in *.
        autorewrite with eq_rw in *. forward.
        inv_all; subst. specialize (IHr1 _ _ _ _ H H0).
        specialize (IHr2 _ _ _ _ H2 H5). subst; reflexivity. }
      { rewrite H2 in *. congruence. } }
    { arrow_case_any; try congruence.
      destruct (typ2_match_case t1); forward_reason.
      { rewrite H2 in *.
        red in x1; red in x4. subst.
        clear H2 H1. simpl in *.
        autorewrite with eq_rw in *.
        forward. }
      { rewrite H2 in *. congruence. } }
  Qed.

  Definition mrw (T : Type) : Type :=
    tenv typ -> tenv typ -> tenv typ -> nat -> nat -> forall c : Ctx typ (expr typ func), ctx_subst c ->
    option (T * ctx_subst c).

  Definition rw_ret {T} (val : T) : mrw T :=
    fun _ _ _ _ _ _ s => Some (val, s).

  Definition rw_bind {T U} (c : mrw T) (k : T -> mrw U) : mrw U :=
    fun tvs' tus tvs nus nvs ctx cs =>
      match c tvs' tus tvs nus nvs ctx cs with
      | None => None
      | Some (v,cs') => k v tvs' tus tvs nus nvs ctx cs'
      end.

  Definition rw_orelse {T} (c1 c2 : mrw T) : mrw T :=
    fun tvs' tus tvs nus nvs ctx cs =>
      match c1 tvs' tus tvs nus nvs ctx cs with
      | None => c2 tvs' tus tvs nus nvs ctx cs
      | z => z
      end.

  Definition rw_fail {T} : mrw T :=
    fun tvs' tus tvs nus nvs ctx cs =>
      None.

  Section rw_map2.
    Context {T U V : Type}.
    Variable f : T -> U -> mrw V.

    Fixpoint rw_map2 (ts : list T) (us : list U) : mrw (list V) :=
      match ts , us with
        | nil , nil => rw_ret nil
        | t :: ts , u :: us =>
          rw_bind (f t u) (fun v =>
                             rw_bind (rw_map2 ts us)
                                     (fun vs => rw_ret (v :: vs)))
        | _ , _ => rw_fail
      end.
  End rw_map2.

  Let rewrite_expr :=
    forall (es : list (expr typ func * (R -> mrw (expr typ func))))
           (rg : R),
      mrw (expr typ func).

  Local Existing Instance Subst_ctx_subst.
  Local Existing Instance SubstOk_ctx_subst.
  Local Existing Instance SubstUpdate_ctx_subst.
  Local Existing Instance SubstUpdateOk_ctx_subst.
  Local Existing Instance Expr_expr.
  Local Existing Instance ExprOk_expr.

  Definition setoid_rewrite_rel
             (e : expr typ func) (r : R) (rw : mrw (expr typ func)) : Prop :=
    forall (ctx : Ctx typ (expr typ func)) cs (tvs' : tenv typ) cs' (e' : expr typ func),
      let tus := getUVars ctx in
      let tvs := getVars ctx in
      rw tvs' tus tvs (length tus) (length tvs) ctx cs = Some (e', cs') ->
      WellFormed_ctx_subst cs ->
      WellFormed_ctx_subst cs' /\
      forall t rD,
      RD r t = Some rD ->
      match pctxD cs , exprD' tus (tvs' ++ tvs) t e
          , pctxD cs' , exprD' tus (tvs' ++ tvs) t e'
      with
      | Some _ , Some eD , Some csD' , Some eD' =>
        SubstMorphism cs cs' /\
        (forall (us : HList.hlist typD (getAmbientUVars ctx))
                (vs : HList.hlist typD (getAmbientVars ctx)),
            csD' (fun (us : HList.hlist typD (getUVars ctx))
                      (vs : HList.hlist typD (getVars ctx)) =>
                    forall vs',
                      rD (eD us (hlist_app vs' vs)) (eD' us (hlist_app vs' vs))) us vs)
      | None , _ , _ , _
      | Some _ , None , _ , _ => True
      | Some _ , Some _ , None , _
      | Some _ , Some _ , Some _ , None => False
      end.

  Definition setoid_rewrite_spec (rw : expr typ func -> R -> mrw (expr typ func)) : Prop :=
    forall e r, @setoid_rewrite_rel e r (rw e r).

  Definition respectful_spec (respectful : expr typ func -> R -> mrw (list R)) : Prop :=
    forall tvs' (ctx : Ctx typ (expr typ func)) cs cs' e r rs,
      let tus := getUVars ctx in
      let tvs := getVars ctx in
      respectful e r tvs' tus tvs (length tus) (length tvs) ctx cs = Some (rs,cs') ->
      WellFormed_ctx_subst cs ->
      WellFormed_ctx_subst cs' /\
      forall ts t rD,
      RD r t = Some rD ->
      match pctxD cs
          , exprD' tus (tvs' ++ tvs) (fold_right (typ2 (F:=Fun)) t ts) e
          , pctxD cs'
          , RD (fold_right Rrespects r rs) (fold_right (typ2 (F:=Fun)) t ts)
      with
      | Some _ , Some eD , Some csD' , Some rD' =>
        SubstMorphism cs cs' /\
        (forall (us : HList.hlist typD (getAmbientUVars ctx))
                (vs : HList.hlist typD (getAmbientVars ctx)),
            csD' (fun (us : HList.hlist typD (getUVars ctx))
                      (vs : HList.hlist typD (getVars ctx)) =>
                    forall vs',
                      Proper rD' (eD us (hlist_app vs' vs))) us vs)
      | None , _ , _ , _
      | Some _ , None , _ , _ => True
      | Some _ , Some _ , None , _
      | Some _ , Some _ , Some _ , None => False
      end.

  Section setoid_rewrite.
    Variable respectfulness
    : expr typ func -> rewrite_expr.

    Fixpoint setoid_rewrite (e : expr typ func)
             (es : list (expr typ func * (R -> mrw (expr typ func)))) (rg : R)
    : mrw (expr typ func) :=
      match e with
        | App f x =>
          setoid_rewrite f ((x, setoid_rewrite x nil) :: es) rg
        | Abs t e' =>
          match es with
            | nil => match rg with
                       | Rpointwise _t (*=t*) rg' =>
                         fun tvs tus tvs' nus nvs c cs =>
                           match @setoid_rewrite e' nil rg'
                                                 (t::tvs) tus tvs' nus nvs c cs
                           with
                           | Some (e'',cs'') =>
                             Some (Abs t e'', cs'')
                           | None => None
                           end
                       | _ => respectfulness (Abs t e') es rg
                     end
            | _ => respectfulness (Abs t e') es rg
          end
        | Var v => respectfulness (Var v) es rg
        | UVar u => respectfulness (UVar u) es rg
        | Inj i => respectfulness (Inj i) es rg
      end.

    Let _lookupU (u : ExprI.uvar) : option (expr typ func) := None.
    Let _lookupV (under : nat) (v : ExprI.var) : option (expr typ func) :=
      if v ?[ ge ] under then
        None
      else
        Some (Var (under - 1 - v)).

    Definition expr_convert (u : nat) : expr typ func -> expr typ func :=
      expr_subst _lookupU (_lookupV u) 0.

(*
    Definition setoid_rewrite_rec tvs' ctx cs
      (ls : list (expr typ func * (R -> mrw (expr typ func))))
    : Prop :=
      Forall (fun e =>
                forall r,
                  @setoid_rewrite_rel ctx cs tvs' (expr_subst _lookupU (_lookupV (length tvs')) 0 (fst e)) r (snd e r)) ls.
*)

    Definition setoid_rewrite_rec
      (ls : list (expr typ func * (R -> mrw (expr typ func))))
    : Prop :=
      Forall (fun e =>
                forall r,
                  @setoid_rewrite_rel (fst e) r (snd e r)) ls.

(*
    Hypothesis respectfulness_sound
    : forall e e' tus tvs t es rg rD eesD,
        respectfulness e es rg = Some e' ->
        RD rg t = Some rD ->
        setoid_rewrite_rec tus tvs es ->

        exprD' tus tvs t (apps e (map fst es)) = Some eesD ->
        exists eesD',
          exprD' tus tvs t e' = Some eesD' /\
          forall us vs,
            rD (eesD us vs) (eesD' us vs).
*)

    Lemma _lookupV_self_ident : forall u v,
        match _lookupV u match _lookupV u v with
                         | Some (Var v') => v'
                         | _ => v
                         end
        with
        | Some (Var v') => v'
        | _ => v
        end = v.
    Proof.
      clear. subst _lookupV. simpl. intros.
      consider (v ?[ ge ] u); intros.
      { rewrite rel_dec_eq_true; eauto with typeclass_instances. }
      consider ((u - 1 - v) ?[ ge ] u); auto.
      { intros. red in v. simpl in *.
        unfold var. omega. }
    Qed.

    Hypothesis respectfulness_sound
    : forall e es rg,
        @setoid_rewrite_rec es ->
        @setoid_rewrite_rel (apps e (map fst es))
                            rg (respectfulness e es rg).

    Theorem setoid_rewrite_sound
    : forall e es rg,
        @setoid_rewrite_rec es ->
        @setoid_rewrite_rel (apps e (map fst es))
                            rg (setoid_rewrite e es rg).
    Proof.
      induction e; eauto using respectfulness_sound.
      { simpl in *. intros.
        eapply IHe1; eauto.
        constructor; eauto.
        simpl. intros. eapply IHe2. constructor. }
      { simpl in *. intros.
        destruct es; eauto using respectfulness_sound.
        destruct rg; eauto using respectfulness_sound.
        red; red in IHe; simpl in *.
        intros.
        forwardy. inv_all; subst.
        specialize (IHe nil rg (Forall_nil _) _ _ (t :: tvs') _ _ H0 H1); clear H0 H1.
        forward_reason.
        split; auto. intros.
        arrow_case_any.
        { red in x1; subst.
          simpl in H2.
          autorewrite with eq_rw in H2.
          forwardy. inv_all; subst.
          specialize (H1 _ _ H5).
          forward_reason.
          destruct (pctxD cs) eqn:HpctxDcs; trivial.
          rewrite exprD'_Abs; eauto with typeclass_instances.
          rewrite typ2_match_iota; eauto with typeclass_instances.
          unfold Monad.bind, Monad.ret; simpl.
          autorewrite with eq_rw.
          destruct (type_cast x t) eqn:Htcxt; trivial.
          simpl in *.
          destruct (exprD' (getUVars ctx) (t :: tvs' ++ getVars ctx) x0 e)
                   eqn:HexprDe; trivial.
          forwardy. forward_reason.
          rewrite H1.
          rewrite exprD'_Abs; eauto with typeclass_instances.
          rewrite typ2_match_iota; eauto with typeclass_instances.
          unfold Monad.bind, Monad.ret; simpl.
          autorewrite with eq_rw.
          rewrite Htcxt.
          rewrite H4.
          split; eauto.
          intros.
          generalize (H7 us vs); clear H7.
          eapply Ap_pctxD; eauto.
          eapply Pure_pctxD; eauto.
          clear. destruct r.
          intros.
          autorewrite with eq_rw.
          red. intros.
          eapply (H (Hcons a vs')). }
        { exfalso; clear - H2. congruence. } }
    Qed.
  End setoid_rewrite.

  Section top_bottom.
    Context (reflexive transitive : R -> bool)
            (rw : expr typ func -> R -> mrw (expr typ func))
            (respectful : expr typ func -> R -> mrw (list R)).

    Hypothesis reflexiveOk
    : forall r t rD, reflexive r = true -> RD r t = Some rD -> Reflexive rD.
    Hypothesis transitiveOk
    : forall r t rD, transitive r = true -> RD r t = Some rD -> Transitive rD.

    Hypothesis rwOk : setoid_rewrite_spec rw.
    Hypothesis respectfulOk : respectful_spec respectful.

    Lemma exprD'_App
    : forall tus tvs td tr f x fD xD,
        exprD' tus tvs (typ2 (F:=Fun) td tr) f = Some fD ->
        exprD' tus tvs td x = Some xD ->
        exprD' tus tvs tr (App f x) = Some (exprT_App fD xD).
    Proof.
      clear - Typ2Ok_Fun RSymOk_func RTypeOk_typD.
      intros.
      autorewrite with exprD_rw; simpl.
      erewrite exprD_typeof_Some by eauto.
      rewrite H. rewrite H0. reflexivity.
    Qed.

    Fixpoint apply_fold tus tvs t ts
             (es : HList.hlist (fun t => ExprI.exprT tus tvs (typD t)) ts)
    : ExprI.exprT tus tvs (typD (fold_right (typ2 (F:=Fun)) t ts))
      -> ExprI.exprT tus tvs (typD t) :=
      match es in HList.hlist _ ts
            return ExprI.exprT tus tvs (typD (fold_right (typ2 (F:=Fun)) t ts))
                   -> ExprI.exprT tus tvs (typD t)
      with
        | HList.Hnil => fun f => f
        | HList.Hcons t' ts x xs => fun f =>
                                      @apply_fold tus tvs t ts xs (exprT_App f x)
      end.

    Lemma apps_exprD'_fold_type
    : forall tus tvs es e t eD,
        exprD' tus tvs t (apps e es) = Some eD ->
        exists ts fD esD,
          exprD' tus tvs (fold_right (typ2 (F:=Fun)) t ts) e = Some fD /\
          hlist_build (fun t => ExprI.exprT tus tvs (typD t))
                      (fun t e => exprD' tus tvs t e) ts es = Some esD /\
          forall us vs,
            eD us vs = @apply_fold _ _ _ _ esD fD us vs.
    Proof.
      clear - Typ2Ok_Fun RTypeOk_typD RSymOk_func.
      intros.
      rewrite exprD'_apps in H; eauto.
      unfold apps_sem' in H. forward. clear H.
      revert H0; revert H1; revert eD; revert t; revert e0; revert e.
      revert t0.
      induction es; simpl; intros.
      { exists nil. exists eD. exists HList.Hnil.
        simpl. split; eauto.
        forward. destruct r. inv_all; subst. assumption. }
      { arrow_case_any.
        { clear H.
          red in x1. subst.
          simpl in H1. autorewrite with eq_rw in H1.
          forward; inv_all; subst.
          eapply IHes with (e := App e a) in H1; eauto.
          { forward_reason.
            assert (x0 = fold_right (typ2 (F:=Fun)) t x1).
            { autorewrite with exprD_rw in H1; simpl in H1.
              forward; inv_all; subst.
              eapply exprD_typeof_Some in H0; eauto.
              eapply exprD_typeof_Some in H4; eauto.
              rewrite H0 in H4.
              inv_all. assumption. }
            { subst.
              eexists (x :: x1). exists e0.
              eexists. split; eauto.
              split. simpl.
              rewrite H2. rewrite H. reflexivity.
              simpl. intros.
              erewrite exprD'_App in H1; eauto.
              inv_all; subst. eauto. } }
          { erewrite exprD'_App; eauto.
            unfold exprT_App. autorewrite with eq_rw.
            reflexivity. } }
        { inversion H1. } }
    Qed.

    Inductive Forall3 {T U V : Type} (P : T -> U -> V -> Prop)
    : list T -> list U -> list V -> Prop :=
    | Forall3_nil : Forall3 P nil nil nil
    | Forall3_cons : forall t u v ts us vs,
                       P t u v -> Forall3 P ts us vs ->
                       Forall3 P (t :: ts) (u :: us) (v :: vs).

(*
    Theorem rw_map2_sound
    : forall T U V (f : T -> U -> mrw V) (P : T -> U -> V -> Prop) ts us vs,
        rw_map2 f ts us = Some vs ->
        (forall a b c, f a b = rw_ret c -> P a b c) ->
        Forall3 P ts us vs.
    Proof. clear. intros. revert H. revert vs; revert us.
           induction ts; destruct us; simpl in *;
           try solve [ inversion 1 ]; intros.
           { inversion H. constructor. }
           { specialize (H0 a u).
             destruct (f a u); [ simpl in H | inversion H ].
             specialize (IHts us).
             destruct (rw_map2 f ts us); inversion H.
             constructor; eauto. }
    Qed.
*)

    Fixpoint recursive_rewrite (f : expr typ func)
             (es : list (expr typ func * (R -> mrw (expr typ func))))
             (rs : list R)
    : mrw (expr typ func) :=
      match es , rs with
        | nil , nil => rw_ret f
        | e :: es , r :: rs =>
          rw_bind ((snd e) r)
                  (fun e' => recursive_rewrite (App f e') es rs)
        | _ , _ => rw_fail
      end.

    Definition mrw_equiv {T} (rT : T -> T -> Prop) (l : mrw T) (r : mrw T) : Prop :=
      forall a b c d e f g,
        Roption (Eqpair rT eq) (l a b c d e f g) (r a b c d e f g).

    Instance Reflexive_mrw_equiv {T} (rT : T -> T -> Prop) {Refl_rT : Reflexive rT}
    : Reflexive (mrw_equiv rT).
    red. red. intros. eapply Reflexive_Roption. eapply Reflexive_Eqpair; eauto.
    Qed.

    Instance Symmetric_mrw_equiv {T} (rT : T -> T -> Prop) {Sym_rT : Symmetric rT}
    : Symmetric (mrw_equiv rT).
    red. red. intros. eapply Symmetric_Roption. eapply Symmetric_Eqpair; eauto. eapply H.
    Qed.

    Instance Transitive_mrw_equiv {T} (rT : T -> T -> Prop) {Trans_rT : Transitive rT}
    : Transitive (mrw_equiv rT).
    red. red. intros. eapply Transitive_Roption. eapply Transitive_Eqpair; eauto with typeclass_instances.
    eapply H. eapply H0.
    Qed.

    Lemma rw_bind_assoc
    : forall {T U V} (c : mrw T) (k : T -> mrw U) (k' : U -> mrw V),
        mrw_equiv eq
                  (rw_bind (rw_bind c k) k')
                  (rw_bind c (fun x => rw_bind (k x) k')).
    Proof.
      clear. unfold rw_bind. simpl.
      red. intros.
      destruct (c a b c0 d e f g); try constructor.
      destruct p.
      eapply Reflexive_Roption. apply Reflexive_Eqpair; eauto.
    Qed.

    Lemma Proper_rw_bind (T U : Type)
    : Proper (mrw_equiv (@eq T) ==> (pointwise_relation (mrw_equiv (@eq U))) ==> mrw_equiv (@eq U)) (@rw_bind T U).
    Proof.
      clear. red. red. red. red. unfold rw_bind. intros.
      red in H.
      specialize (H a b c d e f g).
      destruct H. constructor.
      destruct H. subst.
      eapply H0.
    Qed.

    Lemma rw_bind_rw_ret
    : forall {T U} (x : T) (k : T -> mrw U),
        rw_bind (rw_ret x) k = k x.
    Proof. clear. reflexivity. Qed.

    Lemma rw_bind_rw_fail
    : forall {T U} (k : T -> mrw U),
        rw_bind rw_fail k = rw_fail.
    Proof. clear. reflexivity. Qed.

    Theorem recursive_rewrite_is_map2
    : forall f es rs,
        mrw_equiv (@eq _)
                  (recursive_rewrite f es rs)
                  (rw_bind (rw_map2 (fun e r => snd e r) es rs)
                           (fun es' => rw_ret (apps f es'))).
    Proof.
      clear.
      intros f es; revert f.
      induction es; destruct rs; simpl; intros; auto.
      { rewrite rw_bind_rw_ret. simpl. reflexivity. }
      { rewrite rw_bind_rw_fail. reflexivity. }
      { rewrite rw_bind_rw_fail. reflexivity. }
      { etransitivity.
        2: symmetry; eapply rw_bind_assoc.
        eapply Proper_rw_bind; auto. reflexivity.
        red; intros.
        rewrite IHes.
        etransitivity.
        2: symmetry; eapply rw_bind_assoc.
        eapply Proper_rw_bind; auto. reflexivity.
        red; intros.
        rewrite rw_bind_rw_ret. reflexivity. }
    Qed.

    Inductive Forall2_hlist2 {T U : Type} (F : U -> Type)
              (P : T -> forall u : U,F u -> F u -> Prop)
    : list T -> forall us : list U, HList.hlist F us -> HList.hlist F us -> Prop :=
    | Forall2_hlist2_nil : Forall2_hlist2 P nil HList.Hnil HList.Hnil
    | Forall2_hlist2_cons : forall t u x y ts us xs ys,
                              P t u x y ->
                              Forall2_hlist2 P ts xs ys ->
                              @Forall2_hlist2 T U F P (t :: ts) (u :: us)
                                              (HList.Hcons x xs)
                                              (HList.Hcons y ys).

    Record rw_concl : Type :=
    { lhs : expr typ func
    ; rel : R
    ; rhs : expr typ func }.

    Definition rw_conclD (tus tvs : tenv typ) (c : rw_concl)
    : option (exprT tus tvs Prop) :=
      match typeof_expr tus tvs c.(lhs) with
      | None => None
      | Some t =>
        match exprD' tus tvs t c.(lhs)
            , exprD' tus tvs t c.(rhs)
            , RD c.(rel) t
        with
        | Some lhs , Some rhs , Some rel =>
          Some (fun us vs => rel (lhs us vs) (rhs us vs))
        | _ , _ , _ => None
        end
      end.

    Definition rw_lemma : Type := Lemma.lemma typ (expr typ func) rw_concl.

    Instance RelDec_eq_R : RelDec (@eq R).
    Admitted.
    Instance RelDecCorrect_eq_R : RelDec_Correct RelDec_eq_R.
    Admitted.


    (** Note, this is quite inefficient due to building and destructing the pair **)
    Fixpoint extend_ctx (tvs' : tenv typ)
             (ctx : Ctx typ (expr typ func)) (cs : ctx_subst ctx) {struct tvs'}
    : { ctx : Ctx typ (expr typ func) & ctx_subst ctx } :=
      match tvs' with
      | nil => @existT _ _ ctx cs
      | t :: tvs' =>
        match @extend_ctx tvs' ctx cs with
        | existT ctx' cs' => @existT _ _ (CAll ctx' t) (AllSubst cs')
        end
      end.

    Definition core_rewrite (lem : rw_lemma) (tac : rtacK typ (expr typ func))
    : expr typ func -> tenv typ -> tenv typ -> nat -> nat ->
      forall c : Ctx typ (expr typ func), ctx_subst c ->
                                          option (expr typ func * ctx_subst c).
    refine (
        match typeof_expr nil lem.(vars) lem.(concl).(lhs) with
        | None => fun _ _ _ _ _ _ _ => None
        | Some t =>
          fun e tus tvs nus nvs ctx cs =>
           let ctx' := CExs ctx lem.(vars) in
           let cs' : ctx_subst ctx' := ExsSubst cs (amap_empty _) in
           let tus' := tus ++ lem.(vars) in
           match exprUnify 10 tus' tvs 0 (vars_to_uvars 0 nus lem.(concl).(lhs)) e t cs' with
           | None => None
           | Some cs'' =>
             let prems := List.map (fun e => GGoal (vars_to_uvars 0 nus e)) lem.(premises) in
             match tac tus' tvs (length lem.(vars) + nus) nvs ctx' cs'' (GConj_list prems) with
             | Solved cs''' =>
               match cs''' in ctx_subst ctx
                     return match ctx with
                            | CExs z _ => option (expr typ func * ctx_subst z)
                            | _ => unit
                            end
               with
               | ExsSubst _ _ cs'''' sub =>
                 if amap_is_full (length lem.(vars)) sub then
                   let res :=
                       instantiate (fun u => amap_lookup u sub) 0 (vars_to_uvars 0 nus lem.(concl).(rhs))
                   in
                   Some (res, cs'''')
                 else
                   None
               | _ => tt
               end
             | _ => None
             end
           end
        end).
    Defined.

    Definition dtree : Type := R -> list (rw_lemma * rtacK typ (expr typ func)).

    Fixpoint rewrite_dtree (ls : list (rw_lemma * rtacK typ (expr typ func)))
    : dtree :=
        match ls with
        | nil => fun _ => nil
        | (lem,tac) :: ls =>
          let build := rewrite_dtree ls in
          fun r =>
            if r ?[ eq ] lem.(concl).(rel) then
              (lem,tac) :: build r
            else
              build r
        end.

    Fixpoint using_rewrite_db' (ls : list (rw_lemma * rtacK typ (expr typ func)))
    : expr typ func -> R ->
      tenv typ -> tenv typ -> nat -> nat -> forall ctx, ctx_subst ctx -> option (expr typ func * ctx_subst ctx) :=
      match ls with
      | nil => fun _ _ _ _ _ _ _ _ => None
      | (lem,tac) :: ls =>
        let res := using_rewrite_db' ls in
        let crw := core_rewrite lem tac in
        fun e r tus tvs nus nvs ctx cs =>
          if r ?[ eq ] lem.(concl).(rel) then
            match crw e tus tvs nus nvs ctx cs with
            | None => res e r tus tvs nus nvs ctx cs
            | X => X
            end
          else res e r tus tvs nus nvs ctx cs
      end.

    Fixpoint wrap_tvs (tvs : tenv typ) (ctx : Ctx typ (expr typ func))
    : Ctx typ (expr typ func) :=
      match tvs with
      | nil => ctx
      | t :: tvs' => wrap_tvs tvs' (CAll ctx t)
      end.

    Fixpoint wrap_tvs_ctx_subst tvs ctx (cs : ctx_subst ctx) : ctx_subst (wrap_tvs tvs ctx) :=
      match tvs as tvs return ctx_subst (wrap_tvs tvs ctx) with
      | nil => cs
      | t :: tvs => wrap_tvs_ctx_subst _ (AllSubst cs)
      end.

    Fixpoint unwrap_tvs_ctx_subst T tvs ctx
    : ctx_subst (wrap_tvs tvs ctx) -> (ctx_subst ctx -> T) -> T :=
      match tvs as tvs
            return ctx_subst (wrap_tvs tvs ctx) -> (ctx_subst ctx -> T) -> T
      with
      | nil => fun cs k => k cs
      | t :: tvs => fun cs k => @unwrap_tvs_ctx_subst T tvs (CAll ctx t) cs (fun z => k (fromAll z))
      end.

    Lemma getUVars_wrap_tvs : forall tvs' ctx, getUVars (wrap_tvs tvs' ctx) = getUVars ctx.
    Proof. clear. induction tvs'; simpl; auto.
           intros.  rewrite IHtvs'. reflexivity.
    Qed.

    Lemma WellFormed_ctx_subst_wrap_tvs : forall tvs' ctx (cs : ctx_subst ctx),
        WellFormed_ctx_subst cs ->
        WellFormed_ctx_subst (wrap_tvs_ctx_subst tvs' cs).
    Proof.
      clear. induction tvs'; simpl; auto.
      intros. eapply IHtvs'. constructor. assumption.
    Qed.

    Lemma WellFormed_ctx_subst_unwrap_tvs
    : forall tvs' ctx ctx' (cs : ctx_subst _)
             (k : ctx_subst (Ctx_append ctx ctx') -> ctx_subst ctx),
        (forall cs, WellFormed_ctx_subst cs -> WellFormed_ctx_subst (k cs)) ->
        WellFormed_ctx_subst cs ->
        WellFormed_ctx_subst (@unwrap_tvs_ctx_subst (ctx_subst ctx)  tvs' (Ctx_append ctx ctx') cs k).
    Proof.
      clear.
      induction tvs'; simpl; auto.
      intros. specialize (IHtvs' ctx (CAll ctx' a) cs).
      simpl in *. eapply IHtvs'; eauto.
      intros. eapply H. rewrite (ctx_subst_eta cs0) in H1.
      inv_all. assumption.
    Qed.

    Lemma getVars_wrap_tvs : forall tvs' ctx,
        getVars (wrap_tvs tvs' ctx) = getVars ctx ++ tvs'.
    Proof.
      clear. induction tvs'; simpl; eauto.
      symmetry. eapply app_nil_r_trans.
      simpl. intros. rewrite IHtvs'. simpl.
      rewrite app_ass_trans. reflexivity.
    Qed.

    Definition for_tactic {T} (m : expr typ func ->
      tenv typ -> tenv typ -> nat -> nat ->
      forall ctx : Ctx typ (expr typ func),
        ctx_subst ctx -> option (T * ctx_subst ctx))
    : expr typ func -> mrw T :=
      fun e tvs' tus tvs nus nvs ctx cs =>
        let under := length tvs' in
        let e' := expr_convert under e in
        match m e' tus (tvs ++ tvs') nus (under + nvs) _ (@wrap_tvs_ctx_subst tvs' ctx cs) with
        | None => None
        | Some (v,cs') => Some (v, @unwrap_tvs_ctx_subst _ tvs' ctx cs' (fun x=> x))
        end.

    Definition using_rewrite_db (ls : list (rw_lemma * rtacK typ (expr typ func)))
    : expr typ func -> R -> mrw (expr typ func) :=
      let rw_db := using_rewrite_db' ls in
      fun e r => for_tactic (fun e => rw_db e r) e.

    Lemma exprD'_weakenV
      : forall (typ : Type) (RType_typD : RType typ)
               (Typ2_Fun : Typ2 RType_typD Fun) (func : Type)
               (RSym_func : RSym func),
        RTypeOk ->
        Typ2Ok Typ2_Fun ->
        RSymOk RSym_func ->
        RTypeOk ->
        Typ2Ok Typ2_Fun ->
        RSymOk RSym_func ->
        forall (tus tvs : tenv typ) (e : expr typ func) (t : typ)
               (val : exprT tus tvs (typD t)) (tvs' : list typ),
          exprD' tus tvs t e = Some val ->
          exists val' : exprT tus (tvs ++ tvs') (typD t),
            exprD' tus (tvs ++ tvs') t e = Some val' /\
            (forall (us : hlist typD tus) (vs : hlist typD tvs)
                    (vs' : hlist typD tvs'),
                val us vs = val' us (hlist_app vs vs')).
    Proof.
      clear. intros.
      eapply ExprFacts.exprD'_weaken with (tus':=nil) in H3; try assumption.
      revert H3. instantiate (1 := tvs'). intros.
      forward_reason.
      generalize (@exprD'_conv typ _ _ _ (tus++nil) tus (tvs++tvs') (tvs++tvs') e t
                               (eq_sym (app_nil_r_trans _)) eq_refl); simpl.
      intros. rewrite H5 in H3; clear H5. autorewrite with eq_rw in H3.
      forwardy.
      inv_all. subst. eexists; split; eauto.
      intros. specialize (H4 us vs Hnil vs').
      rewrite H4.
      rewrite hlist_app_nil_r.
      autorewrite with eq_rw.
      reflexivity.
    Qed.

    Lemma exprD'_weakenU
      : forall (typ : Type) (RType_typD : RType typ)
               (Typ2_Fun : Typ2 RType_typD Fun) (func : Type)
               (RSym_func : RSym func),
        RTypeOk ->
        Typ2Ok Typ2_Fun ->
        RSymOk RSym_func ->
        RTypeOk ->
        Typ2Ok Typ2_Fun ->
        RSymOk RSym_func ->
        forall (tus tvs : tenv typ) (e : expr typ func) (t : typ)
               (val : exprT tus tvs (typD t)) (tus' : list typ),
          exprD' tus tvs t e = Some val ->
          exists val' : exprT (tus ++ tus') tvs (typD t),
            exprD' (tus ++ tus') tvs t e = Some val' /\
            (forall (us : hlist typD tus) (vs : hlist typD tvs)
                    (us' : hlist typD tus'),
                val us vs = val' (hlist_app us us') vs).
    Proof.
      clear. intros.
      eapply ExprFacts.exprD'_weaken with (tvs':=nil) in H3; try assumption.
      revert H3. instantiate (1 := tus'). intros.
      forward_reason.
      generalize (@exprD'_conv typ _ _ _ (tus++tus') (tus++tus') (tvs++nil) tvs e t
                               eq_refl(eq_sym (app_nil_r_trans _))); simpl.
      intros. rewrite H5 in H3; clear H5. autorewrite with eq_rw in H3.
      forwardy.
      inv_all. subst. eexists; split; eauto.
      intros. specialize (H4 us vs us' Hnil).
      rewrite H4.
      rewrite hlist_app_nil_r.
      autorewrite with eq_rw.
      reflexivity.
    Qed.


    (** TODO(gmalecha): Move **)
    Lemma WellFormed_Goal_GConj_list
      : forall tus tvs gs,
        Forall (WellFormed_Goal tus tvs) gs ->
        WellFormed_Goal tus tvs (GConj_list gs).
    Proof.
      clear.
      induction 1.
      { constructor. }
      { simpl. destruct l; eauto.
        eapply WFConj_; eauto. }
    Qed.

    (** TODO(gmalecha): Move **)
    Lemma lemmaD_lemmaD' : forall T cD (l : lemma _ _ T),
        lemmaD cD nil nil l <->
        exists pf, lemmaD' cD nil nil l = Some pf /\
                   pf Hnil Hnil.
    Proof.
      clear. unfold lemmaD. simpl. intros.
      destruct (lemmaD' cD nil nil l).
      { split; eauto. intros; forward_reason.
        inv_all. subst. assumption. }
      { split; intros. inversion H. forward_reason. inversion H. }
    Qed.

    Fixpoint GConj_list_simple {T U} (gs : list (Goal T U)) : Goal T U :=
      match gs with
      | nil => GSolved
      | g :: gs => GConj_ g (GConj_list_simple gs)
      end.

    Lemma list_ind_singleton
    : forall {T : Type} (P : list T -> Prop)
             (Hnil : P nil)
             (Hsingle : forall t, P (t :: nil))
             (Hcons : forall t u us, P (u :: us) -> P (t :: u :: us)),
        forall ls, P ls.
    Proof.
      clear. induction ls; eauto.
      destruct ls. eauto. eauto.
    Qed.

    Existing Instance Reflexive_Roption.
    Existing Instance Reflexive_RexprT.


    Lemma goalD_GConj_list_GConj_list_simple : forall tus tvs gs,
        Roption (RexprT _ _ iff)
                (goalD tus tvs (GConj_list gs))
                (goalD tus tvs (GConj_list_simple gs)).
    Proof.
      clear. induction gs using list_ind_singleton.
      { reflexivity. }
      { simpl.
        destruct (goalD tus tvs t); try reflexivity.
        constructor. do 5 red.
        intros.
        apply equiv_eq_eq in H. apply equiv_eq_eq in H0.
        subst. tauto. }
      { simpl in *.
        destruct (goalD tus tvs t); try constructor.
        destruct IHgs; try constructor.
        do 5 red. intros.
        apply equiv_eq_eq in H0; apply equiv_eq_eq in H1; subst.
        apply Data.Prop.and_cancel. intros.
        apply H; reflexivity. }
    Qed.

    Lemma goalD_GConj_list : forall tus tvs gs,
        Roption (RexprT _ _ iff)
                (goalD tus tvs (GConj_list gs))
                (List.fold_right (fun e P =>
                                    match P , goalD tus tvs e with
                                    | Some P' , Some G =>
                                      Some (fun us vs => P' us vs /\ G us vs)
                                    | _ , _ => None
                                    end) (Some (fun _ _ => True)) gs).
    Proof.
      clear. induction gs using list_ind_singleton.
      { simpl.
        reflexivity. }
      { simpl.
        destruct (goalD tus tvs t); try constructor.
        do 5 red. intros.
        eapply equiv_eq_eq in H.
        eapply equiv_eq_eq in H0. subst. tauto. }
      { simpl in *.
        destruct IHgs.
        { destruct (goalD tus tvs t); constructor. }
        { destruct (goalD tus tvs t); try constructor.
          do 5 red. intros.
          do 5 red in H. rewrite H; eauto.
          eapply equiv_eq_eq in H0.
          eapply equiv_eq_eq in H1. subst.
          tauto. } }
    Qed.

    Lemma amap_substD_amap_empty : forall tus tvs,
        exists sD,
          amap_substD tus tvs (amap_empty (expr typ func)) = Some sD /\
          forall a b, sD a b.
    Proof.
      clear - RTypeOk_typD. intros.
      eapply FMapSubst.SUBST.substD_empty.
    Qed.

    Lemma rw_concl_weaken
      : forall (tus tvs : tenv typ) (l : rw_concl) (lD : exprT tus tvs Prop),
        rw_conclD tus tvs l = Some lD ->
        forall tus' tvs' : list typ,
        exists lD' : exprT (tus ++ tus') (tvs ++ tvs') Prop,
          rw_conclD (tus ++ tus') (tvs ++ tvs') l = Some lD' /\
          (forall (us : hlist typD tus) (us' : hlist typD tus')
                  (vs : hlist typD tvs) (vs' : hlist typD tvs'),
              lD us vs <-> lD' (hlist_app us us') (hlist_app vs vs')).
    Proof.
      unfold rw_conclD. simpl. intros.
      forwardy. inv_all. subst.
      erewrite ExprFacts.typeof_expr_weaken by eauto.
      eapply ExprFacts.exprD'_weaken in H0; eauto.
      destruct H0 as [ ? [ Hx ? ] ]; rewrite Hx; clear Hx.
      eapply ExprFacts.exprD'_weaken in H1; eauto.
      destruct H1 as [ ? [ Hx ? ] ]; rewrite Hx; clear Hx.
      rewrite H2. eexists; split; eauto.
      intros. simpl. rewrite <- H0. rewrite <- H1. reflexivity.
    Qed.

    Opaque instantiate.

    Lemma Forall_cons_iff : forall (T : Type) (P : T -> Prop) a b,
        Forall P (a :: b) <-> (P a /\ Forall P b).
    Proof. clear. split.
           inversion 1; auto.
           destruct 1; constructor; auto.
    Qed.

    Lemma Forall_nil_iff : forall (T : Type) (P : T -> Prop),
        Forall P nil <-> True.
    Proof.
      clear. split; auto.
    Qed.

    Lemma core_rewrite_sound :
      forall ctx (cs : ctx_subst ctx),
        let tus := getUVars ctx in
        let tvs := getVars ctx in
        forall l0 r0 e e' cs',
          rtacK_sound r0 ->
          lemmaD rw_conclD nil nil l0 ->
          core_rewrite l0 r0 e tus tvs (length tus) (length tvs) cs = Some (e', cs') ->
          WellFormed_ctx_subst cs ->
          WellFormed_ctx_subst cs' /\
          (forall (t : typ) (rD : typD t -> typD t -> Prop),
              RD (rel (concl l0)) t = Some rD ->
              match pctxD cs with
              | Some _ =>
                match exprD' tus tvs t e with
                | Some eD =>
                  match pctxD cs' with
                  | Some csD' =>
                    match exprD' tus tvs t e' with
                    | Some eD' =>
                      SubstMorphism cs cs' /\
                      (forall (us : hlist typD (getAmbientUVars ctx))
                              (vs : hlist typD (getAmbientVars ctx)),
                          csD'
                            (fun (us0 : hlist typD (getUVars ctx))
                                 (vs0 : hlist typD (getVars ctx)) =>
                               rD (eD us0 vs0) (eD' us0 vs0)) us vs)
                    | None => False
                    end
                  | None => False
                  end
                | None => True
                end
              | None => True
              end).
    Proof.
      Opaque vars_to_uvars.
      clear transitiveOk reflexiveOk respectfulOk rwOk.
      clear rw respectful transitive reflexive.
      unfold core_rewrite. generalize dependent 10.
      simpl.
      intros.
      consider (typeof_expr nil l0.(vars) l0.(concl).(lhs)); intros.
      { match goal with
        | H : match ?X with _ => _ end = _ |- _ =>
          consider X; intros
        end; try match goal with
                 | H : None = Some _ |- _ => exfalso ; clear - H ; inversion H
                 end.
        match goal with
        | Hrt : rtacK_sound ?X , _ : match ?X _ _ _ _ ?C ?CS ?G with _ => _ end = _ |- _ =>
          specialize (@Hrt C CS G _ eq_refl)
        end.
        match goal with
        | Hrt : rtacK_spec _ _ ?X , H : match ?Y with _ => _ end = _ |- _ =>
          replace Y with X in H ; [ generalize dependent X; intros | f_equal ]
        end.
        2: clear; simpl; repeat rewrite app_length; simpl; omega.
        destruct r; try solve [ exfalso; clear - H4; inversion H4 ].
        rewrite (ctx_subst_eta c0) in H4.
        repeat match goal with
               | H : match ?X with _ => _ end = _ |- _ =>
                 let H' := fresh in
                 destruct X eqn:H'; [ | solve [ exfalso; clear - H4; inversion H4 ] ]
               end.
        inv_all. subst.
        destruct (@exprUnify_sound (ctx_subst (CExs ctx (vars l0))) typ func _ _ _ _ _ _ _ _ _ _ n
                                   _ _ _ _ _ _ _ nil H3).
        { constructor; eauto using WellFormed_entry_amap_empty. }
        destruct H; eauto.
        { eapply WellFormed_Goal_GConj_list.
          induction (premises l0); simpl.
          - constructor.
          - constructor; eauto. constructor. }
        split.
        { rewrite ctx_subst_eta in H.
          inv_all. assumption. }
        intros.
        destruct (pctxD cs) eqn:HpctxDcs; trivial.
        destruct (exprD' (getUVars ctx) (getVars ctx) t0 e) eqn:HexprD'e; trivial.
        simpl in *.
        eapply lemmaD_lemmaD' in H0. forward_reason.
        eapply lemmaD'_weakenU with (tus':=getUVars ctx) in H0;
          eauto using ExprOk_expr, rw_concl_weaken.
        simpl in H0. forward_reason.
        unfold lemmaD' in H0.
        forwardy. inv_all. subst.
        unfold rw_conclD in H11.
        forwardy. inv_all; subst.
        assert (y1 = t).
        { revert H11. revert H1. clear - RTypeOk_typD Typ2Ok_Fun RSymOk_func.
          intros.
          eapply ExprFacts.typeof_expr_weaken
            with (tus':=getUVars ctx)
                 (tvs':=nil)
              in H1; eauto.
          simpl in H1.
          rewrite H1 in H11. inv_all. auto. }
        subst t. rename y1 into t.
        generalize (fun tus tvs e t => @ExprI.exprD'_conv typ _ (expr typ func)
                                          _ tus tus (tvs ++ nil) tvs e t eq_refl
                                          (eq_sym (app_nil_r_trans _))). simpl.
        intro HexprD'_conv.
        rewrite HexprD'_conv in H12. autorewrite with eq_rw in H12.
        rewrite HexprD'_conv in H13. autorewrite with eq_rw in H13.
        forwardy. inv_all. subst.

        generalize (@vars_to_uvars_sound typ (expr typ func) _ _ _ _ _ _ _ _ nil _ _ _ H12).
        simpl. destruct 1 as [ ? [ HexprD'e_subst ? ] ].
        eapply exprD'_weakenV with (tvs':=getVars ctx) in HexprD'e_subst; eauto.
        simpl in HexprD'e_subst. forward_reason.
        assert (t = t0) by eauto using RD_single_type.
        intros; subst.
        replace (length (getUVars ctx ++ t0 :: nil))
           with (S (length (getUVars ctx))) in H17
             by (rewrite app_length; simpl; omega).
        eapply exprD'_weakenU
          with (tus':=l0.(vars)) in HexprD'e; eauto.
        destruct (drop_exact_append_exact (vars l0) (getUVars ctx)) as [ ? [ Hx ? ] ].
        rewrite Hx in *; clear Hx.
        destruct (pctxD_substD H2 HpctxDcs) as [ ? [ Hx ? ] ].
        rewrite Hx in *; clear Hx.
        destruct HexprD'e as [ ? [ Hx ? ] ].
        specialize (H6 _ _ _ H16 Hx eq_refl).
        clear Hx.
        forward_reason.
        generalize (pctxD_SubstMorphism_progress H6).
        simpl. rewrite HpctxDcs.
        intro Hx; specialize (Hx _ eq_refl). destruct Hx.
        rewrite H23 in *.
        assert (exists Ps,
                   goalD (getUVars ctx ++ vars l0) (getVars ctx)
                         (GConj_list
                            (map
                               (fun e2 : expr typ func =>
                                  GGoal (vars_to_uvars 0 (length (getUVars ctx)) e2))
                               (premises l0))) = Some Ps /\
                   forall (us : hlist typD (getUVars ctx)) us' vs,
                     Ps (hlist_app us us') vs <->
                     Forall (fun y => y us (hlist_app us' Hnil)) y).
        { revert H0.
          destruct l0. simpl in *.
          clear - RTypeOk_typD RSymOk_func Typ2Ok_Fun.
          intros.
          cut (exists Ps : exprT (getUVars ctx ++ vars) (getVars ctx) Prop,
                  goalD (getUVars ctx ++ vars) (getVars ctx)
                        (GConj_list_simple
                           (map
                              (fun e2 : expr typ func =>
                                 GGoal (vars_to_uvars 0 (length (getUVars ctx)) e2))
                              premises)) = Some Ps /\
                  (forall (us : hlist typD (getUVars ctx)) (us' : hlist typD vars)
                          (vs : hlist typD (getVars ctx)),
                      Ps (hlist_app us us') vs <->
                      Forall
                        (fun
                            y0 : hlist typD (getUVars ctx) ->
                                 hlist typD (vars ++ nil) -> Prop =>
                            y0 us (hlist_app us' Hnil)) y)).
          { destruct (goalD_GConj_list_GConj_list_simple
                        (getUVars ctx ++ vars) (getVars ctx)
                        (map (fun e2 : expr typ func =>
                                GGoal (vars_to_uvars 0 (length (getUVars ctx)) e2))
                           premises)).
            { intros; forward_reason; congruence. }
            { intros; forward_reason.
              inv_all. subst. eexists; split; eauto.
              intros.
              rewrite <- H2. eapply H.
              reflexivity. reflexivity. } }
          revert H0. revert y.
          induction premises; simpl; intros.
          { eexists; split; eauto.
            simpl. inv_all. subst.
            split; eauto. }
          { simpl in *.
            forwardy. inv_all. subst.
            unfold exprD'_typ0 in H.
            simpl in H. forwardy.
            generalize (@vars_to_uvars_sound typ (expr typ func) _ _ _ _ _ _ _ _ nil _ _ _ H).
            intro. forward_reason.
            unfold propD, exprD'_typ0.
            simpl in H2.
            eapply exprD'_weakenV
              with (tvs':=getVars ctx)
                in H2; eauto.
            forward_reason. simpl in H2.
            generalize (@exprD'_conv typ _ (expr typ func) _); eauto. simpl.
            intro Hx.
            rewrite Hx
               with (pfu:=f_equal _ (eq_sym (app_nil_r_trans _))) (pfv:=eq_refl)
                 in H2.
            autorewrite with eq_rw in H2.
            forwardy.
            rewrite H2.
            specialize (IHpremises _ H0).
            forward_reason. rewrite H6.
            eexists; split; eauto. simpl.
            intros.
            inv_all. subst.
            intros. rewrite Forall_cons_iff.
            rewrite <- (H7 _ _ vs).
            autorewrite with eq_rw.
            specialize (H3 us (hlist_app us' Hnil) Hnil).
            simpl in *.
            rewrite H3; clear H3.
            erewrite (H4 (hlist_app us (hlist_app us' Hnil)) Hnil vs); clear H4.
            simpl. rewrite hlist_app_nil_r.
            unfold f_equal.
            autorewrite with eq_rw.
            clear.
            generalize (app_nil_r_trans vars).
            generalize dependent (vars ++ nil).
            intros; subst. reflexivity. } }
        destruct H24 as [ ? [ Hx ? ] ].
        rewrite Hx in *; clear Hx.
        forwardy.
        rewrite (ctx_subst_eta c0) in H7.
        simpl in H7.
        forwardy. rewrite H26.
        inv_all; subst.
        destruct (amap_substD_amap_empty (getUVars ctx ++ vars l0)
                                         (getVars ctx)) as [ ? [ Hx ? ] ];
          change_rewrite Hx in H6; clear Hx.
        rewrite HpctxDcs in H6.
        simpl in *.
        destruct (drop_exact_append_exact l0.(vars) (getUVars ctx)) as [ ? [ Hx ? ] ];
          rewrite Hx in *; clear Hx.
        destruct H25.
        inv_all. subst.
        forwardy.
        repeat match goal with
               | H : ?X = _ , H' : ?X = _ |- _ => rewrite H in H'
               end.
        forward_reason; inv_all; subst.
        simpl in *.
        rewrite H7 in *.
        rewrite H4 in *.
        rewrite H6 in *.
        rewrite H26 in *.
        inv_all.
        forwardy.
        eapply subst_getInstantiation in H7;
          eauto using WellFormed_entry_WellFormed_pre_entry
                 with typeclass_instances.
        destruct H7.
        assert (exists e'D,
                   exprD' (getUVars ctx) (getVars ctx) t0
                          (instantiate (fun u : ExprI.uvar => amap_lookup u x12)
                                       0 (vars_to_uvars 0 (length (getUVars ctx)) l0.(concl).(rhs))) = Some e'D /\
                   forall us vs,
                     e'D us vs =
                     y0 us (hlist_map
           (fun (t : typ) (x6 : exprT (getUVars ctx) (getVars ctx) (typD t)) =>
            x6 us vs) x5)).
        { (** this says that I can strengthen the expression **)
          admit.
        }
        destruct H7 as [ ? [ Hx ? ] ]; rewrite Hx; clear Hx.
        split.
        { etransitivity; eassumption. }
        intros.
        eapply pctxD_substD' with (us:=us) (vs:=vs) in H37; eauto with typeclass_instances.
        gather_facts.
        eapply pctxD_SubstMorphism; [ | | eauto | ]; eauto.
        gather_facts.
        eapply pctxD_SubstMorphism; [ | | eauto | ]; eauto.
        gather_facts.
        eapply Pure_pctxD; eauto. intros.
        specialize (H us0 vs0).
        specialize (H7 us0 vs0).
        generalize dependent (hlist_map
           (fun (t : typ) (x6 : exprT (getUVars ctx) (getVars ctx) (typD t)) =>
            x6 us0 vs0) x5); simpl; intros.
        apply (H10 _ us0 _) in H9; clear H10.
        rewrite foralls_sem in H9.
        setoid_rewrite impls_sem in H9.
        generalize (H9 h); clear H9.
        rewrite Quant._forall_sem in H25.
        simpl.
        specialize (H25 _ H).
        specialize (H23 _ H).
        specialize (H21 _ H23).
        rewrite H7; clear H7.
        rewrite (H20 us0 vs0 h); clear H20.
        specialize (H22 (hlist_app us0 h) vs0).
        rewrite H28 in H22.
        specialize (H22 (conj H23 H19)).
        forward_reason.
        specialize (H9 Hnil).
        simpl in H9.
        rewrite <- H9; clear H9.
        specialize (fun X => H17 X Hnil); simpl in H17.
        rewrite <- H17; clear H17.
        rewrite <- H15; clear H15.
        rewrite hlist_app_nil_r.
        autorewrite with eq_rw.
        simpl.
        refine (fun x => x _).
        clear x14.
        eapply List.Forall_map.
        eapply H24 in H25.
        revert H25.
        eapply Forall_impl.
        intro. rewrite hlist_app_nil_r. tauto. }
      { exfalso; clear - H3; inversion H3. }
    Time Qed.

    Theorem using_rewrite_db'_sound
    : forall r ctx (cs : ctx_subst ctx),
        let tus := getUVars ctx in
        let tvs := getVars ctx in
        forall hints : list (rw_lemma * rtacK typ (expr typ func)),
        Forall (fun lt =>
                  lemmaD rw_conclD nil nil (fst lt) /\
                  rtacK_sound (snd lt)) hints ->
        forall e e' cs',
          @using_rewrite_db' hints e r tus tvs (length tus) (length tvs) ctx cs = Some (e', cs') ->
          WellFormed_ctx_subst cs ->
          WellFormed_ctx_subst cs' /\
          (forall (t : typ) (rD : typD t -> typD t -> Prop),
              RD r t = Some rD ->
              match pctxD cs with
              | Some _ =>
                match exprD' tus tvs t e with
                | Some eD =>
                  match pctxD cs' with
                  | Some csD' =>
                    match exprD' tus tvs t e' with
                    | Some eD' =>
                      SubstMorphism cs cs' /\
                      (forall (us : hlist typD (getAmbientUVars ctx))
                              (vs : hlist typD (getAmbientVars ctx)),
                          csD'
                            (fun (us0 : hlist typD (getUVars ctx))
                                 (vs0 : hlist typD (getVars ctx)) =>
                                 rD (eD us0 vs0)
                                    (eD' us0 vs0)) us vs)
                    | None => False
                    end
                  | None => False
                  end
                | None => True
                end
              | None => True
              end).
    Proof.
      clear transitiveOk reflexiveOk respectfulOk rwOk.
      clear rw respectful transitive reflexive.
      induction 1.
      { simpl. inversion 1. }
      { simpl. intros. destruct x.
        assert (using_rewrite_db' l e r tus tvs (length tus) (length tvs) cs = Some (e',cs')
             \/ (r = l0.(concl).(rel) /\
                 core_rewrite l0 r0 e tus tvs (length tus) (length tvs) cs = Some (e',cs'))).
        { consider (r ?[ eq ] rel (concl l0)); eauto.
          intros. destruct (core_rewrite l0 r0 e tus tvs (length tus) (length tvs) cs); eauto. }
        clear H1. destruct H3; eauto.
        destruct H1. subst. clear IHForall H0.
        simpl in H. destruct H.
        revert H2. revert H3. revert H. revert H0. clear.
        intros.
        eapply core_rewrite_sound in H3; eauto. }
    Qed.

    Theorem using_rewrite_db_sound
    : forall hints : list (rw_lemma * rtacK typ (expr typ func)),
        Forall (fun lt =>
                  lemmaD rw_conclD nil nil (fst lt) /\
                  rtacK_sound (snd lt)) hints ->
        setoid_rewrite_spec (using_rewrite_db hints).
    Proof.
      clear transitiveOk reflexiveOk respectfulOk rwOk.
      clear rw respectful transitive reflexive.
      unfold using_rewrite_db.
      unfold for_tactic.
      red. red. intros.
      forwardy. inv_all. subst.
      rewrite Plus.plus_comm in H0. rewrite <- app_length in H0.
      destruct (fun Hx =>
                    @using_rewrite_db'_sound r _ (wrap_tvs_ctx_subst tvs' cs) hints H
                                             (expr_convert (length tvs') e) e' c Hx
                                             (WellFormed_ctx_subst_wrap_tvs _ H1)).
      { rewrite <- H0. f_equal.
        eauto using getUVars_wrap_tvs.
        eauto using getVars_wrap_tvs.
        rewrite getUVars_wrap_tvs. reflexivity.
        rewrite getVars_wrap_tvs. reflexivity. }
      clear H0.
      split.
      { eapply WellFormed_ctx_subst_unwrap_tvs with (ctx':=CTop nil nil); eauto. }
      intros.
      specialize (H3 _ _ H0); clear H0.
      admit.
    Qed.

    Instance Injective_mrw_equiv_rw_ret {T} (rT : T -> T -> Prop) (a b : T)
    : Injective (mrw_equiv rT (rw_ret a) (rw_ret b)) :=
    { result := rT a b }.
    Proof.
      unfold rw_ret. clear. intros. red in H.
      specialize (H nil nil nil 0 0 _ (@TopSubst _ _ nil nil)).
      inv_all. assumption.
    Defined.

    Definition rw_bind_catch {T U : Type} (c : mrw T) (k : T -> mrw U) (otherwise : mrw U) : mrw U :=
      fun tus' tus tvs nus nvs ctx cs =>
        match c tus' tus tvs nus nvs ctx cs with
        | None => otherwise tus' tus tvs nus nvs ctx cs
        | Some (val,cs') => k val tus' tus tvs nus nvs ctx cs'
        end.

    Lemma rw_orelse_case
      : forall (T : Type) (A B : mrw T) a b c d e f g h,
        @rw_orelse _ A B a b c d e f g = h ->
        A a b c d e f g = h \/
        B a b c d e f g = h.
    Proof.
      clear. unfold rw_orelse. intros.
      forward.
    Qed.

    Lemma rw_bind_catch_case
      : forall (T U : Type) (A : mrw T) (B : T -> mrw U) (C : mrw U)
               a b c d e f g h,
        @rw_bind_catch _ _ A B C a b c d e f g = h ->
        (exists x g', A a b c d e f g = Some (x,g') /\
                      B x a b c d e f g' = h) \/
        (C a b c d e f g = h /\ A a b c d e f g = None).
    Proof. clear.
           unfold rw_bind_catch. intros; forward.
           left. do 2 eexists; split; eauto.
    Qed.

    Lemma rw_bind_case
      : forall (T U : Type) (A : mrw T) (B : T -> mrw U)
               a b c d e f g h,
        @rw_bind _ _ A B a b c d e f g = Some h ->
        exists x g',
          A a b c d e f g = Some (x, g') /\
          B x a b c d e f g' = Some h.
    Proof. clear.
           unfold rw_bind. intros; forward.
           do 2 eexists; eauto.
    Qed.

    Theorem recursive_rewrite_sound
    : forall tvs',
        forall es ctx (cs : ctx_subst ctx) cs' f f' rs e',
          let tvs := getVars ctx in
          let tus := getUVars ctx in
          recursive_rewrite f' es rs tvs' tus tvs (length tus) (length tvs) cs = Some (e', cs') ->
          forall (Hrws : setoid_rewrite_rec es),
            WellFormed_ctx_subst cs ->
            WellFormed_ctx_subst cs' /\
            forall r t rD',
              RD r t = Some rD' ->
            forall ts fD rD eD,
              exprD' tus (tvs' ++ tvs) t (apps f (map fst es)) = Some eD ->
              exprD' tus (tvs' ++ tvs) (fold_right (typ2 (F:=Fun)) t ts) f = Some fD ->
              RD (fold_right Rrespects r rs) (fold_right (typ2 (F:=Fun)) t ts) = Some rD ->
              match pctxD cs , exprD' tus (tvs' ++ tvs) (fold_right (typ2 (F:=Fun)) t ts) f'
                    , pctxD cs'
              with
              | Some csD , Some fD' , Some csD' =>
                exists eD',
                exprD' tus (tvs' ++ tvs) t e' = Some eD' /\
                SubstMorphism cs cs' /\
                forall us vs,
                  csD' (fun us vs =>
                          forall vs',
                            rD (fD us (hlist_app vs' vs)) (fD' us (hlist_app vs' vs)) ->
                            rD' (eD us (hlist_app vs' vs)) (eD' us (hlist_app vs' vs))) us vs
              | Some _ , Some _ , None => False
              | Some _ , None , _  => True
              | None , _ , _ => True
              end.
    Proof.
      clear reflexiveOk transitiveOk rwOk respectfulOk.
      clear rw respectful reflexive transitive.
      induction es; destruct rs; simpl in *.
      { inversion 1; subst. clear H.
        intros.
        split; try assumption. intros.
        consider (pctxD cs'); intros; trivial.
        assert (ts = nil) by admit.
        subst. simpl in *.
        consider (ExprDsimul.ExprDenote.exprD' (getUVars ctx) (tvs' ++ getVars ctx)
                                               t e'); intros; trivial.
        eexists; split; eauto.
        split; [ reflexivity | ].
        intros.
        eapply Pure_pctxD; eauto.
        intros.
        rewrite H1 in *. rewrite H3 in *.
        inv_all. subst. assumption. }
      { inversion 1. }
      { inversion 1. }
      { intros.
        eapply rw_bind_case in H.
        forward_reason.
        inversion Hrws; clear Hrws; subst.
        specialize (H4 _ _ _ _ _ _ H H0); clear H0 H.
        forward_reason.
        specialize (IHes _ _ _ (App f (fst a)) _ _ _ H1 H5 H); clear H1 H5 H.
        forward_reason.
        split; eauto.
        intros.
        arrow_case_any.
        { unfold Relim in H5; autorewrite with eq_rw in H5.
          forwardy; inv_all; subst.
          destruct ts.
          { exfalso. (*
            simpl in *.
            red in x3. subst.
            clear IHes. clear H5.
            assert ((TransitiveClosure.leftTrans (@tyAcc _ _)) x2 (typ2 x1 x2)).
            { constructor.
              eapply tyAcc_typ2R; eauto. }
            generalize dependent (typ2 x1 x2).
            revert r x2 y2.
                      *) admit. }
          { simpl in *. 
            admit. (*
            specialize (H0 _ _ H5).
            destruct (pctxD cs) eqn:HpctxDcs; trivial.
            destruct (exprD' (getUVars ctx) (tvs' ++ getVars ctx)
                             (typ2 t0 (fold_right (typ2 (F:=Fun)) t ts)) f')
                     eqn:HexprD'f'; trivial.
            specialize (fun fD rD => H1 ts fD rD _ H3).
            red in x3.
            rewrite exprD'_apps in H3 by eauto with typeclass_instances.
            unfold apps_sem' in H3.
            generalize (exprD'_typeof_expr _ (or_introl H4)).
            intro Htypeof_f.
            simpl in H3. rewrite Htypeof_f in H3.
            forwardy.
            unfold type_of_apply in H10.
            rewrite typ2_match_iota in H10 by eauto with typeclass_instances.
            autorewrite with eq_rw in H10. forwardy.
            red in y4. inv_all. subst. clear H10.
            specialize (fun rD => H2 _ rD H7).
            clear H6.
            generalize x3. intro.
            eapply injection in x3. red in x3. simpl in x3.
            destruct x3. subst.
            rewrite (UIP_refl x4). clear x4.
            simpl.
            specialize (H2 _ H9).
            autorewrite with exprD_rw in H7.
            simpl in H7. forwardy.
            inv_all. subst.
            rewrite H6 in *. inv_all. subst.
            rewrite H10 in *.
            destruct (pctxD x0) eqn:HpctxDx0; try contradiction.
            autorewrite with exprD_rw in H2. simpl in H2.
            forwardy.
            rewrite (@exprD_typeof_Some typ func _ _ _ _ _ _ _ _ _ _ _ H1) in H2.
            rewrite HexprD'f' in H2.
            rewrite H1 in H2.
            destruct (pctxD cs') eqn:HpctxDcs'; try contradiction.
            forward_reason.
            eexists; split; eauto.
            split.
            { etransitivity; eauto. }
            { intros.
              generalize (H13 us vs); clear H13.
              eapply Ap_pctxD; eauto.
              eapply pctxD_SubstMorphism; [ | | eauto | ]; eauto.
              generalize (H11 us vs); clear H11.
              eapply Ap_pctxD; eauto.
              eapply Pure_pctxD; eauto.
              repeat match goal with
                     | H : _ = _ , H' : _ = _ |- _ =>
                       rewrite H in H'
                     end. inv_all. subst.
              clear. unfold exprT_App.
              unfold setoid.respectful.
              intros.
              specialize (H vs').
              specialize (H0 vs').
              revert H0. revert H1.
              autorewrite with eq_rw.
              generalize dependent (typ2_cast x1 (fold_right (typ2 (F:=Fun)) t ts)).
              generalize dependent (typD (typ2 x1 (fold_right (typ2 (F:=Fun)) t ts))).
              intros; subst. eauto. } *) } }
        { exfalso. clear - H5. inversion H5. } }
    Time Qed. (* 14s! why is this so long!, this suggests a bad proof *)

    (*
    Lemma rw_orelse_sound : forall {T} (a b c : mrw T),
        rw_orelse a b = c ->
        (exists x, a = Some x /\ c = Some x) \/
        (a = rw_fail /\ b = c).
    Proof. clear. intros. destruct a; eauto. Qed.
     *)

    Definition bottom_up (e : expr typ func) (r : R)
    : mrw (expr typ func) :=
      setoid_rewrite
        (fun e efs r =>
	   let es := map fst efs in
           rw_orelse
	     (rw_bind_catch (respectful e r)
                            (fun rs =>
                               rw_bind (recursive_rewrite e efs rs)
			               (fun e' =>
                                          if transitive r
                                          then rw_orelse (rw e' r) (rw_ret e')
                                          else rw_ret e'))
                            (fun x => rw (apps e es) r x))
	     (if reflexive r then rw_ret (apps e es) else rw_fail))
        e nil r.

    Lemma bottom_up_sound_lem
    : forall e rg,
        @setoid_rewrite_rel e rg (bottom_up e rg).
    Proof.
      unfold bottom_up. intros.
      eapply setoid_rewrite_sound; eauto; try solve [ constructor ].
      clear rg e.
      intros.
      red. intros.
      eapply rw_orelse_case in H0; destruct H0.
      { eapply rw_bind_catch_case in H0; destruct H0.
        { forward_reason.
          eapply rw_bind_case in H2.
          forward_reason.
          eapply respectfulOk in H0; destruct H0; eauto.
          eapply recursive_rewrite_sound with (f := e) in H2; eauto.
          forward_reason.
          consider (transitive rg); intros.
          { eapply rw_orelse_case in H6; destruct H6.
            { eapply rwOk in H6. destruct H6; auto.
              split; auto.
              intros.
              specialize (H7 _ _ H8).
              specialize (fun ts => H4 ts _ _ H8).
              destruct (pctxD cs) eqn:HpctxDcs; trivial.
              destruct (exprD' (getUVars ctx) (tvs' ++ getVars ctx) t (apps e (map fst es)))
                       eqn:HexprD'apps_e_es; trivial.
              specialize (fun ts fD rD => H5 _ _ _ H8 ts fD rD _ HexprD'apps_e_es).
              eapply apps_exprD'_fold_type in HexprD'apps_e_es.
              forward_reason.
              specialize (H4 x3).
              rewrite H9 in H4.
              destruct (pctxD x0) eqn:HpctxDx0; try contradiction.
              destruct (RD (fold_right Rrespects rg x) (fold_right (typ2 (F:=Fun)) t x3)) eqn:Hrd; try contradiction.
              specialize (H5 _ _ _ H9 Hrd).
              rewrite H9 in *.
              destruct (pctxD x2) eqn:HpctxDx2; try contradiction.
              forward_reason.
              rewrite H5 in *.
              destruct (pctxD cs') eqn:HpctxDcs'; try contradiction.
              destruct (exprD' (getUVars ctx) (tvs' ++ getVars ctx) t e'); try contradiction.
              forward_reason.
              split.
              { etransitivity; [ eassumption | etransitivity; eassumption ]. }
              { intros.
                generalize (H15 us vs); clear H15.
                eapply Ap_pctxD; eauto.
                eapply pctxD_SubstMorphism; [ | | eauto | ]; eauto.
                generalize (H13 us vs); clear H13.
                eapply Ap_pctxD; eauto.
                eapply pctxD_SubstMorphism; [ | | eauto | ]; eauto.
                generalize (H14 us vs); clear H14.
                eapply Ap_pctxD; eauto.
                eapply Pure_pctxD; eauto.
                intros.
                eapply transitiveOk in H3; eauto.
                etransitivity; [ clear H15 | eapply H15 ].
                eapply H14; clear H14.
                eapply H13. } }
            { unfold rw_ret in H6. inv_all. subst.
              split; auto.
              intros.
              specialize (H5 _ _ _ H6).
              specialize (fun ts => H4 ts _ _ H6).
              destruct (pctxD cs) eqn:HpctxDcs; trivial.
              destruct (exprD' (getUVars ctx) (tvs' ++ getVars ctx) t (apps e (map fst es))) eqn:HexprD'apps_e_es; trivial.
              destruct (apps_exprD'_fold_type _ _ _ HexprD'apps_e_es).
              forward_reason.
              specialize (fun rD => H5 x1 _ rD _ eq_refl H7).
              specialize (H4 x1).
              rewrite H7 in *.
              destruct (pctxD x0) eqn:HpctxDx0; try contradiction.
              destruct (RD (fold_right Rrespects rg x) (fold_right (typ2 (F:=Fun)) t x1)); try contradiction.
              specialize (H5 _ eq_refl).
              destruct (pctxD cs') eqn:HpctxDcs'; try assumption.
              forward_reason.
              rewrite H5.
              split.
              { etransitivity; eauto. }
              { intros.
                generalize (H11 us vs); clear H11; eapply Ap_pctxD; eauto.
                eapply pctxD_SubstMorphism; [ | | eauto | ]; eauto.
                generalize (H12 us vs); clear H12; eapply Ap_pctxD; eauto.
                eapply Pure_pctxD; eauto.
                revert H9. clear.
                intros.
                eapply H0. eapply H. } } }
          { clear H3.
            inversion H6; clear H6; subst.
            split; eauto. intros.
            specialize (H5 _ _ _ H3).
            specialize (fun ts => H4 ts _ _ H3).
            destruct (pctxD cs) eqn:HpctxDcs; trivial.
            destruct (exprD' (getUVars ctx) (tvs' ++ getVars ctx) t (apps e (map fst es))) eqn:HexprD'apps_e_es; trivial.
             destruct (apps_exprD'_fold_type _ _ _ HexprD'apps_e_es).
             forward_reason.
             specialize (H4 x1).
             specialize (fun rD => H5 x1 _ rD _ eq_refl H6).
             rewrite H6 in *.
             destruct (pctxD x0) eqn:HpctxDx0; try contradiction.
             destruct (RD (fold_right Rrespects rg x) (fold_right (typ2 (F:=Fun)) t x1)); try contradiction.
             specialize (H5 _ eq_refl).
             destruct (pctxD cs') eqn:HpctxDcs'; try assumption.
             forward_reason.
             rewrite H5.
             split.
             { etransitivity; eauto. }
             { intros.
               repeat (gather_facts; try (eapply pctxD_SubstMorphism; eauto; [ ])).
               eapply Pure_pctxD; eauto.
               revert H8. clear.
               intros. eapply H0. eapply H. } } }
        { destruct H0. clear H2.
          eapply rwOk; eauto. } }
      { consider (reflexive rg); intros.
        { inversion H2; clear H2; subst.
          split; eauto. intros.
          specialize (reflexiveOk _ H0 H2).
          destruct (pctxD cs') eqn:HpctxDcs'; trivial.
          destruct (exprD' (getUVars ctx) (tvs' ++ getVars ctx) t (apps e (map fst es))); trivial.
          split.
          { reflexivity. }
          { intros. eapply Pure_pctxD; eauto. } }
        { inversion H2. } }
    Time Qed.

    Theorem bottom_up_sound
    : setoid_rewrite_spec bottom_up.
    Proof.
      intros. red. eapply bottom_up_sound_lem.
    Qed.

(*
    Fixpoint top_down (f : nat) (e : expr typ func) (r : R) {struct f}
    : option (expr typ func) :=
      setoid_rewrite
        (fun e efs r =>
	   let es := map fst efs in
           rw_orelse
             (rw_bind (rw (apps e es) r)
                      (fun e' =>
                         if transitive r then
                           match f with
                             | 0 => rw_ret e'
                             | S f => top_down f e' r
                           end
                         else
                           rw_ret e'))
             match respectful e r with
	       | None => if reflexive r then rw_ret (apps e es) else rw_fail
	       | Some rs =>
	         rw_orelse
                   (recursive_rewrite e efs rs)
		            (fun e' => rw_ret (apps e es')))
                   (if reflexive r then rw_ret (apps e es) else rw_fail)
	     end)
        e nil r.
*)
  End top_bottom.

  Definition auto_setoid_rewrite_bu
             (r : R)
             (reflexive transitive : R -> bool)
             (rewriter : expr typ func -> R -> mrw (expr typ func))
             (respectful : expr typ func -> R -> mrw (list R))
  : rtac typ (expr typ func) :=
    let rw := bottom_up reflexive transitive rewriter respectful in
    fun tus tvs nus nvs ctx cs g =>
      match @rw g r nil tus tvs nus nvs ctx cs with
      | None => Fail
      | Some (g', cs') => More_ cs' (GGoal g')
      end.

  Variable Rflip_impl : Rbase.
  Variable Rflip_impl_is_flip_impl
    : RD (Rinj Rflip_impl) (typ0 (F:=Prop)) =
      Some match eq_sym (typ0_cast (F:=Prop)) in _ = t return t -> t -> Prop with
           | eq_refl => Basics.flip Basics.impl
           end.

  Theorem auto_setoid_rewrite_bu_sound
  : forall is_refl is_trans rw proper
           (His_reflOk :forall r t rD, is_refl r = true -> RD r t = Some rD -> Reflexive rD)
           (His_transOk :forall r t rD, is_trans r = true -> RD r t = Some rD -> Transitive rD),
      setoid_rewrite_spec rw ->
      respectful_spec proper ->
      rtac_sound (auto_setoid_rewrite_bu (Rinj Rflip_impl)
                                         is_refl is_trans rw proper).
  Proof.
    intros. unfold auto_setoid_rewrite_bu. red.
    intros.
    generalize (@bottom_up_sound is_refl is_trans rw proper
                                 His_reflOk His_transOk H H0 g (Rinj Rflip_impl) ctx s nil).
    simpl.
    destruct (bottom_up is_refl is_trans rw proper g (Rinj Rflip_impl) nil
      (getUVars ctx) (getVars ctx) (length (getUVars ctx))
      (length (getVars ctx)) s).
    { destruct p.
      subst.
      red. intros Hbus ? ?.
      specialize (Hbus _ _ eq_refl H2).
      forward_reason.
      split; try assumption.
      split; [ constructor | ].
      specialize (H4 _ _ Rflip_impl_is_flip_impl).
      revert H4.
      destruct (pctxD s) eqn:HpctxDs; try (clear; tauto).
      simpl. unfold propD. unfold exprD'_typ0.
      simpl.
      destruct (exprD' (getUVars ctx) (getVars ctx) (typ0 (F:=Prop)) g);
        try solve [ tauto ].
      destruct (pctxD c) eqn:HpctxDc; try solve [ tauto ].
      destruct (exprD' (getUVars ctx) (getVars ctx) (typ0 (F:=Prop)) e);
        try solve [ tauto ].
      destruct 1; split; try assumption.
      intros. generalize (H5 us vs); clear H5.
      eapply Ap_pctxD; eauto.
      eapply Pure_pctxD; eauto.
      intros.
      specialize (H5 Hnil). simpl in *.
      revert H6 H5. autorewrite with eq_rw.
      unfold Basics.flip, Basics.impl.
      clear. tauto. }
    { subst. intro. clear.
      eapply rtac_spec_Fail. }
  Qed.

End setoid.

(*
Definition my_respectfulness (f : expr typ func)
           (es : list (expr typ func * (RG -> mrw (expr typ func))))
           (rg : RG)
: mrw (expr typ func) :=
  rw_ret (apps f (List.map (fun x => fst x) es)).


Definition my_respectfulness' (f : expr nat nat)
               (es : list (expr nat nat * (RG (typ:=nat) nat -> mrw (typ:=nat) nat (expr nat nat))))
               (rg : RG (typ:=nat) nat)
    : mrw (typ:=nat) nat (expr nat nat) :=
      rw_ret (apps f (List.map (fun x => snd x rg) es)).

  Fixpoint build_big (n : nat) : expr nat nat :=
    match n with
      | 0 => Inj 0
      | S n => App (build_big n) (build_big n)
    end.

  Time Eval vm_compute in
      match setoid_rewrite (Rbase:=nat) (@my_respectfulness nat nat nat) (build_big 24) nil (RGinj 0) (rsubst_empty _) with
        | Some e => true
        | None => false
      end.
*)

(*
    Definition apply_rewrite (l : rw_lemma * rtacK typ (expr typ func)) (e : expr typ func) (t : typ) (r : R)
    : tenv typ -> tenv typ -> nat -> nat ->
      forall c : Ctx typ (expr typ func), ctx_subst c -> option (expr typ func * ctx_subst c).
    refine (
      let '(lem,tac) := l in
      if lem.(concl).(rel) ?[ eq ] r then
        (fun tus tvs nus nvs ctx cs =>
           let ctx' := CExs ctx (t :: lem.(vars)) in
           let cs' : ctx_subst ctx' := ExsSubst cs (amap_empty _) in
           match exprUnify 10 tus tvs 0 (vars_to_uvars 0 (S nus) lem.(concl).(lhs)) e t cs' with
           | None => None
           | Some cs'' =>
             let prems := List.map (fun e => GGoal (vars_to_uvars 0 (S nus) e)) lem.(premises) in
             match tac tus tvs nus nvs ctx' cs'' (GConj_list prems) with
             | Solved cs''' =>
               match cs''' in ctx_subst ctx
                     return match ctx with
                            | CExs z _ => option (expr typ func * ctx_subst z)
                            | _ => unit
                            end
               with
               | ExsSubst _ _ cs'''' sub =>
                 match amap_lookup nus sub with
                 | None => None
                 | Some e =>
                   if amap_is_full (S (length lem.(vars))) sub then
                     Some (e, cs'''')
                   else
                     None
                 end
               | _ => tt
               end
             | _ => None
             end
           end)
      else
        (fun _ _ _ _ _ _ => None)).
    Defined.
*)

(* This fast-path eliminates the need to build environments when unification is definitely going to fail
    Fixpoint checkUnify (e1 e2 : expr typ func) : bool :=
      match e1 , e2 with
      | ExprCore.UVar _ , _ => true
      | ExprCore.Var v1 , ExprCore.Var v2 => v1 ?[ eq ] v2
      | Inj a , Inj b => a ?[ eq ] b
      | App f1 x1 , App f2 x2 => checkUnify f1 f2
      | Abs _ _ , Abs _ _ => true
      | _ , ExprCore.UVar _ => true
      | _ , _ => false
      end.
 *)