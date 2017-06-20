{-
 - Module      : Conjure.Process.StrengthenVariables
 - Description : Strengthen variables using type- and domain-inference.
 - Copyright   : Billy Brown 2017
 - License     : BSD3
 
 Processing step that attempts to strengthen variables at the Essence class level, using methods described in the "Reformulating Essence Specifications for Robustness" paper.
-}

module Conjure.Process.StrengthenVariables
  (
    strengthenVariables
  ) where

import Conjure.Prelude
import Conjure.Language
import Conjure.Language.NameResolution ( resolveNames )
-- These two are needed together
import Conjure.Language.Expression.DomainSizeOf ()
import Conjure.Language.DomainSizeOf ( domainSizeOf )

-- | Strengthen the variables in a model using type- and domain-inference.
strengthenVariables :: (MonadFail m, MonadLog m, MonadUserError m)
                    => Model -> m Model
strengthenVariables = runNameGen . (resolveNames >=> core)
  where core model = do model' <- foldM folded model [ functionAttributes
                                                     ]
                        if model == model'
                           then return model'
                           else core model'
        -- Apply the function to every statement and fold it into the model
        folded m@Model { mStatements = stmts } f
          = foldM (\m' s -> do
                    s' <- f m s
                    -- This is map, but unwraps the value from the monad
                    return m' { mStatements = s' : mStatements m' })
                  m { mStatements = [] }
                  (reverse stmts)

-- | Make the attributes of function variables as constrictive as possible.
functionAttributes :: (MonadFail m, MonadLog m)
                   => Model       -- ^ Model as context.
                   -> Statement   -- ^ Statement to constrain.
                   -> m Statement -- ^ Possibly updated statement.
functionAttributes m (Declaration (FindOrGiven forg n d@DomainFunction{})) = do
  d' <- constrainFunctionDomain d m
  return $ Declaration (FindOrGiven forg n d')
functionAttributes m (Declaration (Letting n (Domain d@DomainFunction{}))) = do
  d' <- constrainFunctionDomain d m
  return $ Declaration (Letting n (Domain d'))
functionAttributes _ s = return s

-- | Constrain the domain of a function given the context of a model.
constrainFunctionDomain :: (MonadFail m, MonadLog m)
                        => Domain () Expression     -- ^ Current domain of the function.
                        -> Model                    -- ^ Context of the model.
                        -> m (Domain () Expression) -- ^ Possibly modified domain.
constrainFunctionDomain d@(DomainFunction r attrs from to) _
  = case attrs of
         -- If a function is surjective or bijective and its domain and codomain
         -- are of equal size, then it is total and bijective
         FunctionAttr s PartialityAttr_Partial JectivityAttr_Surjective ->
           totalAndBijectiveDomainComparison s
         FunctionAttr s PartialityAttr_Partial JectivityAttr_Bijective  ->
           totalAndBijectiveDomainComparison s
         _ -> return d
    where totalAndBijectiveDomainComparison s
            = case domainSizeOf from of
                   Left  e        -> logInfo e >> return d
                   Right fromSize ->
                     case domainSizeOf to :: Either Doc Expression of
                          Left  e      -> logInfo e >> return d
                          Right toSize ->
                            if fromSize == toSize
                               then return $ DomainFunction r (FunctionAttr s PartialityAttr_Total JectivityAttr_Bijective) from to
                               else return d
constrainFunctionDomain d _ = return d
