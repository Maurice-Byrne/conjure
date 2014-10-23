module Conjure.Representations.Set.Occurrence
    ( setOccurrence
    ) where

-- conjure
import Conjure.Prelude
import Conjure.Language.Definition
import Conjure.Language.Lenses
import Conjure.Language.Pretty
import Conjure.Language.DomainSize ( valuesInIntDomain )
import Conjure.Representations.Internal


setOccurrence :: MonadFail m => Representation m
setOccurrence = Representation chck setDown_ structuralCons setDown setUp

    where

        chck f (DomainSet _ attrs innerDomain@(DomainInt{})) = DomainSet "Occurrence" attrs <$> f innerDomain
        chck _ _ = []

        outName name = mconcat [name, "_", "Occurrence"]

        setDown_ (name, DomainSet "Occurrence" _attrs innerDomain@DomainInt{}) = return $ Just
            [ ( outName name
              , DomainMatrix (forgetRepr innerDomain) DomainBool
              )
            ]
        setDown_ _ = fail "N/A {setDown_}"

        structuralCons (name, DomainSet "Occurrence" attrs innerDomain@DomainInt{}) =
            let
                m = Reference (outName name)
                              (Just (DeclHasRepr
                                          Find
                                          (outName name)
                                          (DomainMatrix (forgetRepr innerDomain) DomainBool)))
                body iName = mkLambda iName TypeInt $ \ i -> make opIndexing m i
                cardinality iName = make opSum [make opMapOverDomain (body iName) (Domain (forgetRepr innerDomain))]
            in
                return $ case attrs of
                    SetAttrNone             -> Nothing
                    SetAttrSize x           -> Just $ \ fresh -> [ make opEq  x (cardinality (headInf fresh)) ]
                    SetAttrMinSize x        -> Just $ \ fresh -> [ make opLeq x (cardinality (headInf fresh)) ]
                    SetAttrMaxSize y        -> Just $ \ fresh -> [ make opGeq y (cardinality (headInf fresh)) ]
                    SetAttrMinMaxSize x y   -> Just $ \ fresh -> [ make opLeq x (cardinality (headInf fresh))
                                                                 , make opGeq y (cardinality (headInf fresh)) ]
        structuralCons _ = fail "N/A {structuralCons}"

        setDown (name, DomainSet "Occurrence" _attrs innerDomain@(DomainInt intRanges), ConstantSet constants) = do
                innerDomainVals <- valuesInIntDomain intRanges
                return $ Just
                    [ ( outName name
                      , DomainMatrix   (forgetRepr innerDomain) DomainBool
                      , ConstantMatrix (forgetRepr innerDomain)
                          [ ConstantBool isIn
                          | v <- innerDomainVals
                          , let isIn = ConstantInt v `elem` constants
                          ]
                      )
                    ]
        setDown _ = fail "N/A {setDown}"

        setUp ctxt (name, domain@(DomainSet _ _ (DomainInt intRanges)))=
            case lookup (outName name) ctxt of
                Just constantMatrix ->
                    case constantMatrix of
                        ConstantMatrix _ vals -> do
                            innerDomainVals <- valuesInIntDomain intRanges
                            return (name, ConstantSet
                                            [ ConstantInt v
                                            | (v,b) <- zip innerDomainVals vals
                                            , b == ConstantBool True
                                            ] )
                        _ -> fail $ vcat
                                [ "Expecting a matrix literal for:" <+> pretty (outName name)
                                , "But got:" <+> pretty constantMatrix
                                , "When working on:" <+> pretty name
                                , "With domain:" <+> pretty domain
                                ]
                Nothing -> fail $ vcat $
                    [ "No value for:" <+> pretty (outName name)
                    , "When working on:" <+> pretty name
                    , "With domain:" <+> pretty domain
                    ] ++
                    ("Bindings in context:" : prettyContext ctxt)
        setUp _ _ = fail "N/A {setUp}"

