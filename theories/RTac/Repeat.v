Require Import Coq.Lists.List.
Require Import ExtLib.Core.RelDec.
Require Import ExtLib.Structures.Monad.
Require Import ExtLib.Structures.Traversable.
Require Import ExtLib.Data.List.
Require Import ExtLib.Data.Monads.OptionMonad.
Require Import ExtLib.Tactics.
Require Import MirrorCore.SymI.
Require Import MirrorCore.ExprDAs.
Require Import MirrorCore.RTac.Core.
Require Import MirrorCore.RTac.Try.
Require Import MirrorCore.RTac.Idtac.
Require Import MirrorCore.RTac.Then.

Require Import MirrorCore.Util.Forwardy.

Set Implicit Arguments.
Set Strict Implicit.

Section parameterized.
  Variable typ : Type.
  Variable expr : Type.
  Variable subst : Type.

  Context {RType_typ : RType typ}.
  Context {Expr_expr : Expr RType_typ expr}.
  Context {Typ0_Prop : Typ0 _ Prop}.
  Context {Subst_subst : Subst subst expr}.
  Context {SubstOk_subst : @SubstOk _ _ _ _ Expr_expr Subst_subst}.
  Context {SubstUpdate_subst : SubstUpdate subst expr}.

  (** TODO: Write this with a positive **)
  Section repeater.
    (** TODO: To be efficient, this must be written in CPS
     **)
    Variable tac : rtac typ expr subst.

    Fixpoint REPEAT' (n : nat) {struct n}
    : rtac typ expr subst :=
      fun ctx sub gl =>
        match n with
          | 0 => More_ sub gl
          | S n =>
            match tac ctx sub gl with
              | Fail => More_ sub gl
              | More_ sub' gl' =>
                (REPEAT' n) ctx sub' gl'
              | Solved s => Solved s
            end
        end.
  End repeater.

  Definition REPEAT n (tac : rtac typ expr subst)
  : rtac typ expr subst :=
    REPEAT' tac n.

  Theorem REAPEAT_sound
  : forall tus tvs n tac, rtac_sound tus tvs tac ->
                          rtac_sound tus tvs (REPEAT n tac).
  Proof.
    unfold REPEAT. intros tus vs n tac H.
    induction n.
    - simpl. intros. clear.
      red; intros; subst.
      intro; split; auto.
      simpl.
      forward.
    - simpl. red; intros; subst.
      specialize (H ctx s g _ eq_refl).
      destruct (tac ctx s g); auto.
      + intros; split; auto.
        simpl. forward.
      + simpl in *.
        unfold rtac_sound in *.
        specialize (IHn ctx s0 g0 _ eq_refl).
        unfold rtac_spec in *.
        destruct (REPEAT' tac n ctx s0 g0); auto.
        * intros; forward_reason; split; auto.
          forward. firstorder.
        * intros; forward_reason; split; auto.
          forward. firstorder.
  Qed.

End parameterized.


(*
  Section repeater.
    (** TODO: To be efficient, this must be written in CPS
     **)
    Variable tac : rtac typ expr subst.

    Fixpoint REPEAT' (n : positive)
             (onDone : Result typ expr subst -> Result typ expr subst)
             (onContinue : Ctx typ expr -> subst -> Goal typ expr -> Result typ expr subst)
             {struct n}
    : Ctx typ expr -> subst -> expr -> Result typ expr subst :=
      fun ctx sub gl =>
        match n with
          | xH => tac ctx sub gl
          | xI n =>
            match tac ctx sub gl with
              | Fail => onDone (More sub (GGoal gl))
              | More sub' gl' =>
                runRTac (REPEAT' n onDone
                                 (fun ctx' sub' gl' =>
                                    runRTac (REPEAT' n onDone onContinue)
                                            ctx' sub' gl'))
                        ctx sub' gl'
              | Solved s => onDone (Solved s)
            end
          | xO n =>
            REPEAT' n onDone
                    (fun ctx' sub' gl' =>
                       runRTac (REPEAT' n onDone onContinue)
                               ctx' sub' gl')
           ctx sub gl
        end.
  End repeater.
*)