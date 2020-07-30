from dataclasses import dataclass
from abc import ABC, abstractmethod
from .tokenobject import Token
from typing import List


class Expression(ABC):
    """
    An object representing a JAPL expression.
    This is an abstract base class and is not
    meant to be instantiated directly, inherit
    from it instead!
    """


    class Visitor(ABC):
        """
        Visitor abstract base class to implement
        the Visitor pattern
        """

        @abstractmethod
        def accept(self, visitor):
            raise NotImplementedError

        def visit_literal(self, visitor):
            raise NotImplementedError

        def visit_binary(self, visitor):
            raise NotImplementedError

        def visit_grouping(self, visitor):
            raise NotImplementedError

        def visit_unary(self, visitor):
            raise NotImplementedError

@dataclass
class Binary(Expression, Expression.Visitor):
    left: Expression
    operator: Token
    right: Expression

    def accept(self, visitor):
        return visitor.visit_binary(self)


@dataclass
class Unary(Expression, Expression.Visitor):
    operator: Token
    right: Expression

    def accept(self, visitor):
        return visitor.visit_unary(self)


@dataclass
class Literal(Expression, Expression.Visitor):
    value: object

    def accept(self, visitor):
        return visitor.visit_literal(self)


@dataclass
class Grouping(Expression, Expression.Visitor):
    expr: Expression

    def accept(self, visitor):
        return visitor.visit_grouping(self)


@dataclass
class Variable(Expression, Expression.Visitor):
    name: Token

    def accept(self, visitor):
        return visitor.visit_var_expr(self)

    def __hash__(self):
        return hash(self.name.lexeme)

@dataclass
class Assignment(Expression, Expression.Visitor):
    name: Token
    value: Expression


    def accept(self, visitor):
        return visitor.visit_assign(self)

    def __hash__(self):
        return hash(self.name.lexeme)

@dataclass
class Logical(Expression, Expression.Visitor):
    left: Expression
    operator: Token
    right: Expression

    def accept(self, visitor):
        return visitor.visit_logical(self)


@dataclass
class Call(Expression, Expression.Visitor):
    callee: Expression
    paren: Token
    arguments: List[Expression] = ()

    def accept(self, visitor):
        return visitor.visit_call_expr(self)
