from abc import ABC, abstractmethod
from dataclasses import dataclass
from .expression import Expression
from .tokenobject import Token
from typing import List


class Statement(ABC):
    """
    An Abstract Base Class representing
    JAPL's statements
    """

    class Visitor(ABC):
        """Wrapper to implement the Visitor Pattern"""

        @abstractmethod
        def accept(self, visitor):
            raise NotImplementedError

        def visit_print(self, visitor):
            raise NotImplementedError

        def visit_expr(self, visitor):
            raise NotImplementedError


@dataclass
class Print(Statement, Statement.Visitor):
    """
    The print statement
    """

    expression: Expression

    def accept(self, visitor):
        visitor.visit_print(self)

@dataclass
class StatementExpr(Statement, Statement.Visitor):
    """
    An expression statement
    """

    expression: Expression

    def accept(self, visitor):
        visitor.visit_statement_expr(self)


@dataclass
class Var(Statement, Statement.Visitor):
    """
    A var statement
    """

    name: Token
    init: Expression = None

    def accept(self, visitor):
        visitor.visit_var_stmt(self)


@dataclass
class Del(Statement, Statement.Visitor):
    """
    A del statement
    """

    name: Token

    def accept(self, visitor):
        visitor.visit_del(self)


@dataclass
class Block(Statement, Statement.Visitor):
    """A block statement"""

    statements: List[Statement]

    def accept(self, visitor):
        visitor.visit_block(self)

@dataclass
class If(Statement, Statement.Visitor):
    """An if statement"""

    condition: Expression
    then_branch: Statement
    else_branch: Statement

    def accept(self, visitor):
        visitor.visit_if(self)


@dataclass
class While(Statement, Statement.Visitor):
    """A while statement"""

    condition: Expression
    body: Statement

    def accept(self, visitor):
        visitor.visit_while(self)

@dataclass
class Break(Statement, Statement.Visitor):
    """A break statement"""

    token: Token

    def accept(self, visitor):
        visitor.visit_break(self)

@dataclass
class Function(Statement, Statement.Visitor):
    """A function statement"""

    name: Token
    params: List[Token]
    body: List[Statement]

    def accept(self, visitor):
        visitor.visit_function(self)


@dataclass
class Return(Statement, Statement.Visitor, BaseException):
    """A return statement"""

    keyword: Token
    value: Expression

    def accept(self, visitor):
        visitor.visit_return(self)
