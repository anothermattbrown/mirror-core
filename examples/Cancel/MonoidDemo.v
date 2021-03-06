(* This is a demo of developing a cancellation algorithm for
 * commutative monoids.
 *)
Require Import MirrorCore.ExprI.
Require Import MirrorCore.TypesI.
Require Import MirrorCore.SymI.
Require MirrorCore.syms.SymEnv.
Require MirrorCore.syms.SymSum.
Require Import MirrorCore.RTac.RTac.
Require Import MirrorCore.Lambda.Expr.
Require Import MirrorCore.Lambda.Rtac.
Require Import MirrorCore.Reify.Reify.

Require Import McExamples.Cancel.Monoid.
Require McExamples.Cancel.MonoidSyntaxSimple.
Require McExamples.Cancel.MonoidSyntaxNoDec.
Require McExamples.Cancel.MonoidSyntaxWithConst.
Require McExamples.Cancel.MonoidSyntaxModular.

Set Implicit Arguments.
Set Strict Implicit.

Module MonoidCancel (M : Monoid).

  (* Import the syntactic language *)
  Module Syntax := MonoidSyntaxModular.Syntax M.
  Import Syntax.

  (* The Core Monoid Lemmas *)
  Reify BuildLemma < reify_monoid_typ reify_monoid reify_monoid >
     lem_plus_unit_c : M.plus_unit_c.
  Reify BuildLemma < reify_monoid_typ reify_monoid reify_monoid >
     lem_plus_assoc_c1 : M.plus_assoc_c1.
  Reify BuildLemma < reify_monoid_typ reify_monoid reify_monoid >
     lem_plus_assoc_c2 : M.plus_assoc_c2.
  Reify BuildLemma < reify_monoid_typ reify_monoid reify_monoid >
     lem_plus_comm_c : M.plus_comm_c.
  Reify BuildLemma < reify_monoid_typ reify_monoid reify_monoid >
     lem_plus_cancel : M.plus_cancel.
  Reify BuildLemma < reify_monoid_typ reify_monoid reify_monoid >
     lem_plus_unit_p : M.plus_unit_p.
  Reify BuildLemma < reify_monoid_typ reify_monoid reify_monoid >
     lem_plus_assoc_p1 : M.plus_assoc_p1.
  Reify BuildLemma < reify_monoid_typ reify_monoid reify_monoid >
     lem_plus_assoc_p2 : M.plus_assoc_p2.
  Reify BuildLemma < reify_monoid_typ reify_monoid reify_monoid >
     lem_plus_comm_p : M.plus_comm_p.

  Reify BuildLemma < reify_monoid_typ reify_monoid reify_monoid >
      lem_refl : M.refl.

  (* Write the automation *)
  Section with_solver.
    Variable fs : @SymEnv.functions typ _.
    Let RSym_func := RSym_func fs.
    Local Existing Instance RSym_func.
    Let Expr_expr := @Expr.Expr_expr typ func RType_typ _ _.
    Local Existing Instance Expr_expr.

    Let ExprOk_expr : ExprOk Expr_expr :=
      @ExprOk_expr typ func _ _ _ _ Typ2Ok_tyArr _.
    Local Existing Instance ExprOk_expr.

    Instance RL_lem_plus_unit_c : ReifiedLemma lem_plus_unit_c :=
    { ReifiedLemma_proof := M.plus_unit_c }.
    Instance RL_lem_plus_assoc_c1 : ReifiedLemma lem_plus_assoc_c1 :=
    { ReifiedLemma_proof := M.plus_assoc_c1 }.
    Instance RL_lem_plus_assoc_c2 : ReifiedLemma lem_plus_assoc_c2 :=
    { ReifiedLemma_proof := M.plus_assoc_c2 }.
    Instance RL_lem_plus_comm_c : ReifiedLemma lem_plus_comm_c :=
    { ReifiedLemma_proof := M.plus_comm_c }.
    Instance RL_lem_plus_cancel : ReifiedLemma lem_plus_cancel :=
    { ReifiedLemma_proof := M.plus_cancel }.
    Instance RL_lem_plus_unit_p : ReifiedLemma lem_plus_unit_p :=
    { ReifiedLemma_proof := M.plus_unit_p }.
    Instance RL_lem_plus_assoc_p1 : ReifiedLemma lem_plus_assoc_p1 :=
    { ReifiedLemma_proof := M.plus_assoc_p1 }.
    Instance RL_lem_plus_assoc_p2 : ReifiedLemma lem_plus_assoc_p2 :=
    { ReifiedLemma_proof := M.plus_assoc_p2 }.
    Instance RL_lem_plus_comm_p : ReifiedLemma lem_plus_comm_p :=
    { ReifiedLemma_proof := M.plus_comm_p }.
    Instance RL_lem_refl : ReifiedLemma lem_refl :=
    { ReifiedLemma_proof := M.refl }.

    Variable solver : rtac typ (expr typ func).
    Hypothesis solver_ok : RtacSound solver.

    Definition iter_right (n : nat) : rtac typ (expr typ func) :=
      REC n (fun rec =>
               FIRST [ EAPPLY lem_plus_unit_c
                     | EAPPLY lem_plus_assoc_c1 ;; ON_ALL rec
                     | EAPPLY lem_plus_assoc_c2 ;; ON_ALL rec
                     | EAPPLY lem_plus_cancel ;;
                              ON_EACH [ SOLVE solver | IDTAC ]
            ])
          IDTAC.

    Instance iter_right_sound {Q} : RtacSound (iter_right Q).
    Proof.
      unfold iter_right; rtac_derive_soundness_default.
    Qed.

    Section afterwards.
      Variable k : rtac typ (expr typ func).
      Definition iter_left (n : nat) : rtac typ (expr typ func) :=
        REC n (fun rec =>
                 FIRST [ EAPPLY lem_plus_unit_p
                       | EAPPLY lem_plus_assoc_p1 ;; ON_ALL rec
                       | EAPPLY lem_plus_assoc_p2 ;; ON_ALL rec
                       | k
              ])
            IDTAC.

      Hypothesis k_sound : RtacSound k.

      Lemma iter_left_sound : forall Q, RtacSound (iter_left Q).
      Proof. unfold iter_left; rtac_derive_soundness_default. Qed.
    End afterwards.
    Local Existing Instance iter_left_sound.

    Definition cancel' (n m : nat) : rtac typ (expr typ func) :=
      let k :=
          FIRST [ EAPPLY lem_plus_comm_c ;; ON_ALL (iter_right m)
                | iter_right m
                ]
      in
      FIRST [ iter_left k n
            | EAPPLY lem_plus_comm_p ;; ON_ALL (iter_left k n)
            ].

    Local Instance cancel'_sound : forall P Q, RtacSound (cancel' P Q).
    Proof.
      cbv beta delta [ cancel' ]; rtac_derive_soundness_default.
    Qed.

    Fixpoint size (e : expr typ func) : nat :=
      match e with
      | App (App _ x) y => size x + size y
      | _ => 1
      end.

    Definition cancel : rtac typ (expr typ func) :=
      AT_GOAL (fun _ _ e =>
                 let fuel := size e in
                 REPEAT fuel
                        (FIRST [ SOLVE solver
                               | (cancel' fuel fuel ;; ON_ALL (TRY solver)) ;; MINIFY
              ])).

    Theorem cancel_sound : RtacSound cancel.
    Proof.
      unfold cancel.
      rtac_derive_soundness_default; eauto with typeclass_instances.
    Qed.

  End with_solver.

  Local Existing Instance cancel_sound.
  Local Existing Instance RL_lem_refl.

  Definition the_Expr fs := (@Expr.Expr_expr typ func _ _ (RSym_func fs)).

  Definition the_tactic fs :=
    @cancel fs (EAPPLY (RSym_sym:=RSym_func fs) lem_refl).

  Theorem the_tactic_sound fs : rtac_sound (Expr_expr:=the_Expr fs) (the_tactic fs).
  Proof.
    unfold the_tactic.
    intros. eapply cancel_sound; eauto with typeclass_instances.
  Qed.

  Ltac rtac_canceler :=
    lazymatch goal with
    | |- ?trm =>
      let k tbl e :=
          let result := constr:(@Interface.runRtac typ (expr typ func) nil nil e (the_tactic tbl)) in
          let resultV := eval vm_compute in result in
          match resultV with
          | Solved _ =>
            change (@env_propD _ _ _ Typ0_tyProp (the_Expr tbl) nil nil e) ;
              cut (result = resultV) ;
              [ set (pf := @Interface.rtac_Solved_closed_soundness
                             _ _ _ _ _ _ (the_tactic_sound tbl)
                             nil nil e) ;
                exact pf
              | vm_cast_no_check (@eq_refl _ resultV) ]
          end
      in
      reify_expr_bind reify_monoid k
                      [[ (fun x : @mk_dvar_map _ _ _ typD table_terms (@SymEnv.F typ _) => True) ]]
                      [[ trm ]]
  end.

  Module Demo.
    Axiom N : nat -> M.M.

    Fixpoint build_plusL n : M.M :=
      match n with
      | 0 => N 0
      | S n' => M.P (N n) (build_plusL n')
      end.

    Fixpoint build_plusR n : M.M :=
      match n with
      | 0 => N 0
      | S n' => M.P (build_plusR n') (N n)
      end.

    Definition goal n := M.R (build_plusL n) (build_plusR n).

    Ltac prep := unfold goal, build_plusL, build_plusR.

    Theorem test1 : goal 120.
      prep.
      Time rtac_canceler.
    Time Qed.
    Print Assumptions test1.
  End Demo.

End MonoidCancel.
