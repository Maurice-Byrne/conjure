
module Conjure.Language.AST.Syntax where

import Conjure.Language.NewLexer (ETok)
import Conjure.Prelude

data LToken
    = RealToken ETok
    | MissingToken ETok
    | SkippedToken ETok
    deriving (Eq, Ord)

instance Show LToken where
    show (RealToken x) = show x
    show (MissingToken x) = "MISSING[" ++ show x ++ "]"
    show (SkippedToken x) = "SKIPPED[" ++ show x ++ "]"

newtype ProgramTree = ProgramTree [StatementNode]

instance Show ProgramTree where
    show (ProgramTree  x) = intercalate "\n" (map show x)

data StatementNode
    = Declaration DeclarationStatementNode
    | Branching BranchingStatementNode
    | SuchThat SuchThatStatementNode
    | Where WhereStatementNode
    | Objective ObjectiveStatementNode
    deriving (Show)

data SuchThatStatementNode
    = SuchThatStatementNode
        LToken -- Such
        LToken -- That
        (Sequence ExpressionNode) -- constraints
    deriving (Show)

data WhereStatementNode
    = WhereStatementNode
        LToken -- where
        (Sequence ExpressionNode) -- expresssions
    deriving (Show)

data ObjectiveStatementNode
    = ObjectiveMin LToken ExpressionNode
    | ObjectiveMax LToken ExpressionNode
    deriving (Show)

-- Declaration statements
data DeclarationStatementNode
    = FindStatement FindStatementNode
    | GivenStatement GivenStatementNode
    | LettingStatement LettingStatementNode
    deriving (Show)

data FindStatementNode
    = FindStatementNode
        LToken -- find
        (Sequence NameNode) -- names
        LToken -- colon
        DomainNode -- domain
    deriving (Show)

data GivenStatementNode
    = GivenStatementNode
        LToken -- given
        (Sequence NameNode) -- name
        LToken -- colon
        DomainNode -- domain
    | GivenEnumNode
        LToken
        (Sequence NameNode)
        LToken -- new
        LToken -- type
        LToken -- enum
    deriving (Show)

data LettingStatementNode
    = LettingExpr
        LToken -- lLetting
        (Sequence NameNode) -- name
        LToken -- lBe
        ExpressionNode
    | LettingDomain
        LToken -- lLetting
        (Sequence NameNode) -- name
        LToken -- lBe
        LToken -- domain
        DomainNode
    | LettingEnum
        LToken -- lLetting
        (Sequence NameNode) -- name
        LToken -- lBe
        LToken -- lNew
        LToken -- lType
        LToken -- lEnum
        (ListNode NameNode) -- nameList
    | LettingAnon
        LToken -- lLettingAnon
        (Sequence NameNode) -- name
        LToken -- lBe
        LToken -- lNew
        LToken -- lType
        LToken -- lOf
        LToken -- lSize
        ExpressionNode -- expr
    deriving (Show)

-- Branching on

data BranchingStatementNode
    = BranchingStatementNode
        LToken
        LToken
        (ListNode BranchingOnNode)
    deriving (Show)

data BranchingOnNode = BranchingOnName NameNode | BranchingOnExpression ExpressionNode
    deriving (Show)

-- Domains

data DomainNode
    = BoolDomainNode LToken
    | RangedIntDomainNode LToken (ListNode RangeNode)
    | RangedEnumNode NameNode (ListNode RangeNode)
    | EnumDomainNode NameNode
    | TupleDomainNode LToken (ListNode DomainNode)
    | RecordDomainNode LToken (ListNode NamedDomainNode)
    | VariantDomainNode LToken (ListNode NamedDomainNode)
    | MatrixDomainNode LToken LToken LToken (ListNode DomainNode) LToken DomainNode
    | SetDomainNode LToken (ListNode AttributeNode) LToken DomainNode
    | MSetDomainNode LToken (ListNode AttributeNode) LToken DomainNode
    | FunctionDomainNode LToken (ListNode AttributeNode) DomainNode LToken DomainNode
    | SequenceDomainNode LToken (ListNode AttributeNode) LToken DomainNode
    | RelationDomainNode LToken (ListNode AttributeNode) LToken (ListNode DomainNode)
    | PartitionDomainNode LToken (ListNode AttributeNode) LToken DomainNode
    | MissingDomainNode LToken
    deriving (Show)

data RangeNode
    = SingleRangeNode ExpressionNode
    | OpenRangeNode DoubleDotNode
    | RightUnboundedRangeNode ExpressionNode DoubleDotNode
    | LeftUnboundedRangeNode DoubleDotNode ExpressionNode
    | BoundedRangeNode ExpressionNode DoubleDotNode ExpressionNode
    deriving (Show)

data DoubleDotNode = DoubleDotNode LToken LToken deriving (Show)

data AttributeNode = NamedAttributeNode NameNode | NamedExpressionAttribute NameNode ExpressionNode
    deriving (Show)

data NamedDomainNode = NameDomainNode NameNode LToken DomainNode
    deriving (Show)

-- Common Statements

newtype NameNode = NameNode LToken
    deriving (Show)

-- Expressions
data ExpressionNode
    = Literal LiteralNode
    | IdentifierNode NameNode
    | QuantificationExpr QuantificationExpressionNode
    | ComprehensionExpr ComprehensionExpressionNode
    | OperatorExpressionNode OperatorExpressionNode
    | ParenExpression ParenExpressionNode
    | AbsExpression ParenExpressionNode
    | FunctionalApplicationNode LToken (ListNode ExpressionNode)
    | MissingExpressionNode LToken
    deriving (Show)

data ParenExpressionNode = ParenExpressionNode LToken ExpressionNode LToken
    deriving (Show)

newtype ShortTuple = ShortTuple (ListNode ExpressionNode) deriving (Show)

data LongTuple = LongTuple LToken (ListNode ExpressionNode) deriving (Show)

-- Literals
data LiteralNode
    = IntLiteral LToken
    | BoolLiteral LToken
    | MatrixLiteral MatrixLiteralNode
    | TupleLiteralNode LongTuple
    | TupleLiteralNodeShort ShortTuple
    | RecordLiteral LToken (ListNode RecordMemberNode)
    | VariantLiteral LToken (ListNode RecordMemberNode) --catch later
    | SetLiteral (ListNode ExpressionNode)
    | MSetLiteral LToken (ListNode ExpressionNode)
    | FunctionLiteral LToken (ListNode ArrowPairNode)
    | SequenceLiteral LToken (ListNode ExpressionNode)
    | RelationLiteral LToken (ListNode RelationElemNode)
    | PartitionLiteral LToken (ListNode PartitionElemNode)
    deriving (Show)

data MatrixLiteralNode
    = MatrixLiteralExplicitDomain (ListNode ExpressionNode) LToken DomainNode
    | MatrixLiteralImplicitDomain (ListNode ExpressionNode)
    deriving (Show)

data RecordMemberNode = RecordMemberNode NameNode LToken ExpressionNode
    deriving (Show)

data ArrowPairNode = ArrowPairNode ExpressionNode LToken ExpressionNode
    deriving (Show)

data RelationElemNode
    = RelationElemNodeLabeled LongTuple
    | RelationElemNodeShort ShortTuple
    deriving (Show)

newtype PartitionElemNode = PartitionElemNode (ListNode ExpressionNode)
    deriving (Show)

data QuantificationExpressionNode
    = QuantificationExpressionNode
        LToken
        (Sequence QuantificationPattern)
        LToken
        ExpressionNode
    deriving (Show) -- MAYBE?

data QuantificationPattern =
    QuantificationPattern ExpressionNode
    deriving (Show)

data ComprehensionExpressionNode
    = ComprehensionExpressionNode
        LToken
        ExpressionNode
        LToken
        (Sequence ComprehensionBodyNode)
        LToken
    deriving (Show)

data ComprehensionBodyNode
    = CompBodyCondition ExpressionNode
    | CompBodyDomain NamedDomainNode
    | CompBodyLettingNode LToken NameNode LToken ExpressionNode
    deriving (Show)

data OperatorExpressionNode
    = PostfixOpNode ExpressionNode PostfixOpNode
    | PrefixOpNode LToken ExpressionNode
    | BinaryOpNode ExpressionNode LToken ExpressionNode
    deriving (Show)


data PostfixOpNode
    = IndexedNode LToken IndexerNode LToken
    | OpFactorial  LToken
    | ApplicationNode (ListNode ExpressionNode)
    deriving (Show)

-- data FunctionApplicationNode 
--     = FunctionApplicationNode LToken (ListNode ExpressionNode) 

data IndexerNode
    = Indexer
    deriving (Show)
data ListNode itemType = ListNode
    { lOpBracket :: LToken
    , items :: Sequence itemType
    , lClBracket :: LToken
    }
    deriving (Show)

newtype Sequence itemType = Seq
    { elems :: [SeqElem itemType]
    }

-- deriving (Show)
instance (Show a) => Show (Sequence a) where
    show (Seq e) = "Seq:\n" ++ intercalate "\n\t" (map show e) ++ "\n"

data SeqElem itemType = SeqElem
    { item :: itemType
    , separator :: Maybe LToken
    }
    deriving (Show)
