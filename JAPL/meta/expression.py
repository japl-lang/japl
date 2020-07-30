from dataclasses import dataclass
from abc import ABC, abstractmethod
from .tokenobject import Token
from typing import List


class Expression(object):
    """
    An object representing a JAPL expression.
    This class is not meant to be instantiated directly,
    inherit from it instead!
    """

    def accept(self, visitor):
        raise NotImplementedError

    class Visitor(ABC):
        """
        Visitor abstract base class to implement
        the Visitor pattern
        """

        @abstractmethod
        def visit_literal(self, visitor):
            raise NotImplementedError

        @abstractmethod
        def visit_binary(self, visitor):
            raise NotImplementedError

        @abstractmethod
        def visit_grouping(self, visitor):
            raise NotImplementedError

        @abstractmethod
        def visit_unary(self, visitor):
            raise NotImplementedError


@dataclass
class Binary(Expression):
    left: Expression
    operator: Token
    right: Expression

    def accept(self, visitor):
        return visitor.visit_binary(self)


@dataclass
class Unary(Expression):
    operator: Token
    right: Expression

    def accept(self, visitor):
        return visitor.visit_unary(self)


@dataclass
class Literal(Expression):
    value: object

    def accept(self, visitor):
        return visitor.visit_literal(self)


@dataclass
class Grouping(Expression):
    expr: Expression

    def accept(self, visitor):
        return visitor.visit_grouping(self)


@dataclass
class Variable(Expression):
    name: Token

    def accept(self, visitor):
        return visitor.visit_var_expr(self)

    def __hash__(self):
        return super().__hash__()


@dataclass
class Assignment(Expression):
    name: Token
    value: Expression

    def accept(self, visitor):
        return visitor.visit_assign(self)

    def __hash__(self):
        return super().__hash__()

@dataclass
class Logical(Expression):
    left: Expression
    operator: Token
    right: Expression

    def accept(self, visitor):
        return visitor.visit_logical(self)


@dataclass
class Call(Expression):
    callee: Expression
    paren: Token
    arguments: List[Expression] = ()

    def accept(self, visitor):
        return visitor.visit_call_expr(self)
