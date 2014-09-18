Require Import ExtLib.Tactics.
Require Import MirrorCore.EnvI.
Require Import MirrorCore.ExprI.
Require Import MirrorCore.TypesI.
Require Import MirrorCore.SubstI.
Require Import MirrorCore.RTac.Core.

Require Import MirrorCore.Util.Forwardy.

Set Implicit Arguments.
Set Strict Implicit.

Section parameterized.
  Context {typ : Type}.
  Context {expr : Type}.
  Context {subst : Type}.
  Context {RType_typ : RType typ}.
  Context {Expr_expr : Expr RType_typ expr}.
  Context {Typ0_Prop : Typ0 _ Prop}.
  Context {Subst_subst : Subst subst expr}.
  Context {SubstOk_subst : @SubstOk _ _ _ _ Expr_expr Subst_subst}.

  Definition SOLVE (tac : rtac typ expr subst) : rtac typ expr subst :=
    fun ctx s g => match tac ctx s g with
                     | Solved s => Solved s
                     | _ => Fail
                   end.

  Theorem SOLVE_sound
  : forall tus tvs tac, rtac_sound tus tvs tac -> rtac_sound tus tvs (SOLVE tac).
  Proof.
    unfold SOLVE, rtac_sound.
    intros.
    admit.
  Qed.

End parameterized.