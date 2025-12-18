import Mathlib.Data.Nat.Choose.Bounds
import Mathlib.Data.Nat.Choose.Sum

/-!
# Complexity bounds (Pascal diagonals)

This module formalizes the “Pascal diagonal / arity principle” used in the docs:

- The full set of subsets (unconstrained enumeration) grows as `2^n`.
- A fixed-arity diagonal `n.choose k` is polynomially bounded in `n` for fixed `k`.

In the architecture, this corresponds to enforcing a fixed interaction arity at interfaces
(e.g. `k = 2` or `k = 3`) instead of enumerating arbitrary subsets.
-/

namespace BicfProduction
namespace Complexity

open Finset Nat

-- “Diagonal is polynomial”: for fixed k, choose is bounded by a k-th power.
theorem choose_le_pow (n k : ℕ) : n.choose k ≤ n ^ k :=
  Nat.choose_le_pow n k

-- “Whole row is exponential in aggregate”: sum of a Pascal row is 2^n.
theorem sum_range_choose (n : ℕ) : (∑ m ∈ range (n + 1), n.choose m) = 2 ^ n :=
  Nat.sum_range_choose n

end Complexity
end BicfProduction

