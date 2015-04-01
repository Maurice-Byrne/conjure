{-# LANGUAGE QuasiQuotes #-}

module Conjure.Rules.Horizontal.Sequence where

import Conjure.Rules.Import


rule_Comprehension_Literal :: Rule
rule_Comprehension_Literal = "sequence-comprehension-literal" `namedRule` theRule where
    theRule (Comprehension body gensOrConds) = do
        (gofBefore, (pat, expr), gofAfter) <- matchFirst gensOrConds $ \ gof -> case gof of
            Generator (GenInExpr pat@Single{} expr) -> return (pat, matchDefs [opToSet,opToMSet,opToRelation] expr)
            _ -> na "rule_Comprehension_Literal"
        (TypeSequence t, elems) <- match sequenceLiteral expr
        let outLiteral = make matrixLiteral
                            (TypeMatrix TypeInt t)
                            (DomainInt [RangeBounded 1 (fromInt (genericLength elems))])
                            elems
        let upd val old = lambdaToFunction pat old val
        return
            ( "Comprehension on sequence literals"
            , do
                (iPat, i) <- quantifiedVar
                let val = [essence| (&i, &outLiteral[&i]) |]
                return $ Comprehension (upd val body)
                         $  gofBefore
                         ++ [Generator (GenDomainNoRepr iPat $ mkDomainIntB 1 (fromInt $ genericLength elems))]
                         ++ transformBi (upd val) gofAfter
            )
    theRule _ = na "rule_Comprehension_Literal"


rule_Image_Literal_Bool :: Rule
rule_Image_Literal_Bool = "sequence-image-literal-bool" `namedRule` theRule where
    theRule p = do
        (func, arg)                    <- match opImage p
        (TypeSequence TypeBool, elems) <- match sequenceLiteral func
        -- let argIsUndef = make opNot $ make opOr $ fromList
        --         [ [essence| &a = &arg |]
        --         | (a,_) <- elems
        --         ]
        return $
            if null elems
                then
                    ( "Image of empty sequence literal"
                    , return [essence| false |]                          -- undefined is false.
                    )
                else
                    ( "Image of sequence literal"
                    , return $ make opOr $ fromList $
                          [ [essence| (&a = &arg) /\ &b |]              -- if this is ever true, the output is true.
                                                                        -- undefined is still false.
                          | (a',b) <- zip allNats elems
                          , let a = fromInt a'
                          ]
                    )


rule_Image_Literal_Int :: Rule
rule_Image_Literal_Int = "sequence-image-literal-int" `namedRule` theRule where
    theRule p = do
        (func, arg)                   <- match opImage p
        (TypeSequence TypeInt, elems) <- match sequenceLiteral func
        return
            ( "Image of sequence literal"
            , return $
                let
                    val = make opSum $ fromList $
                        -- if this is ever true, the output is the value of b.
                        [ [essence| toInt(&a = &arg) * &b |]
                        | (a',b) <- zip allNats elems
                        , let a = fromInt a'
                        ]
                    len = fromInt $ genericLength elems
                    argIsDef = [essence| &arg <= &len |]
                in
                    WithLocals val (Right [argIsDef])
            )


rule_Eq :: Rule
rule_Eq = "sequence-eq" `namedRule` theRule where
    theRule p = do
        (x,y)          <- match opEq p
        TypeSequence{} <- typeOf x
        TypeSequence{} <- typeOf y
        return
            ( "Horizontal rule for sequence equality"
            , do
                 (iPat, i) <- quantifiedVar
                 return
                     [essence|
                         (forAll &iPat in &x . &y(&i[1]) = &i[2])
                             /\
                         (forAll &iPat in &y . &x(&i[1]) = &i[2])
                             /\
                         defined(&x) = defined(&y)
                     |]
            )


rule_Neq :: Rule
rule_Neq = "sequence-neq" `namedRule` theRule where
    theRule [essence| &x != &y |] = do
        TypeSequence{} <- typeOf x
        TypeSequence{} <- typeOf y
        return
            ( "Horizontal rule for sequence dis-equality"
            , do
                 (iPat, i) <- quantifiedVar
                 return
                     [essence|
                         (exists &iPat in &x . !(&i in &y))
                         \/
                         (exists &iPat in &y . !(&i in &x))
                     |]
            )
    theRule _ = na "rule_Neq"


rule_SubsetEq :: Rule
rule_SubsetEq = "sequence-subsetEq" `namedRule` theRule where
    theRule p = do
        (x,y)          <- match opSubsetEq p
        TypeSequence{} <- typeOf x
        TypeSequence{} <- typeOf y
        return
            ( "Horizontal rule for sequence subsetEq"
            , do
                 (iPat, i) <- quantifiedVar
                 return
                     [essence|
                         (forAll &iPat in &x . &y(&i[1]) = &i[2])
                             /\
                         defined(&x) subsetEq defined(&y)
                     |]
            )


rule_Subset :: Rule
rule_Subset = "sequence-subset" `namedRule` theRule where
    theRule [essence| &a subset &b |] = do
        TypeSequence{} <- typeOf a
        TypeSequence{} <- typeOf b
        return
            ( "Horizontal rule for set subset"
            , return [essence| &a subsetEq &b /\ &a != &b |]
            )
    theRule _ = na "rule_Subset"


rule_Supset :: Rule
rule_Supset = "set-supset" `namedRule` theRule where
    theRule [essence| &a supset &b |] = do
        TypeSequence{} <- typeOf a
        TypeSequence{} <- typeOf b
        return
            ( "Horizontal rule for set supset"
            , return [essence| &b subset &a |]
            )
    theRule _ = na "rule_Supset"


rule_SupsetEq :: Rule
rule_SupsetEq = "set-subsetEq" `namedRule` theRule where
    theRule [essence| &a supsetEq &b |] = do
        TypeSequence{} <- typeOf a
        TypeSequence{} <- typeOf b
        return
            ( "Horizontal rule for set supsetEq"
            , return [essence| &b subsetEq &a |]
            )
    theRule _ = na "rule_SupsetEq"


rule_Lt :: Rule
rule_Lt = "sequence-lt" `namedRule` theRule where
    theRule p = do
        (a,b) <- match opLt p
        TypeSequence{} <- typeOf a
        TypeSequence{} <- typeOf b
        hasRepresentation a
        hasRepresentation b
        ma <- tupleLitIfNeeded <$> downX1 a
        mb <- tupleLitIfNeeded <$> downX1 b
        return
            ( "Horizontal rule for sequence <" <+> pretty (make opLt ma mb)
            , return $ make opLt ma mb
            )


rule_Leq :: Rule
rule_Leq = "sequence-leq" `namedRule` theRule where
    theRule p = do
        (a,b) <- match opLeq p
        TypeSequence{} <- typeOf a
        TypeSequence{} <- typeOf b
        hasRepresentation a
        hasRepresentation b
        ma <- tupleLitIfNeeded <$> downX1 a
        mb <- tupleLitIfNeeded <$> downX1 b
        return
            ( "Horizontal rule for sequence <=" <+> pretty (make opLeq ma mb)
            , return $ make opLeq ma mb
            )


rule_Comprehension_PreImage :: Rule
rule_Comprehension_PreImage = "sequence-preImage" `namedRule` theRule where
    theRule (Comprehension body gensOrConds) = do
        (gofBefore, (pat, expr), gofAfter) <- matchFirst gensOrConds $ \ gof -> case gof of
            Generator (GenInExpr pat@Single{} expr) -> return (pat, expr)
            _ -> na "rule_Comprehension_PreImage"
        (func, img) <- match opPreImage expr
        TypeSequence{} <- typeOf func
        let upd val old = lambdaToFunction pat old val
        return
            ( "Mapping over the preImage of a sequence"
            , do
                (jPat, j) <- quantifiedVar
                let val = [essence| &j[1] |]
                return $ Comprehension
                        (upd val body)
                        $  gofBefore
                        ++ [ Generator (GenInExpr jPat func)
                           , Condition [essence| &j[2] = &img |]
                           ]
                        ++ transformBi (upd val) gofAfter
            )
    theRule _ = na "rule_Comprehension_PreImage"


rule_Card :: Rule
rule_Card = "sequence-cardinality" `namedRule` theRule where
    theRule [essence| |&s| |] = do
        TypeSequence{} <- typeOf s
        return
            ( "Horizontal rule for sequence cardinality."
            , do
                (iPat, _) <- quantifiedVar
                return [essence| sum &iPat in &s . 1 |]
            )
    theRule _ = na "rule_Card"


rule_Comprehension_Defined :: Rule
rule_Comprehension_Defined = "sequence-defined" `namedRule` theRule where
    theRule (Comprehension body gensOrConds) = do
        (gofBefore, (pat, expr), gofAfter) <- matchFirst gensOrConds $ \ gof -> case gof of
            Generator (GenInExpr pat@Single{} expr) -> return (pat, expr)
            _ -> na "rule_Comprehension_Defined"
        s                                            <- match opDefined expr
        DomainSequence _ (SequenceAttr sizeAttr _) _ <- domainOf s
        maxSize <- case sizeAttr of
                    SizeAttr_Size x -> return x
                    SizeAttr_MaxSize x -> return x
                    SizeAttr_MinMaxSize _ x -> return x
                    _ -> fail "rule_Comprehension_Defined maxSize"
        let upd val old = lambdaToFunction pat old val
        return
            ( "Mapping over defined(f)"
            , do
                (jPat, j) <- quantifiedVar
                let val = j
                return $ Comprehension
                            (upd val body)
                            $  gofBefore
                            ++ [ Generator (GenDomainNoRepr jPat $ mkDomainIntB 1 maxSize)
                               , Condition [essence| &j <= |&s| |]
                               ]
                            ++ transformBi (upd val) gofAfter
            )
    theRule _ = na "rule_Comprehension_Defined"


-- | TODO: This may allow repetitions.
rule_Comprehension_Range :: Rule
rule_Comprehension_Range = "sequence-range" `namedRule` theRule where
    theRule (Comprehension body gensOrConds) = do
        (gofBefore, (pat, expr), gofAfter) <- matchFirst gensOrConds $ \ gof -> case gof of
            Generator (GenInExpr pat@Single{} expr) -> return (pat, expr)
            _ -> na "rule_Comprehension_PreImage"
        func <- match opRange expr
        TypeSequence{} <- typeOf func
        let upd val old = lambdaToFunction pat old val
        return
            ( "Mapping over range(f)"
            , do
                (jPat, j) <- quantifiedVar
                let val = [essence| &j[2] |]
                return $ Comprehension
                            (upd val body)
                            $  gofBefore
                            ++ [ Generator (GenInExpr jPat func) ]
                            ++ transformBi (upd val) gofAfter
            )
    theRule _ = na "rule_Comprehension_Range"


rule_In :: Rule
rule_In = "sequence-in" `namedRule` theRule where
    theRule [essence| &x in &f |] = do
        TypeSequence{} <- typeOf f
        return
            ( "Sequence membership to sequence image."
            , return [essence| &f(&x[1]) = &x[2] |]
            )
    theRule _ = na "rule_In"


rule_Restrict_Image :: Rule
rule_Restrict_Image = "sequence-restrict-image" `namedRule` theRule where
    theRule p = do
        (func', arg) <- match opImage p
        (func , dom) <- match opRestrict func'
        TypeSequence{} <- typeOf func
        return
            ( "Sequence image on a restricted sequence."
            , do
                (iPat, i) <- quantifiedVar
                let bob = [essence| exists &iPat : &dom . &i = &arg |]
                return $ WithLocals (make opImage func arg) (Right [bob])
            )


rule_Restrict_Comprehension :: Rule
rule_Restrict_Comprehension = "sequence-restrict-comprehension" `namedRule` theRule where
    theRule (Comprehension body gensOrConds) = do
        (gofBefore, (iPat, iPatName, expr), gofAfter) <- matchFirst gensOrConds $ \ gof -> case gof of
            Generator (GenInExpr iPat@(Single iPatName) expr) -> return (iPat, iPatName, expr)
            _ -> na "rule_Comprehension_PreImage"
        (func, dom) <- match opRestrict expr
        TypeSequence{} <- typeOf func
        return
            ( "Mapping over restrict(func, dom)"
            , do
                (jPat, j) <- quantifiedVar
                let i = Reference iPatName Nothing
                return $ Comprehension body
                            $  gofBefore
                            ++ [ Generator (GenInExpr iPat func)
                               , Condition [essence| exists &jPat : &dom . &j = &i[1] |]
                               ]
                            ++ gofAfter
            )
    theRule _ = na "rule_Restrict_Comprehension"


-- | image(f,x) can be nasty for non-total sequences.
--   1.   if f is a total sequence, it can readily be replaced by a set expression.
--   2.1. if f isn't total, and if the return type is right, it will always end up as a generator for a comprehension.
--      a vertical rule is needed for such cases.
--   2.2. if the return type is not "right", i.e. it is a bool or an int, i.e. sth we cannot quantify over,
--        the vertical rule is harder.

rule_Image_Bool :: Rule
rule_Image_Bool = "sequence-image-bool" `namedRule` theRule where
    theRule p = do
        let
            onChildren
                :: MonadState (Maybe (Expression, Expression)) m
                => Expression
                -> m (Expression -> Expression)
            onChildren ch = do
                let
                    try = do
                        (func, arg) <- match opImage ch
                        case match opRestrict func of
                            Nothing -> return ()
                            Just{}  -> na "rule_Image_Bool"         -- do not use this rule for restricted sequences
                        TypeSequence TypeBool <- typeOf func
                        return (func, arg)
                case try of
                    Nothing -> return (const ch)        -- do not fail if a child is not of proper form
                    Just (func, arg) -> do              -- just return it back unchanged
                        seenBefore <- gets id
                        case seenBefore of
                            Nothing -> do
                                modify $ const $ Just (func, arg)
                                return id
                            Just{}  ->
                                return (const ch)

        let (children_, gen) = uniplate p
        (genChildren, mFunc) <- runStateT (mapM onChildren children_) Nothing
        let
            mkP :: Expression -> Expression
            mkP new = gen $ fmap ($ new) genChildren
        (func, arg) <- maybe (na "rule_Image_Bool") return mFunc        -- Nothing signifies no relevant children
        return
            ( "Sequence image, bool."
            , do
                (iPat, i) <- quantifiedVar
                return $ mkP $ make opOr $ Comprehension [essence| &i[2] |]
                        [ Generator (GenInExpr iPat func)
                        , Condition [essence| &i[1] = &arg |]
                        ]
            )


rule_Image_Int :: Rule
rule_Image_Int = "sequence-image-int" `namedRule` theRule where
    theRule p = do
        let
            onChildren
                :: MonadState (Maybe (Expression, Expression)) m
                => Expression
                -> m (Expression -> Expression)
            onChildren ch = do
                let
                    try = do
                        (func, arg) <- match opImage ch
                        case match opRestrict func of
                            Nothing -> return ()
                            Just{}  -> na "rule_Image_Int"          -- do not use this rule for restricted sequences
                        TypeSequence TypeInt <- typeOf func
                        return (func, arg)
                case try of
                    Nothing -> return (const ch)        -- do not fail if a child is not of proper form
                    Just (func, arg) -> do              -- just return it back unchanged
                        seenBefore <- gets id
                        case seenBefore of
                            Nothing -> do
                                modify $ const $ Just (func, arg)
                                return id
                            Just{}  ->
                                return (const ch)

        let (children_, gen) = uniplate p
        (genChildren, mFunc) <- runStateT (mapM onChildren children_) Nothing
        let
            mkP :: Expression -> Expression
            mkP new = gen $ fmap ($ new) genChildren
        (func, arg) <- maybe (na "rule_Image_Int") return mFunc         -- Nothing signifies no relevant children
        return
            ( "Sequence image, int."
            , do
                (iPat, i) <- quantifiedVar
                let val = make opSum $ Comprehension [essence| &i[2] |]
                        [ Generator (GenInExpr iPat func)
                        , Condition [essence| &i[1] = &arg |]
                        ]
                    isDefined = [essence| &arg in defined(&func) |]
                return $ mkP $ WithLocals val (Right [isDefined])
            )


rule_Comprehension_Image :: Rule
rule_Comprehension_Image = "sequence-image-comprehension" `namedRule` theRule where
    theRule (Comprehension body gensOrConds) = do
        (gofBefore, (pat, expr), gofAfter) <- matchFirst gensOrConds $ \ gof -> case gof of
            Generator (GenInExpr pat@Single{} expr) -> return (pat, expr)
            _ -> na "rule_Comprehension_Image"
        (mkModifier, expr2) <- match opModifier expr
        (func, arg) <- match opImage expr2
        TypeSequence{} <- typeOf func
        case match opRestrict func of
            Nothing -> return ()
            Just{}  -> na "rule_Image_Bool"         -- do not use this rule for restricted sequences
        let upd val old = lambdaToFunction pat old val
        return
            ( "Mapping over the image of a sequence"
            , do
                (iPat, i) <- quantifiedVar
                (jPat, j) <- quantifiedVar
                return $ Comprehension
                        (upd j body)
                        $  gofBefore
                        ++ [ Generator (GenInExpr iPat (mkModifier func))
                           , Condition [essence| &i[1] = &arg |]
                           , Generator (GenInExpr jPat [essence| &i[2] |])
                           ]
                        ++ transformBi (upd j) gofAfter
            )
    theRule _ = na "rule_Comprehension_Image"


rule_Substring :: Rule
rule_Substring = "substring" `namedRule` theRule where
    theRule [essence| &a substring &b |] = do
        TypeSequence{} <- typeOf a
        TypeSequence{} <- typeOf b

        DomainSequence _ (SequenceAttr aSizeAttr _) _ <- domainOf a
        aMaxSize <- case aSizeAttr of
                    SizeAttr_Size x -> return x
                    SizeAttr_MaxSize x -> return x
                    SizeAttr_MinMaxSize _ x -> return x
                    _ -> fail "rule_Substring maxSize"

        DomainSequence _ (SequenceAttr bSizeAttr _) _ <- domainOf b
        bMaxSize <- case bSizeAttr of
                    SizeAttr_Size x -> return x
                    SizeAttr_MaxSize x -> return x
                    SizeAttr_MinMaxSize _ x -> return x
                    _ -> fail "rule_Substring maxSize"

        let maxSize = [essence| max([&aMaxSize, &bMaxSize]) |]

        return
            ( "Horizontal rule for substring on 2 sequences"
            , do
                (iPat, i) <- quantifiedVar
                (jPat, j) <- quantifiedVar
                return $ make opOr $ Comprehension
                        (make opAnd $ Comprehension
                            [essence| &j[2] = image(&b, &i + &j[1]) |]
                            [ Generator (GenInExpr jPat a)
                            ]
                        )
                        [ Generator (GenDomainNoRepr iPat $ mkDomainIntB 0 [essence| &maxSize - 1 |])]
            )
    theRule _ = na "rule_Substring"


rule_Subsequence :: Rule
rule_Subsequence = "subsequence" `namedRule` theRule where
    theRule [essence| &a subsequence &b |] = do
        TypeSequence{} <- typeOf a
        TypeSequence{} <- typeOf b
 
        DomainSequence _ (SequenceAttr aSizeAttr _) _ <- domainOf a
        aMaxSize <- case aSizeAttr of
                    SizeAttr_Size x -> return x
                    SizeAttr_MaxSize x -> return x
                    SizeAttr_MinMaxSize _ x -> return x
                    _ -> fail "rule_Subsequence maxSize"

        DomainSequence _ (SequenceAttr bSizeAttr _) _ <- domainOf b
        bMaxSize <- case bSizeAttr of
                    SizeAttr_Size x -> return x
                    SizeAttr_MaxSize x -> return x
                    SizeAttr_MinMaxSize _ x -> return x
                    _ -> fail "rule_Subsequence maxSize"

        return
            ( "Horizontal rule for subsequence on 2 sequences"
            , do
                (auxName, aux) <- auxiliaryVar
                (iPat, i) <- quantifiedVar
                return $ WithLocals
                        [essence|
                            and([ &i[2] = image(&b, image(&aux, &i[1]))
                                | &iPat <- &a
                                ])
                        |]
                        (Left [ Declaration (FindOrGiven LocalFind auxName
                                      (DomainSequence def (SequenceAttr aSizeAttr def) (mkDomainIntB 1 bMaxSize)))
                              , SuchThat
                                  [ [essence| and([ image(&aux, &i-1) < image(&aux, &i)
                                                  | &iPat : int(2..&aMaxSize)
                                                  ])
                                    |]
                                  ]
                              ])
            )
    theRule _ = na "rule_Subsequence"