
-- | Gate constraints
--
-- Each gate occupies a single row (exlusively), and can have any (fixed) number 
-- of constraints.
--

{-# LANGUAGE StrictData, RecordWildCards #-}
module Gate.Constraints where

--------------------------------------------------------------------------------

import Prelude    hiding ( (^) )
import Data.Array hiding (range)
import Data.Char
import Control.Monad

import Algebra.Goldilocks
import Algebra.GoldilocksExt
import Algebra.Expr

import Gate.Base
import Gate.Vars
import Gate.Computation
import Misc.Aux

import Gate.Custom.Poseidon
import Gate.Custom.RandomAccess
import Gate.Custom.CosetInterp
import Gate.Custom.Reducing

--------------------------------------------------------------------------------
-- * Gate constraints

-- | Returns the (symbolic) constraints for the given gate
--
gateProgram :: Gate -> StraightLine
gateProgram = compileToStraightLine . gateComputation

gateComputation :: Gate -> Compute ()
gateComputation gate = 
  case gate of

    -- `w[i] - c0*x[i]*y[i] - c1*z[i] = 0`
    ArithmeticGate num_ops 
      -> commitList [ wire (j+3) - cnst 0 * wire j * wire (j+1) - cnst 1 * wire (j+2) | i<-range num_ops, let j = 4*i ]

    -- same but consecutive witness variables make up an extension field element
    ArithmeticExtensionGate num_ops 
      -> forM_ (range num_ops) $ \i -> do
           let j  = 8*i
           let c0 = fromBase (cnst 0)
           let c1 = fromBase (cnst 1)
           commitExt $ wireExt (j+6) - c0 * wireExt j * wireExt (j+2) - c1 * wireExt (j+4)

    -- `sum b^i * limbs[i] - out = 0`, and `0 <= limb[i] < B` is enforced
    BaseSumGate num_limbs base
      -> let limb i = wire (i+1)
             horner = go 0 where go k = if k < num_limbs-1 then limb k + fromIntegral base * go (k+1) else limb k
             sum_eq = horner - wire 0
             range_eq i = product [ limb i - fromIntegral k | k<-[0..base-1] ]
         in  commitList $ sum_eq : [ range_eq i | i<-range num_limbs ]

    CosetInterpolationGate subgroup_bits constr_degree barycentric_weights 
      -> cosetInterpolationGateConstraints $ MkCICfg (Log2 subgroup_bits) constr_degree barycentric_weights

    -- `c[i] - x[i] = 0`
    ConstantGate num_consts
      -> commitList [ cnst i - wire i | i <- range num_consts ]

    -- computes `out = base ^ (sum 2^i e_i)`
    -- order of witness variables: [ base, e[0],...,e[n-1], output, t[0]...t[n-1] ]
    ExponentiationGate num_power_bits -> exponentiationGateConstraints num_power_bits

    -- lookups are handled specially, no constraints here
    LookupGate      num_slots lut_hash              -> return ()
    LookupTableGate num_slots lut_hash last_lut_row -> return ()

    -- `z[i] - c0*x[i]*y[i] = 0`, and two witness cells make up an extension field element
    MulExtensionGate num_ops 
      -> forM_ (range num_ops) $ \i -> do
           let j  = 6*i
           commitExt $ wireExt (j+4) - fromBase (cnst 0) * wireExt j * wireExt (j+2) 

    NoopGate -> return ()

    -- equality with "hardcoded" hash components
    PublicInputGate 
      -> commitList [ wire i - hash i | i <- range 4 ]

    PoseidonGate hash_width -> case hash_width of
      12 -> poseidonGateConstraints
      k  -> error ( "gateConstraints/PoseidonGate: unsupported width " ++ show k)

    PoseidonMdsGate hash_width -> case hash_width of
      12 -> poseidonMdsGateConstraints
      k  -> error ( "gateConstraints/PoseidonMdsGate: unsupported width " ++ show k)

    RandomAccessGate num_bits num_copies num_extra_constants 
      -> randomAccessGateConstraints (MkRACfg (Log2 num_bits) num_copies num_extra_constants)

    ReducingGate num_coeffs 
      -> reducingGateConstraints num_coeffs

    ReducingExtensionGate num_coeffs 
      -> reducingExtensionGateConstraints num_coeffs

    UnknownGate name -> error ("gateConstraints: unknown gate `" ++ name ++ "`")

--------------------------------------------------------------------------------

-- computes `out = base ^ (sum 2^i e_i)`
-- order of witness variables: [ base, e[0],...,e[n-1], output, t[0]...t[n-1] ]
exponentiationGateConstraints :: Int -> Compute ()
exponentiationGateConstraints num_power_bits = 
  do
    let prev i = if i==0 then 1 else sqr (tmp_val (i-1))
    let comp i = prev i * (cur_bit i * base + (1 - cur_bit i))
    let eq   i = comp i - tmp_val i
    commitList [ eq i | i <- range num_power_bits ] 
    commit     ( out - tmp_val (num_power_bits-1) )
  where
    base       = wire 0
    exp_bit i  = wire (i+1)
    out        = wire (num_power_bits+1)
    tmp_val i  = wire (num_power_bits+2+i)
    cur_bit i  = exp_bit (num_power_bits - 1 - i)
    sqr x      = x*x

--------------------------------------------------------------------------------
-- * Debugging

{-
testCompute :: Compute () -> [FExt]
testCompute = runComputation testEvaluationVarsExt 

testArtihExtGate    = testCompute $ gateComputation (ArithmeticExtensionGate 10)
testBaseSum2        = testCompute $ gateComputation (BaseSumGate 13 2)
testBaseSum3        = testCompute $ gateComputation (BaseSumGate 13 3)
testExpoGate        = testCompute $ gateComputation (ExponentiationGate 13)
testMulExtGate      = testCompute $ gateComputation (MulExtensionGate   13)
testCosetGate3      = testCompute $ cosetInterpolationGateConstraints $ cosetInterpolationGateConfig (Log2 3)
testCosetGate4      = testCompute $ cosetInterpolationGateConstraints $ cosetInterpolationGateConfig (Log2 4)
testCosetGate5      = testCompute $ cosetInterpolationGateConstraints $ cosetInterpolationGateConfig (Log2 5)
testRandAccGate     = testCompute $ randomAccessGateConstraints       $ randomAccessGateConfig       (Log2 4)
testPoseidonGate    = testCompute $ gateComputation (PoseidonGate    12)
testPoseidonMdsGate = testCompute $ gateComputation (PoseidonMdsGate 12)
testReducingGate    = testCompute $ gateComputation (ReducingGate          13)
testReducingExtGate = testCompute $ gateComputation (ReducingExtensionGate 13)
-}

--------------------------------------------------------------------------------
