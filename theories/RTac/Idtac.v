Require Import ExtLib.Data.Sum.
Require Import ExtLib.Tactics.
Require Import MirrorCore.RTac.Core.

Require Import MirrorCore.Util.Forwardy.

Set Implicit Arguments.
Set Strict Implicit.

Section parameterized.
  Context {typ : Type}.
  Context {expr : Type}.
  Context {RType_typ : RType typ}.
  Context {RTypeOk_typ : RTypeOk}.
  Context {Typ0_Prop : Typ0 _ Prop}.
  Context {Expr_expr : Expr typ expr}.
  Context {ExprUVar_expr : ExprUVar expr}.


  Definition IDTAC : rtac typ expr :=
    fun _ _ _ _ ctx sub gl => More_ sub (GGoal gl).

  Theorem IDTAC_sound : rtac_sound IDTAC.
  Proof.
    unfold IDTAC, rtac_sound.
    intros; subst.
    eapply rtac_spec_More_; eauto.
  Qed.

End parameterized.

Arguments IDTAC {typ expr} _ _ _ _ {_} _ _.