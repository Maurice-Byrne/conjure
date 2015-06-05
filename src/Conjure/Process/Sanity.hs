module Conjure.Process.Sanity ( sanityChecks ) where

import Conjure.Prelude
import Conjure.UserError
import Conjure.Language.Definition
import Conjure.Language.Domain
import Conjure.Language.Pretty
import Conjure.Language.CategoryOf


sanityChecks :: MonadUserError m => Model -> m Model
sanityChecks model = do
    let
        recordErr :: MonadWriter [Doc] m => [Doc] -> m ()
        recordErr = tell . return . vcat

        check :: MonadWriter [Doc] m => Model -> m ()
        check m = do
            forM_ (mStatements m) $ \ st -> case st of
                Declaration FindOrGiven{} -> mapM_ (checkDomain (Just st)) (universeBi st)
                _                         -> mapM_ (checkDomain Nothing  ) (universeBi st)
            forM_ (universeBi m) checkLit

        -- check for mset attributes
        -- check for binary relation attrobutes
        checkDomain :: MonadWriter [Doc] m => (Maybe Statement) -> Domain () Expression -> m ()
        checkDomain mstmt domain = case domain of
            DomainMSet _ (MSetAttr size occur) _ ->
                case (size, occur) of
                    (SizeAttr_Size{}, _) -> return ()
                    (SizeAttr_MaxSize{}, _) -> return ()
                    (SizeAttr_MinMaxSize{}, _) -> return ()
                    (_, OccurAttr_MaxOccur{}) -> return ()
                    (_, OccurAttr_MinMaxOccur{}) -> return ()
                    _ -> recordErr
                        [ "mset requires (at least) one of the following attributes: size, maxSize, maxOccur"
                        , "When working on:" <++> maybe (pretty domain) pretty mstmt
                        ]
            DomainRelation _ (RelationAttr _ binRelAttr) [a,b]
                | binRelAttr /= def && a /= b
                -> recordErr
                        [ "Binary relation attributes can only be used for binary relation between identical domains."
                        , "Either remove these attributes:" <+> pretty binRelAttr
                        , "Or make sure that the relation is between identical domains."
                        , "When working on:" <++> maybe (pretty domain) pretty mstmt
                        ]
            DomainRelation _ (RelationAttr _ binRelAttr) innerDoms
                | binRelAttr /= def && length innerDoms /= 2
                -> recordErr
                        [ "Binary relation attributes can only be used on binary relations."
                        , "Either remove these attributes:" <+> pretty binRelAttr
                        , "Or make sure that the relation is binary."
                        , "When working on:" <++> maybe (pretty domain) pretty mstmt
                        ]
            _ -> return ()

        -- check for function literals
        --     they cannot contain anything > CatParameter
        --     they cannot map the same element to multiple range elemnets
        -- check for partition literals
        --     they cannot contain anything > CatParameter
        --     the parts have to be disjoint
        -- TODO: Generate where clauses for when they contain parameters.
        checkLit :: MonadWriter [Doc] m => Expression -> m ()
        checkLit lit = case lit of
            AbstractLiteral (AbsLitFunction mappings) -> do
                when (categoryOf lit > CatParameter) $ recordErr
                    [ "A function literal may only contain constants or parameters."
                    , "When working on:" <++> pretty lit
                    ]
                let definedSet = map fst (nub mappings)
                let definedSetNoDups = nub definedSet
                when (length definedSet /= length definedSetNoDups) $ recordErr
                    [ "A function literal can not map one element to multiple range elements."
                    , "When working on:" <++> pretty lit
                    ]
            AbstractLiteral (AbsLitPartition parts) -> do
                when (categoryOf lit > CatParameter) $ recordErr
                    [ "A partition literal may only contain constants or parameters."
                    , "When working on:" <++> pretty lit
                    ]
                let disjoint = and [ null (intersect part1 part2)
                                   | (part1, after) <- withAfter parts
                                   , part2 <- after
                                   ]
                unless disjoint $ recordErr
                    [ "A partition literal has to contain disjoint parts."
                    , "When working on:" <++> pretty lit
                    ]
            _ -> return ()

    errs <- execWriterT $ check model
    if null errs
        then return model
        else userErr errs
