import Mathlib.Data.Fin.Basic
import Mathlib.Data.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Tactic

open Classical
open Finset

namespace BICF

/-- Points of Fano plane -/
abbrev Point7 := Fin 7

/-- Lines of Fano plane -/
abbrev Line7 := Fin 7

/-- Points of 1..14 lottery (modeled as 0..13) -/
abbrev Point14 := Fin 14

/-
  ============================================================
  Part A. Two-half embeddings (helpers)
  ============================================================
-/

def inFirstHalf (x : Point14) : Bool := x.val < 7

/-- Embed Point7 into first half of Point14 -/
def fromPoint7_first (p : Point7) : Point14 :=
  ⟨p.val, Nat.lt_trans p.isLt (by decide : (7 : Nat) < 14)⟩

/-- Embed Point7 into second half of Point14 by adding 7 -/
def fromPoint7_second (p : Point7) : Point14 :=
  ⟨p.val + 7, by
    have hp : p.val < 7 := p.isLt
    exact Nat.add_lt_add_right hp 7⟩

/-- Convert a Point14 known to be in first half into Point7. -/
def toPoint7_first (x : Point14) (hx : x.val < 7) : Point7 :=
  ⟨x.val, hx⟩

/-- Convert a Point14 known to be in second half into Point7 by subtracting 7. -/
def toPoint7_second (x : Point14) (hx : ¬ x.val < 7) : Point7 :=
  ⟨x.val - 7, by
    have hxge : 7 ≤ x.val := Nat.le_of_not_gt hx
    have hxlt : x.val < 14 := x.isLt
    have : x.val - 7 < 7 := by
      have : x.val < 7 + 7 := by simpa [Nat.add_assoc] using hxlt
      exact Nat.sub_lt_left_of_lt_add hxge this
    simpa using this⟩

/-- Helper: first-half roundtrip is identity. -/
theorem first_roundtrip (x : Point14) (hx : x.val < 7) :
    fromPoint7_first (toPoint7_first x hx) = x := by
  apply Fin.ext
  rfl

/-- Helper: second-half roundtrip is identity. -/
theorem second_roundtrip (x : Point14) (hx : ¬ x.val < 7) :
    fromPoint7_second (toPoint7_second x hx) = x := by
  apply Fin.ext
  have hxge : 7 ≤ x.val := Nat.le_of_not_gt hx
  -- (x.val - 7) + 7 = x.val
  simp [fromPoint7_second, toPoint7_second, Nat.sub_add_cancel hxge]

/-
  ============================================================
  Part B. Explicit Fano incidence table
  ============================================================

  Standard Fano plane lines (on points 0..6):
    L0 = {0,1,3}
    L1 = {0,2,6}
    L2 = {0,4,5}
    L3 = {1,2,4}
    L4 = {1,5,6}
    L5 = {2,3,5}
    L6 = {3,4,6}
-/

/-- Shorthand: make a Point7 from a Nat literal (assumes < 7). -/
def p7 (n : Nat) (h : n < 7 := by decide) : Point7 := ⟨n, h⟩

/-- The explicit points-on-line table. -/
def fanoLinePoints : Line7 → Finset Point7
| ⟨0, _⟩ => { p7 0, p7 1, p7 3 }
| ⟨1, _⟩ => { p7 0, p7 2, p7 6 }
| ⟨2, _⟩ => { p7 0, p7 4, p7 5 }
| ⟨3, _⟩ => { p7 1, p7 2, p7 4 }
| ⟨4, _⟩ => { p7 1, p7 5, p7 6 }
| ⟨5, _⟩ => { p7 2, p7 3, p7 5 }
| ⟨6, _⟩ => { p7 3, p7 4, p7 6 }

/-- Incidence predicate: point p is incident to line ℓ iff p is in that line's point set. -/
def FanoI (p : Point7) (ℓ : Line7) : Prop :=
  p ∈ fanoLinePoints ℓ

/-
  ============================================================
  Part C. FanoPlane structure + proofs by finite decision
  ============================================================
-/

structure FanoPlane where
  I : Point7 → Line7 → Prop
  line_through_unique :
    ∀ {p q : Point7}, p ≠ q → ∃! ℓ : Line7, I p ℓ ∧ I q ℓ
  line_card_three :
    ∀ ℓ : Line7, ((Finset.univ.filter (fun p => I p ℓ)).card = 3)

namespace ExplicitFano

/-- The explicit Fano plane boundary object. -/
def Fano : FanoPlane :=
{ I := FanoI
, line_through_unique := by
    -- This is a finite, decidable statement over Fin 7.
    -- `native_decide` brute-forces it.
    intro p q hpq
    native_decide
, line_card_three := by
    intro ℓ
    -- Also finite decidable; brute-force it.
    native_decide
}

/-- Convenience lemma: membership in points-on-line is incidence. -/
lemma mem_pointsOnLine (p : Point7) (ℓ : Line7) :
    FanoI p ℓ ↔ p ∈ fanoLinePoints ℓ := by
  rfl

/-- Each explicit line has exactly 3 points (directly). -/
lemma fanoLinePoints_card (ℓ : Line7) :
    (fanoLinePoints ℓ).card = 3 := by
  native_decide

end ExplicitFano


/-
  ============================================================
  Part D. Tickets and PCG theorem (cleaned with helpers)
  ============================================================
-/

namespace Tickets

open ExplicitFano

def ticket_first (ℓ : Line7) : Finset Point14 :=
  (fanoLinePoints ℓ).image fromPoint7_first

def ticket_second (ℓ : Line7) : Finset Point14 :=
  (fanoLinePoints ℓ).image fromPoint7_second

lemma ticket_first_card (ℓ : Line7) : (ticket_first ℓ).card = 3 := by
  have hinj : Function.Injective fromPoint7_first := by
    intro a b h; apply Fin.ext
    simpa [fromPoint7_first] using congrArg Fin.val h
  -- card(image) = card(source) for injective
  simpa [ticket_first, ExplicitFano.fanoLinePoints_card] using
    Finset.card_image_of_injective (s := fanoLinePoints ℓ) hinj

lemma ticket_second_card (ℓ : Line7) : (ticket_second ℓ).card = 3 := by
  have hinj : Function.Injective fromPoint7_second := by
    intro a b h; apply Fin.ext
    have := congrArg Fin.val h
    exact Nat.add_left_cancel this
  simpa [ticket_second, ExplicitFano.fanoLinePoints_card] using
    Finset.card_image_of_injective (s := fanoLinePoints ℓ) hinj

end Tickets


namespace PCG

open Tickets ExplicitFano

/-- "matches two numbers" predicate for a 3-element ticket -/
def matchesTwo (t : Finset Point14) (a b c : Point14) : Prop :=
  (a ∈ t ∧ b ∈ t) ∨ (a ∈ t ∧ c ∈ t) ∨ (b ∈ t ∧ c ∈ t)

/-- Pigeonhole on two halves: among three booleans, some pair agrees. -/
lemma two_in_same_half (a b c : Point14) :
    (inFirstHalf a = inFirstHalf b) ∨
    (inFirstHalf a = inFirstHalf c) ∨
    (inFirstHalf b = inFirstHalf c) := by
  by_cases ha : inFirstHalf a = true <;>
  by_cases hb : inFirstHalf b = true <;>
  by_cases hc : inFirstHalf c = true <;>
  simp [inFirstHalf] at ha hb hc <;>
  simp [inFirstHalf, ha, hb, hc]

/-
  PCG Theorem (Explicit):

  Using the 14 tickets = 7 lines in first Fano plane + 7 lines in second,
  any triple (a,b,c) has at least one ticket matching ≥2 numbers.

  Proof idea:
  - pick pair that lies in the same half
  - map that half down to Point7
  - use uniqueness of line through pair (in explicit Fano plane)
  - corresponding line-ticket contains both numbers
-/
theorem pcg_two_fano_explicit
    (a b c : Point14)
    (hab : a ≠ b) (hac : a ≠ c) (hbc : b ≠ c) :
    ∃ t : Finset Point14, t.card = 3 ∧ matchesTwo t a b c := by
  have hpair := two_in_same_half a b c
  rcases hpair with habHalf | hacHalf | hbcHalf

  · -- a,b same half
    by_cases ha0 : a.val < 7
    · -- first half case
      have hb0 : b.val < 7 := by
        have : inFirstHalf a = inFirstHalf b := habHalf
        have haT : inFirstHalf a = true := by simp [inFirstHalf, ha0]
        have hbT : inFirstHalf b = true := by simpa [this] using haT
        simpa [inFirstHalf] using hbT

      let pa : Point7 := toPoint7_first a ha0
      let pb : Point7 := toPoint7_first b hb0
      have hpab : pa ≠ pb := by
        intro h; apply hab; apply Fin.ext
        simpa [pa, pb, toPoint7_first] using congrArg Fin.val h

      -- unique line through pa,pb (explicit Fano plane instance)
      have hu := (ExplicitFano.Fano.line_through_unique (p := pa) (q := pb) hpab)
      rcases hu with ⟨ℓ, hℓ, huniq⟩

      let t := ticket_first ℓ
      refine ⟨t, ticket_first_card ℓ, ?_⟩

      have ha_mem : a ∈ t := by
        have : pa ∈ fanoLinePoints ℓ := (hℓ.1)
        have : fromPoint7_first pa ∈ (fanoLinePoints ℓ).image fromPoint7_first :=
          mem_image_of_mem fromPoint7_first this
        -- rewrite fromPoint7_first(pa) = a
        simpa [t, pa, first_roundtrip a ha0] using this

      have hb_mem : b ∈ t := by
        have : pb ∈ fanoLinePoints ℓ := (hℓ.2)
        have : fromPoint7_first pb ∈ (fanoLinePoints ℓ).image fromPoint7_first :=
          mem_image_of_mem fromPoint7_first this
        simpa [t, pb, first_roundtrip b hb0] using this

      exact Or.inl ⟨ha_mem, hb_mem⟩

    · -- second half case
      have hb0 : ¬ b.val < 7 := by
        have : inFirstHalf a = inFirstHalf b := habHalf
        have haF : inFirstHalf a = false := by simp [inFirstHalf, ha0]
        have hbF : inFirstHalf b = false := by simpa [this] using haF
        simpa [inFirstHalf] using hbF

      let pa : Point7 := toPoint7_second a ha0
      let pb : Point7 := toPoint7_second b hb0
      have hpab : pa ≠ pb := by
        intro h; apply hab; apply Fin.ext
        -- use second-roundtrip equality indirectly (cleaner than arithmetic)
        -- if pa=pb then embedding back gives a=b
        have : fromPoint7_second pa = fromPoint7_second pb := congrArg fromPoint7_second h
        simpa [pa, pb, second_roundtrip a ha0, second_roundtrip b hb0] using this

      have hu := (ExplicitFano.Fano.line_through_unique (p := pa) (q := pb) hpab)
      rcases hu with ⟨ℓ, hℓ, huniq⟩

      let t := ticket_second ℓ
      refine ⟨t, ticket_second_card ℓ, ?_⟩

      have ha_mem : a ∈ t := by
        have : pa ∈ fanoLinePoints ℓ := (hℓ.1)
        have : fromPoint7_second pa ∈ (fanoLinePoints ℓ).image fromPoint7_second :=
          mem_image_of_mem fromPoint7_second this
        simpa [t, pa, second_roundtrip a ha0] using this

      have hb_mem : b ∈ t := by
        have : pb ∈ fanoLinePoints ℓ := (hℓ.2)
        have : fromPoint7_second pb ∈ (fanoLinePoints ℓ).image fromPoint7_second :=
          mem_image_of_mem fromPoint7_second this
        simpa [t, pb, second_roundtrip b hb0] using this

      exact Or.inl ⟨ha_mem, hb_mem⟩

  · -- a,c same half: reuse by symmetry (paper can factor into lemma)
    have : ∃ t, t.card = 3 ∧ matchesTwo t a c b := by
      exact pcg_two_fano_explicit a c b hac hab.symm hbc.symm
    rcases this with ⟨t, ht3, hm⟩
    refine ⟨t, ht3, ?_⟩
    rcases hm with h1 | h2 | h3
    · exact Or.inr (Or.inl h1)
    · exact Or.inl h2
    · exact Or.inr (Or.inr (And.comm.mp h3))

  · -- b,c same half: symmetry again
    have : ∃ t, t.card = 3 ∧ matchesTwo t b c a := by
      exact pcg_two_fano_explicit b c a hbc hab.symm hac.symm
    rcases this with ⟨t, ht3, hm⟩
    refine ⟨t, ht3, ?_⟩
    rcases hm with h1 | h2 | h3
    · exact Or.inr (Or.inr h1)
    · exact Or.inl (And.comm.mp h2)
    · exact Or.inr (Or.inl (And.comm.mp h3))

end PCG

end BICF