from abc import ABC, abstractmethod
from dataclasses import dataclass
from .expression import Expression, Variable
from .tokenobject import Token
from typing import List, Any


class Statement(object):
    """
    A Base Class representing JAPL statements
    """

    def accept(self, visitor):
        raise NotImplementedError

    class Visitor(ABC):
        """Wrapper to implement the Visitor Pattern"""


        @abstractmethod
        def visit_statement_expr(self, visitor):
            raise NotImplementedError

        @abstractmethod
        def visit_var_stmt(self, visitor):
            raise NotImplementedError

        @abstractmethod
        def visit_del(self, visitor):
            raise NotImplementedError

        @abstractmethod
        def visit_block(self, visitor):
            raise NotImplementedError

        @abstractmethod
        def visit_if(self, visitor):
            raise NotImplementedError

        @abstractmethod
        def visit_while(self, visitor):
            raise NotImplementedError

        @abstractmethod
        def visit_break(self, visitor):
            raise NotImplementedError

        @abstractmethod
        def visit_function(self, visitor):
            raise NotImplementedError

        @abstractmethod
        def visit_return(self, visitor):
            raise NotImplementedError

        @staticmethod
        def visit_class(self, visitor):
            raise NotImplementedError


@dataclass
class StatementExpr(Statement):
    """
    An expression statement
    """

    expression: Expression

    def accept(self, visitor):
        visitor.visit_statement_expr(self)


@dataclass
class Var(Statement):
    """
    A var statement
    """

    name: Token
    init: Expression = None

    def accept(self, visitor):
        visitor.visit_var_stmt(self)


@dataclass
class Del(Statement):
    """
    A del statement
    """

    name: Any

    def accept(self, visitor):
        visitor.visit_del(self)


@dataclass
class Block(Statement):
    """A block statement"""

    statements: List[Statement]

    def accept(self, visitor):
        visitor.visit_block(self)


@dataclass
class If(Statement):
    """An if statement"""

    condition: Expression
    then_branch: Statement
    else_branch: Statement

    def accept(self, visitor):
        visitor.visit_if(self)


@dataclass
class While(Statement):
    """A while statement"""

    condition: Expression
    body: Statement

    def accept(self, visitor):
        visitor.visit_while(self)


@dataclass
class Break(Statement):
    """A break statement"""

    token: Token

    def accept(self, visitor):
        visitor.visit_break(self)


@dataclass
class Function(Statement):
    """A function statement"""

    name: Token
    params: List[Token]
    body: List[Statement]

    def accept(self, visitor):
        visitor.visit_function(self)


@dataclass
class Return(Statement, BaseException):
    """A return statement"""

    keyword: Token
    value: Expression

    def accept(self, visitor):
        visitor.visit_return(self)


@dataclass
class Class(Statement):
    """A class statement"""

    name: Token
    methods: list
    superclass: Variable

    def accept(self, visitor):
        visitor.visit_class(self)
