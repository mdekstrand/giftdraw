{-# LANGUAGE OverloadedStrings, TypeSynonymInstances, FlexibleInstances #-}
{-# LANGUAGE DeriveDataTypeable #-}

import Control.Monad
import Data.Text.Template

import Data.Random
import qualified Data.Text as T
import qualified Data.Text.Lazy as LT
import qualified Data.Text.Template as TT

import Text.ParserCombinators.Parsec

import System.Process
import System.Exit
import System.Console.CmdArgs
import System.Console.CmdArgs.Verbosity

import System.IO

data Entity = Entity { entityName :: String,
                       entityEmail :: String }
            deriving (Data, Typeable, Eq)

instance Show Entity where
  show e = entityName e ++ " <" ++ entityEmail e ++ ">"

familyParser :: GenParser Char st [Entity]
familyParser = do
  lines <- many line
  eof
  return lines
  where
    line :: GenParser Char st Entity
    line = do
      _ <- string "person"
      ws
      name <- qstr
      ws
      email <- qstr
      eol
      return $ Entity name email
    eol = char '\n'
    ws = skipMany1 space
    qstr = do
      _ <- char '"'
      s <- many $ noneOf "\"\n"
      _ <- char '"'
      return s

data RunParams =
  RunParams { pMailer :: String,
              pTemplate :: FilePath,
              pInputFile :: FilePath,
              pDryRun :: Bool}
  deriving (Show, Data, Typeable)

giftdrawArgs =
  RunParams{pMailer = "sendmail -t" &= explicit &= name "mailer" &= name "m"
                      &= help "specify mailer command"
                      &= typ "CMD",
            pTemplate = "email.txt" &= explicit &= name "template" &= name "t"
                        &= help "mail template file" &= typ "FILE",
            pInputFile = "family.cfg" &= args &= typ "INFILE",
            pDryRun = False &= explicit &= name "dry-run" &= name "n"
                      &= help "don't mail, just print drawings"}
  &= summary "Draw names for gifts"
  &= program "giftdraw"
  &= verbosity

draw :: [Entity] -> IO [(Entity,Entity)]
draw names = do
  random <- runRVar (shuffle names) StdRandom
  let alloc = zip names random
  if any (uncurry (==)) alloc
    then (hPutStrLn stderr "could not draw names, trying again"
          >> draw names)
    else return alloc

sendMail args pairs = do
  template <- fmap (TT.template . T.pack) $ readFile $ pTemplate args
  forM_ pairs $ \(g, r) -> do
    let ctx = context [("giver", entityName g),
                       ("email", entityEmail g),
                       ("recipient", entityName r)]
    let mail = LT.unpack $ render template ctx
    whenNormal $ putStrLn ("sending mail to " ++ entityName g)
    whenLoud $ putStrLn ("  (they give to " ++ entityName r ++ ")")
    let create = if pDryRun args
                 then shell "sed -e 's/^/> /'"
                 else shell $ pMailer args
    (Just hin, _, _, h) <- createProcess create{std_in=CreatePipe}
    hPutStr hin mail
    hClose hin
    code <- waitForProcess h
    case code of
      ExitSuccess -> return ()
      ExitFailure e -> error ("mail command exited with code " ++ show e)

  where
    context :: [(String, String)] -> Context
    context assocs x = maybe err T.pack . lookup (T.unpack x) $ assocs
      where err = error $ "Could not find key: " ++ T.unpack x

main :: IO ()
main = do
  args <- cmdArgs giftdrawArgs
  parseResult <- parseFromFile familyParser $ pInputFile args
  family <- case parseResult of
    Left err -> error $ show err
    Right f -> return f
  whenLoud $ do
    putStrLn "Names:"
    forM_ family $ print
  alloc <- draw family
  sendMail args alloc
