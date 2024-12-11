
module Main where

--------------------------------------------------------------------------------

import Data.Aeson

import Types
import Hash
import Digest
import Goldilocks

import qualified Data.ByteString.Char8      as B
import qualified Data.ByteString.Lazy.Char8 as L

--------------------------------------------------------------------------------

main = do
  let publicIO = MkPublicInputs [0, 1, 3736710860384812976]
  text_common <- L.readFile "json/fibonacci_common.json"
  text_proof  <- L.readFile "json/fibonacci_proof.json"
  text_vkey   <- L.readFile "json/fibonacci_vkey.json"

  -- let Just vkey = decode text_vkey :: Maybe VerifierOnlyCircuitData
  -- print vkey
  -- putStrLn ""
  -- L.putStr (encode vkey)

  let ei = eitherDecode text_common :: Either String CommonCircuitData
  print ei
  putStrLn ""