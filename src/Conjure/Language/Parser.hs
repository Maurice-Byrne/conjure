{-# LANGUAGE QuasiQuotes, ViewPatterns, OverloadedStrings #-}
{-# LANGUAGE CPP #-}

#define TRACE1(label, f) f x   | trace (show $ label <+> pretty x) \
                                    False = error $ show $ "tracing" <+> label
#define TRACE2(label, f) f x y | trace (show $ label <+> sep [pretty x, "~~", pretty y]) \
                                    False = error $ show $ "tracing" <+> label

module Conjure.Language.Parser
    ( runLexerAndParser
    , parseModel
    , parseRuleRefn
    , parseRuleRepr
    , parseTopLevels
    ) where

-- conjure
import Conjure.Prelude
import Conjure.Bug
import Conjure.Language.Definition
import Conjure.Language.Pretty
import Conjure.Language.TypeCheck ( typeOf )
import Language.E ( Spec(..), E(..), BuiltIn(..), xMatch, xMake, viewTaggeds, statementAsList, prettyAsPaths )

import Language.E.Parser.Imports
import Language.E.Parser.EssenceFile



parseModel :: Parser Model
parseModel = specToModel <$> parseSpec

specToModel :: Spec -> Model
specToModel (Spec lang stmt) = Model
    { mLanguage = lang
    , mStatements = map convStmt (statementAsList stmt)
    , mInfo =
        ModelInfo
            { miRepresentations = []
            , miTrail = []
            }
    }

    where


        convStmt :: E -> Statement
        -- TRACE1("[convStmt]",convStmt)

        convStmt [xMatch| [Prim (S name)] := topLevel.declaration.given.name.reference
                        | [D domain     ] := topLevel.declaration.given.domain
                        |] = Declaration (Given (Name name) (convDomain domain))
        convStmt [xMatch| [Prim (S name)] := topLevel.declaration.find .name.reference
                        | [D domain     ] := topLevel.declaration.find .domain
                        |] = Declaration (Find (Name name) (convDomain domain))
        convStmt [xMatch| [Prim (S name)] := topLevel.letting.name.reference
                        | [expr         ] := topLevel.letting.expr
                        |] = Declaration (Letting (Name name) (convExpr expr))
        convStmt [xMatch| [Prim (S name)] := topLevel.letting.name.reference
                        | [domain       ] := topLevel.letting.domain
                        |] = Declaration (Letting (Name name) (convExpr domain))

        convStmt [xMatch| [expr] := topLevel.objective.minimising |] = Objective Minimising (convExpr expr)
        convStmt [xMatch| [expr] := topLevel.objective.maximising |] = Objective Maximising (convExpr expr)

        convStmt [xMatch| [expr] := topLevel.where    |] = Where    (convExpr expr)
        convStmt [xMatch| [expr] := topLevel.suchThat |] = SuchThat (convExpr expr)

        convStmt x = bug $ "convStmt" <+> prettyAsPaths x


        convExpr :: E -> Expression
        -- TRACE1("[convExpr]",convExpr)

        convExpr [xMatch| [Prim (B x)] := value.literal |] = Constant (ConstantBool x)
        convExpr [xMatch| [Prim (I x)] := value.literal |] = Constant (ConstantInt (fromInteger x))

        convExpr [xMatch| [Prim (S x)] := reference |] = Reference (Name x)

-- binary operators
        convExpr [xMatch| [Prim (S op)] := binOp.operator
                        | [left]        := binOp.left
                        | [right]       := binOp.right
                        |] = Op (Name op) [convExpr left, convExpr right]

-- quantified
        convExpr [xMatch| [Prim (S qnName)] := quantified.quantifier.reference
                        | [Prim (S nm)]     := quantified.quanVar.structural.single.reference
                        | [D quanOverDom]   := quantified.quanOverDom
                        | []                := quantified.quanOverOp
                        | []                := quantified.quanOverExpr
                        | [guardE]          := quantified.guard
                        | [body]            := quantified.body
                        |] =
            let
                ty = typeOf (convDomain quanOverDom)
                filterOr b = 
                    if guardE == [xMake| emptyGuard := [] |]
                        then b
                        else Op "filter"
                                [ Lambda (Name nm) ty (convExpr guardE) (bug $ "lambda:" <+> pretty (convExpr guardE))
                                , b
                                ]
            in
                Op (Name qnName)
                    [ filterOr
                        ( Op "map_domain"
                            [ Lambda (Name nm) ty (convExpr body) (bug $ "lambda:" <+> pretty (convExpr body))
                            , (Domain (convDomain quanOverDom))
                            ] ) ]

        convExpr [xMatch| [Prim (S qnName)] := quantified.quantifier.reference
                        | [Prim (S nm)]     := quantified.quanVar.structural.single.reference
                        | []                := quantified.quanOverDom
                        | []                := quantified.quanOverOp.binOp.in
                        | [quanOverExpr]    := quantified.quanOverExpr
                        | [guardE]          := quantified.guard
                        | [body]            := quantified.body
                        |] =
            let
                ty = typeOf (convExpr quanOverExpr)
                filterOr b = 
                    if guardE == [xMake| emptyGuard := [] |]
                        then b
                        else Op "filter"
                                [ Lambda (Name nm) ty (convExpr guardE) (bug $ "lambda:" <+> pretty (convExpr guardE))
                                , b
                                ]

            in
                Op (Name qnName)
                    [ filterOr
                        ( Op "map_in_expr"
                            [ Lambda (Name nm) ty (convExpr body) (bug $ "lambda:" <+> pretty (convExpr body))
                            , convExpr quanOverExpr
                            ] ) ]

-- unary operators
        convExpr [xMatch| xs := operator.dontCare     |] = Op "dontCare"     (map convExpr xs)
        convExpr [xMatch| xs := operator.allDiff      |] = Op "allDiff"      (map convExpr xs)
        convExpr [xMatch| xs := operator.apart        |] = Op "apart"        (map convExpr xs)
        convExpr [xMatch| xs := operator.defined      |] = Op "defined"      (map convExpr xs)
        convExpr [xMatch| xs := operator.flatten      |] = Op "flatten"      (map convExpr xs)
        convExpr [xMatch| xs := operator.freq         |] = Op "freq"         (map convExpr xs)
        convExpr [xMatch| xs := operator.hist         |] = Op "hist"         (map convExpr xs)
        convExpr [xMatch| xs := operator.inverse      |] = Op "inverse"      (map convExpr xs)
        convExpr [xMatch| xs := operator.max          |] = Op "max"          (map convExpr xs)
        convExpr [xMatch| xs := operator.min          |] = Op "min"          (map convExpr xs)
        convExpr [xMatch| xs := operator.normIndices  |] = Op "normIndices"  (map convExpr xs)
        convExpr [xMatch| xs := operator.participants |] = Op "participants" (map convExpr xs)
        convExpr [xMatch| xs := operator.parts        |] = Op "parts"        (map convExpr xs)
        convExpr [xMatch| xs := operator.party        |] = Op "party"        (map convExpr xs)
        convExpr [xMatch| xs := operator.preImage     |] = Op "preImage"     (map convExpr xs)
        convExpr [xMatch| xs := operator.range        |] = Op "range"        (map convExpr xs)
        convExpr [xMatch| xs := operator.together     |] = Op "together"     (map convExpr xs)
        convExpr [xMatch| xs := operator.toInt        |] = Op "toInt"        (map convExpr xs)
        convExpr [xMatch| xs := operator.toMSet       |] = Op "toMSet"       (map convExpr xs)
        convExpr [xMatch| xs := operator.toRelation   |] = Op "toRelation"   (map convExpr xs)
        convExpr [xMatch| xs := operator.toSet        |] = Op "toSet"        (map convExpr xs)

        convExpr [xMatch| [actual] := functionApply.actual
                      |   args   := functionApply.args
                      |]
            = Op "function_image" (map convExpr (actual : args))

        convExpr [xMatch| [x] := structural.single |] = convExpr x

-- values
        convExpr [xMatch| xs := value.tuple.values  |] =
            AbstractLiteral $ AbsLitTuple (map convExpr xs)

        convExpr [xMatch| xs      := value.matrix.values
                        | [D ind] := value.matrix.indexrange
                        |] =
            AbstractLiteral $ AbsLitMatrix (convDomain ind) (map convExpr xs)

        convExpr [xMatch| xs      := value.matrix.values
                        |] =
            AbstractLiteral $ AbsLitMatrix (DomainInt []) (map convExpr xs)

        convExpr [xMatch| xs := value.set.values |] =
            AbstractLiteral $ AbsLitSet (map convExpr xs)

        convExpr [xMatch| xs := value.mset.values |] =
            AbstractLiteral $ AbsLitMSet (map convExpr xs)

        convExpr [xMatch| xs := value.function.values |] =
            AbstractLiteral $ AbsLitFunction
                [ (convExpr i, convExpr j)
                | [xMatch| [i,j] := mapping |] <- xs
                ]

        convExpr [xMatch| xss := value.relation.values |] =
            AbstractLiteral $ AbsLitRelation
                [ map convExpr xs
                | [xMatch| xs := value.tuple.values |] <- xss
                ]

        convExpr [xMatch| xss := value.partition.values |] =
            AbstractLiteral $ AbsLitPartition
                [ map convExpr xs
                | [xMatch| xs := part |] <- xss
                ]

-- D
        convExpr (D x) = Domain (convDomain x)

        convExpr x = bug $ "convExpr" <+> prettyAsPaths x


        convDomain :: Domain () E -> Domain () Expression
        convDomain = fmap convExpr

