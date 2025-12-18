import Lake
open Lake DSL

package «bicf-production» where
  -- Add package configuration options here

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git" @ "v4.26.0"

@[default_target]
lean_lib «BicfProduction» where
  -- Add library configuration options here
