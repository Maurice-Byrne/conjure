module Conjure.Language.Ops
    ( module Conjure.Language.Ops.Generated
    , OperatorContainer(..)
    , mkBinOp, mkOp
    ) where

-- conjure
import Conjure.Prelude
import Conjure.Bug
import Conjure.Language.AdHoc
import Conjure.Language.Pretty
import Conjure.Language.Lexer
import Conjure.Language.Ops.Generated


class OperatorContainer x where
    injectOp :: Ops x -> x
    projectOp :: MonadFail m => x -> m (Ops x)


mkBinOp :: OperatorContainer x => Text -> x -> x -> x
mkBinOp op a b =
    case textToLexeme op of
        Nothing -> bug ("Unknown binary operator:" <+> pretty op)
        Just l  ->
            let
                f = case l of
                    L_Plus      -> \ x y -> injectOp $ MkOpPlus      $ OpPlus       [x,y]
                    L_Minus     -> \ x y -> injectOp $ MkOpMinus     $ OpMinus       x y
                    L_Times     -> \ x y -> injectOp $ MkOpTimes     $ OpTimes      [x,y]
                    L_Div       -> \ x y -> injectOp $ MkOpDiv       $ OpDiv         x y
                    L_Mod       -> \ x y -> injectOp $ MkOpMod       $ OpMod         x y
                    L_Pow       -> \ x y -> injectOp $ MkOpPow       $ OpPow         x y
                    L_Eq        -> \ x y -> injectOp $ MkOpEq        $ OpEq          x y
                    L_Neq       -> \ x y -> injectOp $ MkOpNeq       $ OpNeq         x y
                    L_Lt        -> \ x y -> injectOp $ MkOpLt        $ OpLt          x y
                    L_Leq       -> \ x y -> injectOp $ MkOpLeq       $ OpLeq         x y
                    L_Gt        -> \ x y -> injectOp $ MkOpGt        $ OpGt          x y
                    L_Geq       -> \ x y -> injectOp $ MkOpGeq       $ OpGeq         x y
                    L_in        -> \ x y -> injectOp $ MkOpIn        $ OpIn          x y
                    L_And       -> \ x y -> injectOp $ MkOpAnd       $ OpAnd        [x,y]
                    L_Or        -> \ x y -> injectOp $ MkOpOr        $ OpOr         [x,y]
                    L_Imply     -> \ x y -> injectOp $ MkOpImply     $ OpImply       x y
                    L_Iff       -> \ x y -> injectOp $ MkOpEq        $ OpEq          x y
                    L_subset    -> \ x y -> injectOp $ MkOpSubset    $ OpSubset      x y
                    L_subsetEq  -> \ x y -> injectOp $ MkOpSubsetEq  $ OpSubsetEq    x y
                    L_supset    -> \ x y -> injectOp $ MkOpSupset    $ OpSupset      x y
                    L_supsetEq  -> \ x y -> injectOp $ MkOpSupsetEq  $ OpSupsetEq    x y
                    L_intersect -> \ x y -> injectOp $ MkOpIntersect $ OpIntersect   x y
                    L_union     -> \ x y -> injectOp $ MkOpUnion     $ OpUnion       x y
                    L_LexLt     -> \ x y -> injectOp $ MkOpLexLt     $ OpLexLt       x y
                    L_LexLeq    -> \ x y -> injectOp $ MkOpLexLeq    $ OpLexLeq      x y
                    _ -> bug ("Unknown lexeme for binary operator:" <+> pretty (show l))
            in
                f a b


mkOp :: (OperatorContainer x, ReferenceContainer x) => Text -> [x] -> x
mkOp op xs =
    case textToLexeme op of
        Nothing -> case op of
            "and"       -> injectOp (MkOpAnd       (OpAnd       xs))
            "or"        -> injectOp (MkOpOr        (OpOr        xs))
            "sum"       -> injectOp (MkOpPlus      (OpPlus      xs))
            "not"       -> injectOp (MkOpNot       (OpNot       (headNote "not takes a single argument"       xs)))
            "negate"    -> injectOp (MkOpNegate    (OpNegate    (headNote "negate takes a single argument"    xs)))
            "twoBars"   -> injectOp (MkOpTwoBars   (OpTwoBars   (headNote "twoBars takes a single argument"   xs)))
            "factorial" -> injectOp (MkOpFactorial (OpFactorial (headNote "factorial takes a single argument" xs)))
            _     -> bug ("Unknown operator:" <+> vcat [pretty op, pretty $ show $ textToLexeme op])
            -- _     -> opFunctionImage (fromName (Name op)) xs
        Just l -> case l of
            L_toInt        -> injectOp $ MkOpToInt        $ OpToInt        (headNote "toInt takes a single argument."    xs)
            L_defined      -> injectOp $ MkOpDefined      $ OpDefined      (headNote "defined takes a single argument."  xs)
            L_range        -> injectOp $ MkOpRange        $ OpRange        (headNote "range takes a single argument."    xs)
            L_restrict     -> injectOp $ MkOpRestrict     $ OpRestrict     (atNote "restrict 1" xs 0) (atNote "restrict 2" xs 1)
            L_allDiff      -> injectOp $ MkOpAllDiff      $ OpAllDiff      (headNote "allDiff takes a single argument."  xs)
            L_dontCare     -> injectOp $ MkOpDontCare     $ OpDontCare     (headNote "dontCare takes a single argument." xs)
            L_flatten      -> injectOp $ MkOpFlatten      $ OpFlatten      (headNote "flatten takes a single argument."  xs)
            L_toSet        -> injectOp $ MkOpToSet        $ OpToSet        (headNote "toSet takes a single argument."    xs)
            L_toMSet       -> injectOp $ MkOpToMSet       $ OpToMSet       (headNote "toMSet takes a single argument."   xs)
            L_max          -> injectOp $ MkOpMax          $ OpMax xs
            L_min          -> injectOp $ MkOpMin          $ OpMin xs
            L_preImage     -> injectOp $ MkOpPreImage     $ OpPreImage     (atNote "preImage 1" xs 0) (atNote "preImage 2" xs 1)
            L_freq         -> injectOp $ MkOpFreq         $ OpFreq         (atNote "freq 1"     xs 0) (atNote "freq 2"     xs 1)
            L_hist         -> injectOp $ MkOpHist         $ OpHist         (atNote "hist 1"     xs 0)
            L_parts        -> injectOp $ MkOpParts        $ OpParts        (headNote "parts takes a single argument."    xs)
            L_together     -> injectOp $ MkOpTogether     $ OpTogether     (atNote "together 1" xs 0)
                                                                           (atNote "together 2" xs 1)
                                                                           (atNote "together 3" xs 2)
            L_apart        -> injectOp $ MkOpApart        $ OpApart        (atNote "apart 1"    xs 0)
                                                                           (atNote "apart 2"    xs 1)
                                                                           (atNote "apart 3"    xs 2)
            L_party        -> injectOp $ MkOpParty        $ OpParty        (atNote "party 1"    xs 0)
                                                                           (atNote "party 2"    xs 1)
            L_participants -> injectOp $ MkOpParticipants $ OpParticipants (headNote "participants takes a single argument." xs)
            _ -> bug ("Unknown lexeme for operator:" <+> pretty (show l))