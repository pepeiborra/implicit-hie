{-# LANGUAGE MultiWayIf #-}

module Main where

import Control.Monad
import Data.Attoparsec.Text
import qualified Data.Text as T
import qualified Data.Text.IO as T
import Hie.Cabal.Parser
import Hie.Yaml
import System.Directory
import System.Directory.Internal
import System.FilePath.Posix

main :: IO ()
main = do
  pwd <- getCurrentDirectory
  files <- listDirectory pwd
  cfs <- cabalFiles pwd
  let sOrC =
        if  | any ((".stack-work" ==) . takeFileName) files -> stackHieYaml
            | any (("dist-newstyle" ==) . takeFileName) files -> cabalHieYaml
            | any (("stack.yaml" ==) . takeFileName) files -> stackHieYaml
            | otherwise -> cabalHieYaml
      gen f = do
        f' <- T.readFile f
        case parseOnly parsePackage f' of
          Right r -> do
            let hiePath = fst (splitFileName f) </> "hie.yaml"
            T.writeFile hiePath $ sOrC r
            pure ("wrote " <> hiePath)
          _ -> pure $ "Could not parse " <> f
  when (null cfs) $ error $
    "No .cabal files found under"
      <> pwd
      <> "\n You may need to run stack build."
  mapM_ (putStrLn <=< gen) cfs

cabalFiles :: FilePath -> IO [FilePath]
cabalFiles f = do
  fs <- listDirectory f
  case filter ((".cabal" ==) . takeExtension) fs of
    h : _ -> pure [f </> h]
    _ ->
      fmap concat . mapM cabalFiles
        =<< filterM
          (fmap (fileTypeIsDirectory . fileTypeFromMetadata) . getFileMetadata)
          ( map (f </>) $
              filter
                (`notElem` [".git", "dist", "dist-newstyle", ".stack-work"])
                fs
          )