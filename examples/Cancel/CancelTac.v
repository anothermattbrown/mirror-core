Require Import MirrorCore.ExprI.
Require Import MirrorCore.Lemma.
Require Import MirrorCore.Lambda.Expr.
Require Import MirrorCore.Lambda.ExprUnify.
Require Import MirrorCore.Lambda.Lemma.
Require Import MirrorCore.RTac.RTac.
Require Import McExamples.Cancel.Lang.

Set Implicit Arguments.
Set Strict Implicit.

Section canceller.
  Variables typ func : Type.
  Context {RType_typ : RType typ}.
  Context {RTypeOk_typ : RTypeOk}.
  Context {Typ0_Prop : Typ0 RType_typ Prop}.
  Context {Typ2_func : Typ2 RType_typ RFun}.
  Context {Typ2Ok_func : Typ2Ok Typ2_func}.
  Context {RSym_sym : RSym func}.
  Context {RSymOk_sym : RSymOk RSym_sym}.

  Let Expr_expr := @Expr_expr typ func RType_typ _ _.
  Local Existing Instance Expr_expr.
  Let ExprOk_expr : ExprOk Expr_expr := @ExprOk_expr typ func _ _ _ _ _ _.
  Local Existing Instance ExprOk_expr.
  Local Existing Instance ExprUVarOk_expr.

  Variable T : typ.
  Variable R P U : expr typ func.

  Let p (a b : expr typ func) : expr typ func :=
    App (App P a) b.
  Let r (a b : expr typ func) : expr typ func :=
    App (App R a) b.

  Definition lem_plus_unit_c : Lemma.lemma typ (expr typ func) (expr typ func) :=
  {| vars := T :: T :: nil;
     premises := App (App R (ExprCore.Var 0)) (ExprCore.Var 1) :: nil;
     concl := App (App R (ExprCore.Var 0))  (App (App P U) (ExprCore.Var 1)) |}.
  Definition lem_plus_assoc_c1 : Lemma.lemma typ (expr typ func) (expr typ func) :=
  {| vars := T :: T :: T :: T :: nil;
     premises := App (App R (ExprCore.Var 3))
                     (App (App P (ExprCore.Var 0))
                          (App (App P (ExprCore.Var 1)) (ExprCore.Var 2))) :: nil;
     concl := App (App R (ExprCore.Var 3))
                  (App (App P (App (App P (ExprCore.Var 0)) (ExprCore.Var 1)))
                       (ExprCore.Var 2)) |}.
  Definition lem_plus_assoc_c2 : Lemma.lemma typ (expr typ func) (expr typ func) :=
  {| vars := T :: T :: T :: T :: nil;
     premises := App (App R (ExprCore.Var 3))
                     (App (App P (ExprCore.Var 1))
                          (App (App P (ExprCore.Var 0)) (ExprCore.Var 2))) :: nil;
     concl := App (App R (ExprCore.Var 3))
                  (App (App P (App (App P (ExprCore.Var 0)) (ExprCore.Var 1)))
                       (ExprCore.Var 2)) |}.
  Definition lem_plus_comm_c : Lemma.lemma typ (expr typ func) (expr typ func) :=
  {| vars := T :: T :: T :: nil;
     premises := App (App R (ExprCore.Var 2))
                     (App (App P (ExprCore.Var 0)) (ExprCore.Var 1)) :: nil;
     concl := App (App R (ExprCore.Var 2))
                  (App (App P (ExprCore.Var 1)) (ExprCore.Var 0)) |}.
  Definition lem_plus_cancel : Lemma.lemma typ (expr typ func) (expr typ func) :=
  {| vars := T :: T :: T :: T :: nil;
     premises := App (App R (ExprCore.Var 0)) (ExprCore.Var 2)
                     :: App (App R (ExprCore.Var 1)) (ExprCore.Var 3)
                     :: nil;
     concl := App
                (App R (App (App P (ExprCore.Var 0)) (ExprCore.Var 1)))
                (App (App P (ExprCore.Var 2)) (ExprCore.Var 3)) |}.

  Definition lem_plus_unit_p : Lemma.lemma typ (expr typ func) (expr typ func) :=
  {| vars := T :: T :: nil;
     premises := App (App R (ExprCore.Var 0)) (ExprCore.Var 1) :: nil;
     concl := App (App R (App (App P U) (ExprCore.Var 0)))
                  (ExprCore.Var 1) |}.
  Definition lem_plus_assoc_p1 : Lemma.lemma typ (expr typ func) (expr typ func) :=
  {| vars := T :: T :: T :: T :: nil;
     premises := App
                   (App R
                        (App (App P (ExprCore.Var 0))
                             (App (App P (ExprCore.Var 1)) (ExprCore.Var 2))))
                   (ExprCore.Var 3) :: nil;
     concl := App
                (App R
                     (App (App P (App (App P (ExprCore.Var 0)) (ExprCore.Var 1)))
                          (ExprCore.Var 2))) (ExprCore.Var 3) |}.
  Definition lem_plus_assoc_p2 : Lemma.lemma typ (expr typ func) (expr typ func) :=
  {| vars := T :: T :: T :: T :: nil;
     premises := App
                   (App R
                        (App (App P (ExprCore.Var 1))
                             (App (App P (ExprCore.Var 0)) (ExprCore.Var 2))))
                   (ExprCore.Var 3) :: nil;
     concl := App
                (App R
                     (App (App P (App (App P (ExprCore.Var 0)) (ExprCore.Var 1)))
                          (ExprCore.Var 2))) (ExprCore.Var 3) |}.
  Definition lem_plus_comm_p : Lemma.lemma typ (expr typ func) (expr typ func) :=
  {| vars := T :: T :: T :: nil;
     premises := App
                   (App R
                        (App (App P (ExprCore.Var 0)) (ExprCore.Var 1)))
                   (ExprCore.Var 2) :: nil;
     concl := App
                (App R (App (App P (ExprCore.Var 1)) (ExprCore.Var 0)))
                (ExprCore.Var 2) |}.
  Context {RL1 : ReifiedLemma lem_plus_unit_c}.
  Context {RL2 : ReifiedLemma lem_plus_assoc_c1}.
  Context {RL3 : ReifiedLemma lem_plus_assoc_c2}.
  Context {RL4 : ReifiedLemma lem_plus_comm_c}.
  Context {RL5 : ReifiedLemma lem_plus_cancel}.
  Context {RL6 : ReifiedLemma lem_plus_unit_p}.
  Context {RL7 : ReifiedLemma lem_plus_assoc_p1}.
  Context {RL8 : ReifiedLemma lem_plus_assoc_p2}.
  Context {RL9 : ReifiedLemma lem_plus_comm_p}.
(*  Context {RL10 : ReifiedLemma refl}. *)

  Definition EAPPLY : Lemma.lemma typ (expr typ func) (expr typ func) -> rtac typ (expr typ func) :=
    EAPPLY (fun subst Ssubst SUsubst => @exprUnify subst _ _ _ _ _ Ssubst SUsubst 30).
  Definition APPLY : Lemma.lemma typ (expr typ func) (expr typ func) -> rtac typ (expr typ func) :=
    APPLY (fun subst Ssubst SUsubst => @exprUnify subst _ _ _ _ _ Ssubst SUsubst 30).

  Local Instance RtacSound_EAPPLY l (RL : ReifiedLemma l)
  : RtacSound (EAPPLY l).
  Proof.
    constructor.
    eapply EAPPLY_sound; eauto with typeclass_instances.
    intros. eapply exprUnify_sound; eauto with typeclass_instances.
  Qed.

  Local Instance RtacSound_APPLY l (RL : ReifiedLemma l)
  : RtacSound (APPLY l).
  Proof.
    constructor.
    eapply APPLY_sound; eauto with typeclass_instances.
    intros. eapply exprUnify_sound; eauto with typeclass_instances.
  Qed.

  Variable SOLVER : rtac typ (expr typ func).
  Variable RtacSound_SOLVER : RtacSound SOLVER.

  Notation "'delay' x" := (fun y => x y) (at level 3).

  Fixpoint iter_right (Q : expr typ func) : rtac typ (expr typ func) :=
    FIRST [ EAPPLY lem_plus_unit_c
          | delay match Q with
                  | App (App _ L) R => (* guess star *)
                    FIRST [ EAPPLY lem_plus_assoc_c1 ;; delay (ON_ALL (iter_right L))
                          | EAPPLY lem_plus_assoc_c2 ;; delay (ON_ALL (iter_right R))
                          | EAPPLY lem_plus_cancel ;; ON_EACH (SOLVE SOLVER :: IDTAC :: nil)
                          ]
                   | _ =>
                     EAPPLY lem_plus_cancel ;; ON_EACH [ SOLVE SOLVER | IDTAC ]
                 end ].

  Opaque FIRST APPLY EAPPLY.

  Existing Class rtac_sound.
  Existing Instance RtacSound_proof.

  Lemma body_non_c
  : rtac_sound
     (FIRST [ EAPPLY lem_plus_unit_c
            | delay (EAPPLY lem_plus_cancel ;;
                     ON_EACH [ SOLVE SOLVER | IDTAC ]) ]).
  Proof.
    intros. rtac_derive_soundness_default.
  Qed.

  Lemma iter_right_sound : forall Q, rtac_sound (iter_right Q).
  Proof.
    eapply expr_strong_ind; eauto using body_non_c.
    intros.
    simpl. destruct a; eauto using body_non_c.
    rtac_derive_soundness_default.
    - eapply H. eapply TransitiveClosure.LTStep; eauto.
      eapply acc_App_r.
      eapply TransitiveClosure.LTFin; eauto.
      eapply acc_App_l.
    - eapply H.
      eapply TransitiveClosure.LTFin; eauto.
      eapply acc_App_r.
  Qed.

  Section afterwards.
    Variable k : rtac typ (expr typ func).
    Fixpoint iter_left (P : expr typ func) : rtac typ (expr typ func) :=
      FIRST [ EAPPLY lem_plus_unit_p
            | delay match P with
                    | App (App _ L) R => (* guess star *)
                      FIRST [ EAPPLY lem_plus_assoc_p1 ;; delay (ON_ALL (iter_left L))
                            | EAPPLY lem_plus_assoc_p2 ;; delay (ON_ALL (iter_left R))
                            | k
                            ]
                     | _ => k
                   end ].
    Hypothesis k_sound : rtac_sound k.
    Lemma body_non_p : rtac_sound (FIRST [ EAPPLY lem_plus_unit_p | delay k ]).
    Proof. rtac_derive_soundness_default. Qed.

    Lemma iter_left_sound : forall Q, rtac_sound (iter_left Q).
    Proof.
      eapply expr_strong_ind; eauto using body_non_p.
      simpl. destruct a; eauto using body_non_p.
      intros.
      rtac_derive_soundness_default; eapply H.
      - eapply TransitiveClosure.LTStep; eauto.
        eapply acc_App_r.
        eapply TransitiveClosure.LTFin; eauto.
        eapply acc_App_l.
      - eapply TransitiveClosure.LTFin; eauto.
        eapply acc_App_r.
    Qed.
  End afterwards.

  Definition cancel' (P Q : expr typ func) : rtac typ (expr typ func) :=
    let k :=
        match Q with
          | App (App _ A) B =>
            FIRST [ EAPPLY lem_plus_comm_c ;; delay (ON_ALL (iter_right B))
                  | iter_right A
                  ]
          | _ => FAIL
        end
    in
    match P with
      | App (App _ A) B =>
        FIRST [ iter_left k A
              | (* TODO(gmalecha): What is the purpose of this line? *)
                FAIL ;; ON_ALL (THEN (EAPPLY lem_plus_comm_p) (delay (ON_ALL (iter_left k B))))
              ]
      | _ => FAIL
    end.

  Lemma cancel'_sound : forall P Q, rtac_sound (cancel' P Q).
  Proof.
    cbv beta delta [ cancel' ].
    intros.
    match goal with
      | |- rtac_sound (let x := ?X in _) =>
        assert (rtac_sound X); [ | generalize dependent X ]
    end; simpl; intros;
    rtac_derive_soundness_default; eauto using iter_right_sound, iter_left_sound.
  Qed.

  Fixpoint size (e : expr typ func) : nat :=
    match e with
      | App (App _ x) y => size x + size y
      | _ => 1
    end.

  Definition cancel : rtac typ (expr typ func) :=
    AT_GOAL (fun _ _ e =>
               REPEAT (size e)
                      (FIRST [ SOLVER
                             | AT_GOAL (fun _ _ e =>
                                          match e with
                                          | App (App _ L) R =>
                                            FIRST [ cancel' L R ;;
                                                    ON_ALL (TRY SOLVER) ]
                                          | _ => FAIL
                                          end) ;; MINIFY
                             ])).

  Theorem cancel_sound : rtac_sound cancel.
  Proof.
    unfold cancel.
    rtac_derive_soundness_default; eauto using cancel'_sound with typeclass_instances.
  Qed.

End canceller.

(*
Fixpoint build_plusL n : expr typ func :=
  match n with
    | 0 => Inj (N 1)
    | S n' => App (App (Inj Plus) (Inj (N (S n)))) (build_plusL n')
  end.

Fixpoint build_plusR n : expr typ func :=
  match n with
    | 0 => Inj (N 1)
    | S n' => App (App (Inj Plus) (build_plusR n')) (Inj (N (S n)))
  end.

Definition goal n := App (App (Inj (Eq tyNat)) (build_plusL n)) (build_plusR n).

Time Eval vm_compute in @runRtac _ _ nil nil (goal 200) automation.

Eval vm_compute in goal 1.
Goal True.

vm_compute in r.
*)

(**
Definition lem_plus_unit_c : Lemma.lemma typ (expr typ func) (expr typ func) :=
{|
vars := T :: T :: nil;
premises := App (App (Inj (Eq T)) (ExprCore.Var 1)) (ExprCore.Var 0) :: nil;
concl := App (App R (ExprCore.Var 1))  (App (App P U) (ExprCore.Var 0)) |}.
reify_simple_lemma plus_unit_c.
Show Proof. Defined.
Definition lem_plus_assoc_c1 : Lemma.lemma typ (expr typ func) (expr typ func).
reify_simple_lemma plus_assoc_c1.
Defined.
Definition lem_plus_assoc_c2 : Lemma.lemma typ (expr typ func) (expr typ func).
reify_simple_lemma plus_assoc_c2.
Defined.
Definition lem_plus_comm_c : Lemma.lemma typ (expr typ func) (expr typ func).
reify_simple_lemma plus_comm_c.
Defined.
Definition lem_plus_cancel : Lemma.lemma typ (expr typ func) (expr typ func).
reify_simple_lemma plus_cancel.
Defined.

Definition lem_plus_unit_p : Lemma.lemma typ (expr typ func) (expr typ func).
reify_simple_lemma plus_unit_p.

Defined.
Definition lem_plus_assoc_p1 : Lemma.lemma typ (expr typ func) (expr typ func).
reify_simple_lemma plus_assoc_p1.
Defined.
Definition lem_plus_assoc_p2 : Lemma.lemma typ (expr typ func) (expr typ func).
reify_simple_lemma plus_assoc_p2.
Defined.
Definition lem_plus_comm_p : Lemma.lemma typ (expr typ func) (expr typ func).
reify_simple_lemma plus_comm_p.
Defined.
Definition lem_refl : Lemma.lemma typ (expr typ func) (expr typ func).
reify_simple_lemma refl.
Defined.
**)