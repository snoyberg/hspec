-----------------------------------------------------------------------------
--
-- Module      :  Test.Hspec.Internal
-- Copyright   :  (c) Trystan Spangler 2011
-- License     :  modified BSD
--
-- Maintainer  : trystan.s@comcast.net
-- Stability   : experimental
-- Portability : portable
--
-- |
--
-----------------------------------------------------------------------------

module Test.Hspec.Internal where

import System.IO
import Data.List (groupBy)
import System.CPUTime (getCPUTime)

-- | The result of running a test.
data Result = Success | Fail | Pending String
  deriving Eq

-- | Everything needed to specify and test a specific behavior.
data Spec = Spec {
     -- | What is being tested, usually the name of a type.
     name::String,
     -- | The specific requirement.
     requirement::String,
     -- | The status of this requirement.
     result::Result }

-- | Create a set of specifications for something being described.
--   Once you know what you want specs for, use this.
--
-- > describe "abs" [
-- >   it "returns a positive number given a negative number"
-- >     (abs (-1) == 1)
-- >   ]
--
describe :: String                -- ^ The name of what is being described, usually a function or type.
         -> [IO (String, Result)] -- ^ A list of requirements and verifiers, created by a list of 'it'.
         -> IO [Spec]             -- ^ The resulting specs.
describe n ss = do
  ss' <- sequence ss
  return $ map (\ (req, res) -> Spec n req res) ss'

-- | Anything that can be used as verification that a requirement is met.
class SpecVerifier a where
  -- | Describe a requirement and it's verification, a list of these is used by 'describe'.
  --   Once you know what you want to specify, use this.
  --
  -- > describe "closeEnough" [
  -- >   it "is true if two numbers are almost the same"
  -- >     (1.001 `closeEnough` 1.002),
  -- >
  -- >   it "is false if two numbers are not almost the same"
  -- >     (not $ 1.001 `closeEnough` 1.003),
  -- >
  -- >   it "can also detect infinite loops"
  -- >     (pending "still figuring this one out")
  -- >   ]
  --
  it :: String              -- ^ A requirement for what is being described.
     -> a                   -- ^ A verifier for this requirement.
     -> IO (String, Result) -- ^ The combined requirement and result of verification.

instance SpecVerifier Bool where
  it n b = return (n, if b then Success else Fail)

instance SpecVerifier Result where
  it n r = return (n, r)

-- | Declare a requirement as not successful or failing but pending some other work.
--   If you want to track a requirement but don't expect it to succeed or fail yet, use this.
--
-- > describe "fancyFormatter" [
-- >   it "can format text in a way that everyone likes"
-- >     (pending "waiting for clarification from the designers")
-- >   ]
--
pending :: String  -- ^ An explanation for why this requirement is pending.
        -> Result
pending = Pending

-- | Create a document of the given specs.
documentSpecs :: [Spec] -> [String]
documentSpecs = concatMap documentGroup . groupBy (\ a b -> name a == name b)

-- | Create a document of the given group of specs.
documentGroup :: [Spec] -> [String]
documentGroup specGroup = "" : name (head specGroup) : map documentSpec specGroup

-- | Create a document of the given spec.
documentSpec :: Spec -> String
documentSpec spec  = case result spec of
                Success    -> " - " ++ requirement spec
                Fail       -> " x " ++ requirement spec
                Pending s  -> " - " ++ requirement spec ++ "\n     # " ++ s

-- | Create a summary of how long it took to verify the specs.
timingSummary :: Double -> String
timingSummary t = "Finished in " ++ quantify (t / (10.0^(12::Integer))) "second"

-- | Create a summary of how many specs exist and how many failed verification.
successSummary :: [Spec] -> String
successSummary ss = quantify (length ss) "example" ++ ", " ++ quantify failed "failure"
    where failed = length $ filter ((==Fail).result) ss

-- | Create a document of the given specs.
-- This does not track how much time it took to verify the specs.
-- If you want a description of each requirement and don't need to know how
-- long it tacks to check, use this.
pureHspec :: [Spec]   -- ^ The specs you are interested in.
          -> [String] -- ^ A human-readable summary of the specs and which need to be implemented.
pureHspec ss = documentSpecs ss ++ [ "", timingSummary 0, "", successSummary ss]

-- | Create a document of the given specs and write it to the given handle.
-- This does track how much time it took to verify the specs.
-- If you want a description of each requirement and do need to know how long it
-- tacks to check or want to write to a handle, use this.
--
-- > writeReport filename specs = withFile filename WriteMode (\ h -> hHspec h specs)
--
hHspec :: Handle     -- ^ A handle for the stream you want to write to, usually a file or stdout.
       -> IO [Spec]  -- ^ The specs you are interested in.
       -> IO ()
hHspec h ss = do
  t0 <- getCPUTime
  ss' <- ss
  mapM_ (hPutStrLn h) $ documentSpecs ss'
  t1 <- getCPUTime
  mapM_ (hPutStrLn h) [ "", timingSummary (fromIntegral $ t1 - t0), "", successSummary ss']


-- | Create a document of the given specs and write it to stdout.
hspec :: IO [Spec] -> IO ()
hspec = hHspec stdout


-- | Create a more readable display of a quantity of something.
quantify :: Num a => a -> String -> String
quantify 1 s = "1 " ++ s
quantify n s = show n ++ " " ++ s ++ "s"



