from .meta.exceptions import JAPLError
from .meta.expression import Expression
from .meta.statement import Statement
from .meta.functiontype import FunctionType
from .meta.classtype import ClassType
from .meta.looptype import LoopType
try:
    from functools import singledispatchmethod
except ImportError:
    from singledispatchmethod import singledispatchmethod   # Backport
from typing import List, Union
from collections import deque


class Resolver(Expression.Visitor, Statement.Visitor):
    """
    This class serves the purpose of correctly resolving
    name bindings (even with closures) efficiently
    """

    def __init__(self, interpreter):
        """
        Object constructor
        """

        self.interpreter = interpreter
        self.scopes = deque()
        self.current_function = FunctionType.NONE
        self.current_loop = LoopType.NONE
        self.current_class = ClassType.NONE

    @singledispatchmethod
    def resolve(self, stmt_or_expr: Union[Statement, Expression, List[Statement]]):
        """Generic method to dispatch statements/expressions"""

        raise NotImplementedError

    def begin_scope(self):
        """
        Opens a new scope
        """

        self.scopes.append({})

    def end_scope(self):
        """
        Ends a scope
        """

        self.scopes.pop()

    @resolve.register
    def resolve_statement(self, stmt: Statement):
        """
        Resolves names for the given group
        of statements
        """

        stmt.accept(self)

    @resolve.register
    def resolve_expression(self, expression: Expression):
        """
        Resolves an expression
        """

        return expression.accept(self)

    @resolve.register
    def resolve_statements(self, stmt: list):
        """Resolves multiple statements"""

        for statement in stmt:
            self.resolve(statement)

    def declare(self, name):
        """
        Declares a new variable
        """

        if not self.scopes:
            return
        scope = self.scopes[-1]
        if name.lexeme in scope:
            raise JAPLError(name, "Cannot re-declare the same variable in local scope, use assignment instead")
        scope[name.lexeme] = False

    def define(self, name):
        """
        Defines a new variable
        """

        if not self.scopes:
            return
        scope = self.scopes[-1]
        scope[name.lexeme] = True

    def visit_block(self, block):
        """Starts name resolution on a given block"""

        self.begin_scope()
        self.resolve(block.statements)
        self.end_scope()

    def visit_var_stmt(self, stmt):
        """Visits a var statement node"""

        self.declare(stmt.name)
        if stmt.init:
            self.resolve(stmt.init)
        self.define(stmt.name)

    def visit_var_expr(self, expr):
        """Visits a var expression node"""

        if self.scopes and self.scopes[-1].get(expr.name.lexeme) is False:
            raise JAPLError(expr.name, f"Cannot read local variable in its own initializer")
        self.resolve_local(expr, expr.name)

    def resolve_local(self, expr, name):
        """Resolves local variables"""

        i = 0
        for scope in reversed(self.scopes):
            if name.lexeme in scope:
                self.interpreter.resolve(expr, i)
            i += 1

    def resolve_function(self, function, function_type: FunctionType):
        """Resolves function objects"""

        enclosing = self.current_function
        self.current_function = function_type
        self.begin_scope()
        for param in function.params:
            self.declare(param)
            self.define(param)
        self.resolve(function.body)
        self.end_scope()
        self.current_function = enclosing

    def visit_assign(self, expr):
        """Visits an assignment expression"""

        self.resolve(expr.value)
        self.resolve_local(expr, expr.name)

    def visit_function(self, stmt):
        """Visits a function statement"""

        self.declare(stmt.name)
        self.define(stmt.name)
        self.resolve_function(stmt, FunctionType.FUNCTION)

    def visit_class(self, stmt):
        """Visits a class statement"""

        enclosing = self.current_class
        self.current_class = ClassType.CLASS
        self.declare(stmt.name)
        self.define(stmt.name)
        if stmt.superclass:
            if stmt.superclass.name.lexeme == stmt.name.lexeme:
                raise JAPLError(stmt.name, "A class cannot inherit from itself")
            self.resolve(stmt.superclass)
            self.begin_scope()
            self.scopes[-1]["super"] = True
        self.begin_scope()
        self.scopes[-1]["this"] = True
        for method in stmt.methods:
            ftype = FunctionType.METHOD
            if method.name.lexeme == "init":
                ftype = FunctionType.INIT
            self.resolve_function(method, ftype)
        self.end_scope()
        if stmt.superclass:
            self.end_scope()
        self.current_class = enclosing

    def visit_statement_expr(self, stmt):
        """Visits a statement expression node"""

        self.resolve(stmt.expression)

    def visit_if(self, stmt):
        """Visits an if statement node"""

        self.resolve(stmt.condition)
        self.resolve(stmt.then_branch)
        if stmt.else_branch:
            self.resolve(stmt.else_branch)

    def visit_return(self, stmt):
        """Visits a return statement node"""

        if self.current_function == FunctionType.NONE:
            raise JAPLError(stmt.keyword, "'return' outside function")
        elif self.current_function == FunctionType.INIT:
            raise JAPLError(stmt.keyword, "Cannot explicitly return from constructor")
        elif stmt.value is not None:
            self.resolve(stmt.value)

    def visit_while(self, stmt):
        """Visits a while statement node"""

        loop = self.current_loop
        self.current_loop = LoopType.WHILE
        self.resolve(stmt.condition)
        self.resolve(stmt.body)
        self.current_loop = loop

    def visit_binary(self, expr):
        """Visits a binary expression node"""

        self.resolve(expr.left)
        self.resolve(expr.right)

    def visit_call_expr(self, expr):
        """Visits a call expression node"""

        self.resolve(expr.callee)
        for argument in expr.arguments:
            self.resolve(argument)

    def visit_grouping(self, expr):
        """Visits a grouping expression"""

        self.resolve(expr.expr)

    def visit_literal(self, expr):
        """Visits a literal node"""

        return   # Literal has no subexpressions and does not reference variables

    def visit_logical(self, expr):
        """Visits a logical node"""

        self.visit_binary(expr)   # No need to short circuit, so it's the same!

    def visit_unary(self, expr):
        """Visits a unary node"""

        self.resolve(expr.right)

    def visit_del(self, stmt):
        """Visits a del statement"""

        self.resolve(stmt.name)

    def visit_break(self, stmt):
        """Visits a break statement"""

        if self.current_loop == LoopType.NONE:
            raise JAPLError("'break' outside loop")

    def visit_get(self, expr):
        """Visits a property get expression"""

        self.resolve(expr.object)

    def visit_set(self, expr):
        """Visits a property set expression"""

        self.resolve(expr.value)
        self.resolve(expr.object)

    def visit_this(self, expr):
        """Visits a 'this' expression"""

        if self.current_class == ClassType.NONE:
            raise JAPLError(expr.keyword, "'this' outside class")
        self.resolve_local(expr, expr.keyword)

    def visit_super(self, expr):
        """Visits a 'super' expression"""

        if self.current_class == ClassType.NONE:
            raise JAPLError(expr.keyword, "'super' outside class")
        self.resolve_local(expr, expr.keyword)


