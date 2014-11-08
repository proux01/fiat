(** * Definition of the finite set spec *)
Require Import Coq.Strings.String Coq.Sets.Ensembles Coq.Sets.Finite_sets Coq.Lists.List Coq.Sorting.Permutation.
Require Import ADTSynthesis.ADT ADTSynthesis.ADT.ComputationalADT ADTSynthesis.ADTRefinement.Core ADTSynthesis.ADTNotation ADTSynthesis.ADTRefinement.GeneralRefinements ADTSynthesis.Common.AdditionalEnsembleDefinitions.
Require Export Bedrock.Memory Bedrock.IL.

Set Implicit Arguments.

Local Open Scope string_scope.

(** TODO: Figure out where Facade words live, and use that *)
Module Type BedrockWordT.
  Axiom W : Type.
  Axiom wzero : W.
  Axiom wplus : W -> W -> W.
  Axiom weq : W -> W -> bool.
  Axiom wlt : W -> W -> bool.
  Axiom weq_iff : forall x y, x = y <-> weq x y = true.
  Axiom wlt_irrefl : forall x, wlt x x = false.
  Axiom wlt_trans : forall x y z, wlt x y = true -> wlt y z = true -> wlt x z = true.
  Axiom wle_antisym : forall x y, wlt x y = false -> wlt y x = false -> x = y.
  Axiom wle_asym : forall x y, wlt x y = true -> wlt y x = false.
End BedrockWordT.

Module Export BedrockWordW <: BedrockWordT.
  Definition W := Memory.W.

  Definition wzero := (@Word.natToWord 32 0).
  Definition wplus := (@Word.wplus 32).
  Definition weq := @Word.weqb 32.

  Definition wlt := IL.wltb.

  Lemma weq_iff x : forall y, x = y <-> weq x y = true.
  Proof.
    symmetry; apply Word.weqb_true_iff.
  Qed.

  Lemma wlt_irrefl x : wlt x x = false.
  Proof.
    unfold wlt, wltb.
    destruct (Word.wlt_dec x x).
    pose proof (Word.lt_le w); congruence.
    reflexivity.
  Qed.

  Lemma wlt_true_iff :
    forall x y,
      wlt x y = true <-> Word.wlt x y.
  Proof.
    intros.
    unfold wlt, IL.wltb.
    destruct (Word.wlt_dec x y); intuition.
  Qed.

  Lemma wlt_false_iff :
    forall x y,
      wlt x y = false <-> ~ Word.wlt x y.
  Proof.
    intros.
    unfold wlt, IL.wltb.
    destruct (Word.wlt_dec x y); intuition.
  Qed.

  Lemma wlt_trans x : forall y z, wlt x y = true -> wlt y z = true -> wlt x z = true.
  Proof.
    intros.
    rewrite wlt_true_iff in *.
    unfold Word.wlt in *.
    eapply BinNat.N.lt_trans; eauto.
  Qed.

  Lemma wle_antisym x : forall y, wlt x y = false -> wlt y x = false -> x = y.
  Proof.
    intros.
    rewrite wlt_false_iff in *.
    unfold Word.wlt in *.
    rewrite BinNat.N.nlt_ge in *.
    apply Word.wordToN_inj.
    apply BinNat.N.le_antisymm; intuition.
  Qed.

  Lemma wle_asym x : forall y, wlt x y = true -> wlt y x = false.
  Proof.
    intro y; rewrite wlt_true_iff, wlt_false_iff.
    unfold Word.wlt.
    apply BinNat.N.lt_asymm.
  Qed.
End BedrockWordW.

(** TODO: Test: Do we get a speedup if we replace these definitions
    with [{| bindex := "$STRING-HERE" |}]? *)
Definition sEmpty := "Empty".
Definition sAdd := "Add".
Definition sRemove := "Remove".
Definition sIn := "In".
Definition sSize := "Size".

(** We define the interface for finite sets *)
(** QUESTION: Does Facade give us any other methods?  Do we want to
    provide any other methods? *)
Definition FiniteSetSig : ADTSig :=
  ADTsignature {
      Constructor sEmpty : unit -> rep,
      Method sAdd : rep x W -> rep x unit,
      Method sRemove : rep x W -> rep x unit,
      Method sIn : rep x W -> rep x bool,
      Method sSize : rep x unit -> rep x nat
    }.

(** And now the spec *)
Definition FiniteSetSpec : ADT FiniteSetSig :=
  ADTRep (Ensemble W) {
    Def Constructor sEmpty (_ : unit) : rep := ret (Empty_set _),

    Def Method sAdd (xs : rep , x : W) : unit :=
      ret (Add _ xs x, tt),

    Def Method sRemove (xs : rep , x : W) : unit :=
      ret (Subtract _ xs x, tt),

    Def Method sIn (xs : rep , x : W) : bool :=
        (b <- { b : bool | b = true <-> Ensembles.In _ xs x };
         ret (xs, b)),

    Def Method sSize (xs : rep , _ : unit) : nat :=
          (n <- { n : nat | cardinal _ xs n };
           ret (xs, n))
  }.
