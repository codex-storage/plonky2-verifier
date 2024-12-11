
{-# LANGUAGE StrictData #-}
module Types where

--------------------------------------------------------------------------------

import Data.Word

import Goldilocks

--------------------------------------------------------------------------------

type KeccakHash  = [Word8]

type LookupTable = [(Word64,Word64)]

--------------------------------------------------------------------------------

data CommonCircuitData = MkCommonCircuitData
  { circuit_config                 :: CircuitConfig    -- ^ Global circuit configuration
  , circuit_fri_params             :: FriParams        -- ^ FRI parameters
  , circuit_gates                  :: [Gate]           -- ^ The types of gates used in this circuit, along with their prefixes.
  , circuit_selectors_info         :: SelectorsInfo    -- ^ Information on the circuit's selector polynomials.
  , circuit_quotient_degree_factor :: Int              -- ^ The degree of the PLONK quotient polynomial.
  , circuit_num_gate_constraints   :: Int              -- ^ The largest number of constraints imposed by any gate.
  , circuit_num_constants          :: Int              -- ^ The number of constant wires.
  , circuit_num_public_inputs      :: Int              -- ^ Number of public inputs
  , circuit_k_is                   :: [F]              -- ^ The @{k_i}@ values (coset shifts) used in @S_I D_i@ in Plonk's permutation argument.
  , circuit_num_partial_products   :: Int              -- ^ The number of partial products needed to compute the `Z` polynomials.
  , circuit_num_lookup_polys       :: Int              -- ^ The number of lookup polynomials.
  , circuit_num_lookup_selectors   :: Int              -- ^ The number of lookup selectors.
  , circuit_luts                   :: [LookupTable]    -- ^ The stored lookup tables.
  }
  deriving (Eq,Show)

data CircuitConfig = MkCircuitConfig
  { cfg_num_wires                  :: Int        -- ^ Number of wires available at each row. This corresponds to the "width" of the circuit, and consists in the sum of routed wires and advice wires.
  , cfg_num_routed_wires           :: Int        -- ^ The number of routed wires, i.e. wires that will be involved in Plonk's permutation argument.
  , cfg_num_constants              :: Int        -- ^ The number of constants that can be used per gate.
  , cfg_use_base_arithmetic_gate   :: Bool       -- ^ Whether to use a dedicated gate for base field arithmetic, rather than using a single gate for both base field and extension field arithmetic.
  , cfg_security_bits              :: Int        -- ^ Security level target
  , cfg_num_challenges             :: Int        -- ^ The number of challenge points to generate, for IOPs that have soundness errors of (roughly) `degree / |F|`.
  , cfg_zero_knowledge             :: Bool       -- ^ Option to activate the zero-knowledge property.
  , cfg_randomize_unused_wires     :: Bool       -- ^ Option to disable randomization (useful for debugging).
  , cfg_max_quotient_degree_factor :: Int        -- ^ A cap on the quotient polynomial's degree factor.
  , cfg_fri_config                 :: FriConfig
  }
  deriving (Eq,Show)

-- | The interval @[a,b)@ (inclusive on the left, exclusive on the right)
data Range 
  = MkRange Int Int
  deriving (Eq,Show)

data SelectorsInfo = MkSelectorsInfo
  { selector_indices :: [Int]
  , groups           :: [Range]
  , selector_vector  :: Maybe [Int]
  }
  deriving (Eq,Show)

data FriConfig = MkFrConfig 
  { fri_rate_bits          :: Int                      -- ^ @rate = 2^{-rate_bits}@
  , fri_cap_height         :: Int                      -- ^ Height of Merkle tree caps.
  , fri_proof_of_work_bits :: Int                      -- ^ Number of bits used for grinding.
  , fri_reduction_strategy :: FriReductionStrategy     -- ^ The reduction strategy to be applied at each layer during the commit phase.
  , fri_num_query_rounds   :: Int                      -- ^ Number of query rounds to perform.
  }
  deriving (Eq,Show)

data FriReductionStrategy 
  = Fixed             { arity_bits_seq :: [Int] }
  | ConstantArityBits { arity_bits :: Int , final_poly_bits :: Int }
  | MinSize           { opt_max_arity_bits :: Maybe Int }
  deriving (Eq,Show)

data FriParams = MkFriParams
  { fri_config               :: FriConfig   -- ^ User-specified FRI configuration.
  , fri_hiding               :: Bool        -- ^ Whether to use a hiding variant of Merkle trees (where random salts are added to leaves).
  , fri_degree_bits          :: Int         -- ^ The degree of the purported codeword, measured in bits.
  , fri_reduction_arity_bits :: [Int]       -- ^ The arity of each FRI reduction step, expressed as the log2 of the actual arity.
  }
  deriving (Eq,Show)

data Gate
  = ArithmeticGate          { num_ops    :: Int }
  | ArithmeticExtensionGate { num_ops    :: Int }
  | BasSumGate              { num_limbs  :: Int }
  | CosetInterpolationGate  { subgroup_bits :: Int, degree :: Int , barycentric_weights :: [F] }
  | ConstantGate            { num_consts :: Int }
  | ExponentiationGate      { num_power_bits :: Int }
  | LookupGate              { num_slots  :: Int, lut_hash :: KeccakHash }
  | LookupTableGate         { num_slots  :: Int, lut_hash :: KeccakHash, last_lut_row :: Int }
  | MulExtensionGate        { num_ops    :: Int }
  | NoopGate
  | PublicInputGate
  | PoseidonGate            { hash_width :: Int}
  | PoseidonMdsGate         { hash_width :: Int}
  | RandomAccessGate        { bits :: Int, num_copies :: Int, num_extra_constants :: Int }
  | ReducingGate            { num_coeffs :: Int }
  | ReducingExtensionGate   { num_coeffs :: Int }
  deriving (Eq,Show)

--------------------------------------------------------------------------------