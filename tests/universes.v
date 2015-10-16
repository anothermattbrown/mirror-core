Require Import MirrorCore.CtxLogic.
Require Import MirrorCore.OpenT.
Require Import MirrorCore.Generic.
Require Import MirrorCore.TypesI.
Require Import MirrorCore.EnvI.
Require Import MirrorCore.ExprI.
Require Import MirrorCore.SubstituteI.
Require Import MirrorCore.VariablesI.
Require Import MirrorCore.AbsAppI.
Require Import MirrorCore.UnifyI.
Require Import MirrorCore.ExprProp.
Require Import MirrorCore.ExprSem.
Require Import MirrorCore.ExprDAs.
Require Import MirrorCore.SymI.
Require Import MirrorCore.SubstI.
Require Import MirrorCore.ProverI.
Require Import MirrorCore.EProverI.
Require Import MirrorCore.Instantiate.
Require Import MirrorCore.VarsToUVars.
Require Import MirrorCore.Lemma.
Require Import MirrorCore.LemmaApply.
Require Import MirrorCore.provers.ProverTac.
Require Import MirrorCore.provers.AssumptionProver.
Require Import MirrorCore.provers.DefaultProver.
Require Import MirrorCore.provers.AutoProver.
Require Import MirrorCore.Subst.UVarMap.
Require Import MirrorCore.Subst.FMapSubst.

Require Import MirrorCore.Util.Approx.
Require Import MirrorCore.Util.Iteration.
Require Import MirrorCore.Util.ListMapT.
Require Import MirrorCore.Util.Forwardy.
Require Import MirrorCore.Util.Quant.
Require Import MirrorCore.Util.Nat.
Require Import MirrorCore.Util.HListBuild.
Require Import MirrorCore.Util.Compat.

Require Import MirrorCore.syms.SymEnv.
Require Import MirrorCore.syms.SymPolyEnv.
Require Import MirrorCore.syms.SymSum.
Require Import MirrorCore.syms.SymOneOf.

Require Import MirrorCore.Lambda.ExprCore.
Require Import MirrorCore.Lambda.ExprDI.
Require Import MirrorCore.Lambda.ExprDsimul.
Require Import MirrorCore.Lambda.ExprD.
Require Import MirrorCore.Lambda.ExprDFacts.
Require Import MirrorCore.Lambda.ExprTac.
Require Import MirrorCore.Lambda.Expr.
Require Import MirrorCore.Lambda.ExprLift.
Require Import MirrorCore.Lambda.Red.
Require Import MirrorCore.Lambda.RedAll.
Require Import MirrorCore.Lambda.TypedFoldEager.
Require Import MirrorCore.Lambda.TypedFoldLazy.
Require Import MirrorCore.Lambda.TypedFoldApp.
Require Import MirrorCore.Lambda.FoldApp.
Require Import MirrorCore.Lambda.StrongFoldApp.
Require Import MirrorCore.Lambda.WtExpr.
Require Import MirrorCore.Lambda.Lemma.
Require Import MirrorCore.Lambda.ExprUnify_common.
Require Import MirrorCore.Lambda.ExprUnify_simple.
Require Import MirrorCore.Lambda.ExprUnify_simul.
Require Import MirrorCore.Lambda.ExprUnify.
Require Import MirrorCore.Lambda.ExprSubst.
Require Import MirrorCore.Lambda.ExprSubstitute.
Require Import MirrorCore.Lambda.AppN.
Require Import MirrorCore.Lambda.ExprVariables.
Require Import MirrorCore.Lambda.AutoSetoidRewrite.
Require Import MirrorCore.Lambda.AutoSetoidRewriteRtac.
Require Import MirrorCore.Lambda.RewriteRelations.
Require Import MirrorCore.Lambda.Ptrns.

Require Import MirrorCore.Views.Ptrns.
Require Import MirrorCore.Views.FuncView.
Require Import MirrorCore.Views.ViewSumN.
Require Import MirrorCore.Views.ListView.
Require Import MirrorCore.Views.NatView.
Require Import MirrorCore.Views.StringView.
Require Import MirrorCore.Views.BoolView.
Require Import MirrorCore.Views.ProdView.
Require Import MirrorCore.Views.ApplicativeView.
Require Import MirrorCore.Views.EqView.


Require Import MirrorCore.RTac.BIMap.
Require Import MirrorCore.RTac.Ctx.
Require Import MirrorCore.RTac.Core.
Require Import MirrorCore.RTac.CoreK.
Require Import MirrorCore.RTac.IsSolved.
Require Import MirrorCore.RTac.SpecLemmas.
Require Import MirrorCore.RTac.RunOnGoals.
Require Import MirrorCore.RTac.RunOnGoals_list.
Require Import MirrorCore.RTac.Then.
Require Import MirrorCore.RTac.Try.
Require Import MirrorCore.RTac.Repeat.
Require Import MirrorCore.RTac.Rec.
Require Import MirrorCore.RTac.Idtac.
Require Import MirrorCore.RTac.First.
Require Import MirrorCore.RTac.Fail.
Require Import MirrorCore.RTac.Solve.
Require Import MirrorCore.RTac.ThenK.
Require Import MirrorCore.RTac.IdtacK.
Require Import MirrorCore.RTac.runTacK.
Require Import MirrorCore.RTac.Assumption.
Require Import MirrorCore.RTac.Intro.
Require Import MirrorCore.RTac.Apply.
Require Import MirrorCore.RTac.EApply.
Require Import MirrorCore.RTac.Simplify.
Require Import MirrorCore.RTac.Instantiate.
Require Import MirrorCore.RTac.Minify.
Require Import MirrorCore.RTac.AtGoal.
Require Import MirrorCore.RTac.Reduce.
Require Import MirrorCore.RTac.Interface.
Require Import MirrorCore.RTac.RTac.
Require Import MirrorCore.RTac.InContext.

Require Import MirrorCore.Reify.Patterns.
Require Import MirrorCore.Reify.Reify.
