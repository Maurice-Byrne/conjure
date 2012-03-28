{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}

module Language.Essence.Domain where

import Control.Monad.Trans.Class ( lift )

import Control.Applicative
import Control.Arrow ( first, second )
import Control.Monad ( ap, liftM, msum )
import Control.Monad.Error ( MonadError, ErrorT, throwError, runErrorT )
import Control.Monad.State ( MonadState, StateT, modify )
import Control.Monad.Writer ( MonadWriter )
import Data.Generics ( Data )
import Data.List ( sort )
import Data.Maybe ( fromMaybe )
import Data.Typeable ( Typeable )
import GHC.Generics ( Generic )
import qualified Data.Map as M
import Test.QuickCheck ( Arbitrary, arbitrary, elements )
import Test.QuickCheck.Gen ( oneof )

import GenericOps.Core ( NodeTag
                       , Hole, hole, HoleStatus(..)
                       , GPlate, gplate, gplateError, gplateLeaf, gplateSingle, gplateUniList
                       , GNode, mkG, fromG, fromGs
                       , MatchBind, match, BindingsMap
                       )
import ParsecUtils
import ParsePrint
import PrintUtils ( (<+>), (<>), text, Doc )
import qualified PrintUtils as Pr

import {-# SOURCE #-} Language.Essence.Expr
import                Language.Essence.Identifier
import                Language.Essence.Range
import                Language.Essence.Type
import {-# SOURCE #-} Language.Essence.Value
import {-# SOURCE #-} Language.EssenceEvaluator ( deepSimplify )



class DomainOf a where
    domainOf ::
        ( Applicative m
        , MonadError Doc m
        , MonadState BindingsMap m
        , MonadWriter [Doc] m
        ) => a -> m Domain

needsRepresentation :: Domain -> Bool
needsRepresentation (DMatrix _ e) = needsRepresentation e
needsRepresentation (AnyDom {dConstr = TSet      }) = True
needsRepresentation (AnyDom {dConstr = TMSet     }) = True
needsRepresentation (AnyDom {dConstr = TFunction }) = True
needsRepresentation (AnyDom {dConstr = TRelation }) = True
needsRepresentation (AnyDom {dConstr = TPartition}) = True
needsRepresentation _ = False

representationValue :: Domain -> Maybe Expr
representationValue (AnyDom {dAttrs = DomainAttrs attrs}) = msum $ flip map attrs $ \ a -> case a of
    NameValue AttrRepresentation x -> Just x
    _ -> Nothing
representationValue _ = Nothing



data Domain = DHole Identifier
    | DBool
    | DInt                (Range Expr)
    | DEnum    Identifier (Range Identifier)
    | DUnnamed Expr
    | DMatrix  Domain Domain
    | AnyDom { dConstr  :: AnyTypeEnum
             , dElement :: [Domain]
             , dAttrs   :: DomainAttrs
             }
    | Indices Expr Expr
    deriving (Eq, Ord, Read, Show, Data, Typeable, Generic)

instance NodeTag Domain

instance Hole Domain where
    hole (DHole (Identifier "_")) = UnnamedHole
    hole (DHole (Identifier nm) ) = NamedHole nm
    hole _                        = NotAHole

instance GPlate Domain where
    gplate   (DHole  x) = gplateSingle DHole x
    gplate p@(DBool {}) = gplateLeaf p
    gplate   (DInt   x) = gplateSingle DInt x
    gplate (DEnum nm x) =
        ( [mkG nm, mkG x]
        , \ xs ->
            case xs of
                [mnm,mx] ->
                    case (fromG mnm, fromG mx) of
                        (Just nm', Just x') -> DEnum nm' x'
                        _                   -> gplateError "Domain DEnum[1]"
                _ -> gplateError "Domain DEnum[2]"
        )
    gplate (DUnnamed x) = gplateSingle DUnnamed x
    gplate (DMatrix i e) = gplateUniList (\ [i',e'] -> DMatrix i' e' ) [i,e]
    gplate (AnyDom nm es as) =
        ( mkG nm : mkG as : map mkG es
        , \ xs -> let nm' = fromGs $ take 1 xs
                      as' = fromGs $ take 1 $ drop 1 xs
                      es' = fromGs $ drop 2 xs
                  in  if length nm' == 1 &&
                         length as' == 1 &&
                         length es' == length es
                          then AnyDom (head nm') es' (head as')
                          else gplateError "Domain AnyDom"
        )
    gplate (Indices x y) = gplateUniList (\ [x',y'] -> Indices x' y' ) [x,y]

instance MatchBind Domain

instance ParsePrint Domain where
    parse = choiceTry
                [ pBool, pInt, pEnum, pUnnamed, pMatrix
                , pTuple, pSetMSet "set" TSet, pSetMSet "mset" TMSet
                , pFunction, pRelation, pPartition
                , pIndices
                , pDHole
                ]
        where
            pDHole = DHole <$> parse

            pBool = DBool <$ reserved "bool"

            pInt     = do reserved "int" ; DInt  <$>           (try (parens parse) <|> return RAll)

            pEnum    = DEnum <$> parse <*> (try (parens parse) <|> return RAll)

            -- needed to disambiguate from DHole
            -- DHole can still be resolved to DUnnamed, after parsing.
            pUnnamed = do reserved "unnamed";  DUnnamed <$> parse

            pMatrix = do
                reserved "matrix"
                reserved "indexed"
                reserved "by"
                is <- brackets (parse `sepBy1` comma)
                reserved "of"
                e  <- parse
                return $ foldr DMatrix e is

            pTuple = do
                reserved "tuple"
                as <- parse
                reserved "of"
                es <- parens (parse `sepBy` comma)
                return $ AnyDom TTuple es as

            pSetMSet kw en = do
                reserved kw
                as <- parse
                reserved "of"
                e  <- parse
                return $ AnyDom en [e] as

            pFunction = do
                reserved "function"
                as <- parse
                fr <- parse
                reservedOp "->"
                to <- parse
                return $ AnyDom TFunction [fr,to] as

            pRelation = do
                reserved "relation"
                as <- parse
                reserved "of"
                es <- parens (parse `sepBy` reservedOp "*")
                return $ AnyDom TRelation es as

            pPartition = do
                reserved "partition"
                as <- parse
                reserved "from"
                e  <- parse
                return $ AnyDom TPartition [e] as

            pIndices = do
                reserved "indices"
                parens $ do
                    i <- parse
                    comma
                    j <- parse
                    return (Indices i j)

    pretty (DHole (Identifier nm)) = text nm
    pretty DBool = "bool"
    pretty (DInt RAll) = "int"
    pretty (DInt r   ) = "int" <> Pr.parens (pretty r)
    pretty (DEnum i RAll) = pretty i
    pretty (DEnum i r   ) = pretty i <> Pr.parens (pretty r)
    pretty (DUnnamed i) = "unnamed" <+> pretty i
    pretty (DMatrix i e) = "matrix" <+> "indexed"
                       <+> "by" <+> prettyList Pr.brackets Pr.comma is
                       <+> "of" <+> pretty e'
        where
            (is,e') = helper i e
            helper a b = first (a:) $ case b of DMatrix c d -> helper c d
                                                _           -> ([], b)
    pretty (AnyDom TTuple es as) = "tuple" <+> pretty as <+> "of"
                                                <+> prettyList Pr.parens Pr.comma es
    pretty (AnyDom TSet  [e] as) = "set"  <+> pretty as <+> "of" <+> pretty e
    pretty (AnyDom TMSet [e] as) = "mset" <+> pretty as <+> "of" <+> pretty e
    pretty (AnyDom TFunction [fr,to] as) = "function"  <+> pretty as <+> pretty fr <+> "->" <+> pretty to
    pretty (AnyDom TRelation es as) = "relation" <+> pretty as <+> "of"
                                                      <+> prettyList Pr.parens "*" es
    pretty (AnyDom TPartition [e] as) = "partition" <+> pretty as <+> "from" <+> pretty e
    pretty (Indices x y) = "indices" <> prettyList Pr.parens Pr.comma [x,y]
    pretty p = error ("Invalid domain: " ++ show p)

instance Arbitrary Domain where
    arbitrary = {-deepPromote <$> -}oneof
        [ DHole    <$> arbitrary
        , return DBool
        , DInt     <$> arbitrary
        , DEnum    <$> arbitrary <*> arbitrary
        , DUnnamed <$> arbitrary
        , DMatrix  <$> arbitrary <*> arbitrary
        , AnyDom TTuple     <$> arbitrary              <*> arbitrary
        , AnyDom TSet       <$> (return <$> arbitrary) <*> arbitrary
        , AnyDom TMSet      <$> (return <$> arbitrary) <*> arbitrary
        , do (fr,to) <- arbitrary; AnyDom TFunction [fr,to] <$> arbitrary
        , AnyDom TRelation  <$> arbitrary              <*> arbitrary
        , AnyDom TPartition <$> (return <$> arbitrary) <*> arbitrary
        ]

instance TypeOf Domain where
    typeOf (DHole  i) = return $ THole i
    typeOf DBool      = return TBool
    typeOf (DInt  {}) = return TInt
    typeOf (DEnum {}) = return $ TEnum Nothing
    typeOf (DUnnamed  x) = return $ TUnnamed x
    typeOf (DMatrix a b) = TMatrix `liftM` typeOf a `ap` typeOf b
    typeOf (AnyDom e ds _) = AnyType e `liftM` mapM typeOf ds
    typeOf p@(Indices m (V (VInt ind))) = do

        let
            go (TMatrix x _) 0 = return x
            go (TMatrix _ x) n = go x (n-1)
            go _ _ = Nothing

        tm <- typeOf =<< deepSimplify m
        case go tm ind of
            Nothing -> throwError $ "typeOf fail:" <+> pretty p
            Just t  -> return t
    typeOf p@(Indices _ _) = throwError $ "typeOf fail:" <+> pretty p

instance DomainOf Domain where
    domainOf = return



newtype DomainAttrs = DomainAttrs [DomainAttr]
    deriving (Eq, Ord, Read, Show, Data, Typeable, Generic)

instance NodeTag DomainAttrs

instance Hole DomainAttrs

instance GPlate DomainAttrs where
    gplate (DomainAttrs xs) = gplateUniList DomainAttrs xs

instance MatchBind DomainAttrs where
    match p@(DomainAttrs ps) a@(DomainAttrs as) = do
        lift $ lift $ modify ((mkG p, mkG a) :) -- add this node on top of the call stack.
        helper (DontCare `elem` ps)
               (sort $ filter (/=DontCare) ps)
               (sort $ filter (/=DontCare) as)
        lift $ lift $ modify tail
        where
            checkMatch :: Monad m => DomainAttr -> DomainAttr -> StateT (M.Map String GNode) (StateT [(GNode,GNode)] m) Bool
            checkMatch i j = do
                res <- runErrorT (match i j)
                case res of
                    Right _ -> return True
                    _       -> return False

            tryMatch :: Monad m => DomainAttr -> [DomainAttr] -> StateT (M.Map String GNode) (StateT [(GNode,GNode)] m) (Bool, [DomainAttr])
            tryMatch _ []     = return (False, [])
            tryMatch i (j:js) = do
                b <- checkMatch i j
                if b
                    then return (b,js)
                    else second (j:) `liftM` tryMatch i js

            helper :: Monad m => Bool -> [DomainAttr] -> [DomainAttr] -> ErrorT Doc (StateT (M.Map String GNode) (StateT [(GNode,GNode)] m)) ()
            helper _    []     []     = return ()  -- if both attr lists are fully consumed.
            helper True []     _      = return ()  -- if the pattern list is fully consumed, we DontCare.
            helper d    (x:xs) ys = do
                (res, ys') <- lift $ tryMatch x ys
                if res
                    then helper d xs ys'
                    else throwError $ "attribute in pattern not found in actual: " <+> pretty x
            helper _ _ ys = throwError $ "some attibutes in actual not matched: " <+> prettyList id Pr.comma ys

instance ParsePrint DomainAttrs where
    parse = DomainAttrs . fromMaybe [] <$> optionMaybe (parens (parse `sepBy` comma))
    pretty (DomainAttrs []) = Pr.empty
    pretty (DomainAttrs xs) = prettyList Pr.parens Pr.comma xs

instance Arbitrary DomainAttrs where
    arbitrary = DomainAttrs <$> arbitrary



data DomainAttr
    = OnlyName DomainAttrEnum
    | NameValue DomainAttrEnum Expr
    | DontCare
    deriving (Eq, Ord, Read, Show, Data, Typeable, Generic)

instance NodeTag DomainAttr

instance Hole DomainAttr

instance GPlate DomainAttr where
    gplate (OnlyName e) = gplateSingle OnlyName e
    gplate (NameValue e x) =
        ( [mkG e, mkG x]
        , \ ex ->
            case ex of
                [me,mx] ->
                    case (fromG me, fromG mx) of
                        (Just e', Just x') -> NameValue e' x'
                        _ -> gplateError "DomainAttr[1]"
                _ -> gplateError "DomainAttr[2]"
        )
    gplate p@(DontCare {}) = gplateLeaf p

instance MatchBind DomainAttr

instance ParsePrint DomainAttr where
    parse = choiceTry [pNameValue, pOnlyName, pDontCare]
        where
            pOnlyName  = OnlyName  <$> parse
            pNameValue = NameValue <$> parse <*> parse
            pDontCare  = DontCare  <$  reservedOp "_"
    pretty (OnlyName e) = pretty e
    pretty (NameValue e x) = pretty e <+> pretty x
    pretty DontCare = "_"

instance Arbitrary DomainAttr where
    arbitrary = oneof
        [ OnlyName  <$> arbitrary
        , NameValue <$> arbitrary <*> arbitrary
        , return DontCare
        ]



data DomainAttrEnum
    = AttrRepresentation
    | AttrSize
    | AttrMinSize
    | AttrMaxSize
    | AttrOccr
    | AttrMinOccr
    | AttrMaxOccr
    | AttrTotal
    | AttrPartial
    | AttrInjective
    | AttrSurjective
    | AttrBijective
    | AttrRegular
    | AttrComplete
    | AttrPartSize
    | AttrMinPartSize
    | AttrMaxPartSize
    | AttrNumParts
    | AttrMinNumParts
    | AttrMaxNumParts
    deriving (Eq, Ord, Read, Show, Enum, Bounded, Data, Typeable, Generic)

instance NodeTag DomainAttrEnum

instance Hole DomainAttrEnum

instance GPlate DomainAttrEnum

instance MatchBind DomainAttrEnum

instance ParsePrint DomainAttrEnum where
    isoParsePrint = fromPairs
            [ ( AttrRepresentation , "representation" )
            , ( AttrSize           , "size"           )
            , ( AttrMinSize        , "minSize"        )
            , ( AttrMaxSize        , "maxSize"        )
            , ( AttrOccr           , "occr"           )
            , ( AttrMinOccr        , "minOccr"        )
            , ( AttrMaxOccr        , "maxOccr"        )
            , ( AttrTotal          , "total"          )
            , ( AttrPartial        , "partial"        )
            , ( AttrInjective      , "injective"      )
            , ( AttrSurjective     , "surjective"     )
            , ( AttrBijective      , "bijective"      )
            , ( AttrRegular        , "regular"        )
            , ( AttrComplete       , "complete"       )
            , ( AttrPartSize       , "partSize"       )
            , ( AttrMinPartSize    , "minPartSize"    )
            , ( AttrMaxPartSize    , "maxPartSize"    )
            , ( AttrNumParts       , "numParts"       )
            , ( AttrMinNumParts    , "minNumParts"    )
            , ( AttrMaxNumParts    , "maxNumParts"    )
            ]

instance Arbitrary DomainAttrEnum where
    arbitrary = elements [minBound .. maxBound]
