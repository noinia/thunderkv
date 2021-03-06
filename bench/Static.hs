module Main where

import           Control.Monad
import           Criterion.Main
import           Criterion.Types (reportFile)
import qualified Data.IntMap as IntMap
import qualified Data.List as List
import qualified Data.Map as Map
import qualified SortedVec as SortedVec
import           System.Random
import qualified Thunder.Map.Storable as Thunder
import qualified Thunder.Map.Boxed as ThunderBoxed

--------------------------------------------------------------------------------

randomIOs   :: Random a => Int -> IO [a]
randomIOs n = replicateM n randomIO

genKeys   :: Int -> IO [Int]
genKeys n = List.sort <$> randomIOs n

genInput   :: Int -> IO [(Int,Int)]
genInput n = map (\k -> (k,k)) <$> genKeys n

-- benchmark searches static trees

main :: IO ()
main = defaultMainWith config
    [ bgroup "Building " $ map build sizes
    , bgroup "Querying"  $ map (\n -> runQueries n (2*n)) sizes
    ]
  where
    sizes = map round $ [1e3, 1e4, 1e5]
    config = defaultConfig { reportFile = Just "bench-thunderkv-report.html" }


build   :: Int -> Benchmark
build n = env (genInput n) $ \xs ->
            bgroup ("building a tree of size " <> show n) $
              [ bench "Thunder"    $ nf Thunder.fromAscList    xs
              , bench "ThunderBoxed"    $ nf ThunderBoxed.fromAscList    xs
              -- , bench "Map"          $ nf Map.fromAscList    xs
              -- , bench "IntMap"       $ nf IntMap.fromAscList xs
              -- , bench "Baseline"     $ nf Baseline.fromAscList    xs
              -- , bench "SortedVec"    $ nf SortedVec.fromAscList    xs
              ]


preprocess n m = do xs <- genInput n
                    qs <- randomIOs m
                    pure $ ( Thunder.fromAscList xs
                           , ThunderBoxed.fromAscList xs
                           -- , Baseline.fromAscList xs
                           , Map.fromAscList xs
                           , IntMap.fromAscList xs
                           , SortedVec.fromAscList xs
                           , qs
                           )


runAllQueries     :: (Int -> Maybe (Int,Int)) -> [Int] -> Int
runAllQueries qry = List.foldl' (\a q -> case qry q of
                                           Nothing    -> a
                                           Just (_,v) -> a + v
                                ) 0





runQueries     :: Int -- ^ input size
               -> Int -- ^ Number of queries
               -> Benchmark
runQueries n m = env (preprocess n m) $ \(~(thunder, boxed, map', intMap, sortedVec,qs)) ->
                   bgroup ("querying " <> show m <> " queries on size " <> show n)
                     [ bench "Thunder"    $ nf (query Thunder.lookupGE thunder)            qs
                     , bench "ThunderBoxed"    $ nf (query ThunderBoxed.lookupGE boxed)            qs
                     , bench "Map"        $ nf (query Map.lookupGE map')            qs
                     , bench "IntMap"     $ nf (query IntMap.lookupGE intMap)       qs
                     -- , bench "Baseline"   $ nf (query Baseline.lookupGE vebB)       qs
                     , bench "SortedVec"  $ nf (query SortedVec.lookupGE sortedVec) qs
                     ]
  where
    query f t = runAllQueries (flip f t)
