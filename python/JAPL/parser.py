from .meta.exceptions import ParseError
from .meta.tokentype import TokenType
from .meta.tokenobject import Token
from typing import List, Union
from .meta.expression import Variable, Assignment, Logical, Call, Binary, Unary, Literal, Grouping, Expression, Get, Set, This, Super
from .meta.statement import StatementExpr, Var, Del, Block, If, While, Break, Function, Return, Class


class Parser(object):
    """A simple recursive-descent top-down parser"""

    def __init__(self, tokens: List[Token]):
        """Object constructor"""

        self.tokens = tokens
        self.current: int = 0

    def check(self, token_type):
        """
        Helper method for self.match
        """

        if self.done():
            return False
        elif self.peek().kind == token_type:
            return True
        return False

    def throw(self, token: Token, message: str) -> ParseError:
        """Returns ParseError with the given message"""

        return ParseError(token, message)

    def synchronize(self):
        """Synchronizes the parser's state to recover after
           an error occurred while parsing"""

        self.step()
        while not self.done():
            if self.previous().kind == TokenType.SEMICOLON:
                break
            else:
                token_type = self.peek().kind
                if token_type in (
                        TokenType.IF, TokenType.CLASS, TokenType.VAR, TokenType.FOR, TokenType.WHILE,
                        TokenType.RETURN, TokenType.FUN
                ):
                    return
            self.step()

    def peek(self):
        """
        Returns a token without consuming it
        """

        return self.tokens[self.current]

    def previous(self):
        """
        Returns the most recently consumed token
        """

        return self.tokens[self.current - 1]

    def done(self):
        """
        Returns True if we reached EOF
        """

        return self.peek().kind == TokenType.EOF

    def match(self, *types: Union[TokenType, List[TokenType]]):
        """
        Checks if the current token matches
        any of the given token type(s)
        """

        for token_type in types:
            if self.check(token_type):
                self.step()
                return True
        return False

    def consume(self, token_type, message: str):
        """
        Consumes a token, raises an error
        with the given message if the current token
        differs from the expected one
        """

        if self.check(token_type):
            return self.step()
        raise self.throw(self.peek(), message)

    def primary(self):
        """Parses unary expressions (literals)"""

        if self.match(TokenType.FALSE):
            return Literal(False)
        elif self.match(TokenType.TRUE):
            return Literal(True)
        elif self.match(TokenType.NIL):
            return Literal(None)
        elif self.match(TokenType.NUM, TokenType.STR):
            return Literal(self.previous().literal)
        elif self.match(TokenType.LP):
            expr: Expression = self.expression()
            self.consume(TokenType.RP, "Unexpected error while parsing parenthesized expression")
            return Grouping(expr)
        elif self.match(TokenType.ID):
            return Variable(self.previous())
        elif self.match(TokenType.SUPER):
            keyword = self.previous()
            self.consume(TokenType.DOT, "Expecting '.' after 'super'")
            method = self.consume(TokenType.ID, "Expecting superclass method name")
            return Super(keyword, method)
        elif self.match(TokenType.THIS):
            return This(self.previous())
        raise self.throw(self.peek(), "Invalid syntax")

    def finish_call(self, callee):
        """Parses a function call"""

        arguments = []
        if not self.check(TokenType.RP):
            while True:
                if len(arguments) >= 255:
                    raise self.throw(self.peek(), "Cannot have more than 255 arguments")
                arguments.append(self.expression())
                if not self.match(TokenType.COMMA):
                    break
        paren = self.consume(TokenType.RP, "Unexpected error while parsing call")
        return Call(callee, paren, arguments)

    def call(self):
        """Parses call expressions"""

        expr = self.primary()
        while True:
            if self.match(TokenType.LP):
                expr = self.finish_call(expr)
            elif self.match(TokenType.DOT):
               name = self.consume(TokenType.ID, "Expecting property after '.'")
               expr = Get(expr, name)
            else:
                break
        return expr

    def unary(self):
        """Parses unary expressions"""

        if self.match(TokenType.NEG, TokenType.MINUS):
            operator: Token = self.previous()
            right: Expression = self.unary()
            return Unary(operator, right)
        return self.call()

    def pow(self):
        """Parses pow expressions"""

        expr: Expression = self.unary()
        while self.match(TokenType.POW):
            operator: Token = self.previous()
            right: Expression = self.unary()
            expr = Binary(expr, operator, right)
        return expr

    def multiplication(self):
        """
        Parses multiplications and divisions
        """

        expr: Expression = self.pow()
        while self.match(TokenType.STAR, TokenType.SLASH, TokenType.MOD):
            operator: Token = self.previous()
            right: Expression = self.pow()
            expr = Binary(expr, operator, right)
        return expr

    def addition(self):
        """
        Parses additions and subtractions
        """

        expr: Expression = self.multiplication()
        while self.match(TokenType.PLUS, TokenType.MINUS):
            operator: Token = self.previous()
            right: Expression = self.multiplication()
            expr = Binary(expr, operator, right)
        return expr

    def comparison(self):
        """
        Parses comparison expressions
        """

        expr: Expression = self.addition()
        while self.match(TokenType.GT, TokenType.GE, TokenType.LT, TokenType.LE, TokenType.NE):
            operator: Token = self.previous()
            right: Expression = self.addition()
            expr = Binary(expr, operator, right)
        return expr

    def equality(self):
        """
        Parses equality expressions
        """

        expr: Expression = self.comparison()
        while self.match(TokenType.NEG, TokenType.DEQ):
            operator: Token = self.previous()
            right: Expression = self.comparison()
            expr = Binary(expr, operator, right)
        return expr

    def logical_and(self):
        """Parses a logical and expression"""

        expr = self.equality()
        while self.match(TokenType.AND):
            operator = self.previous()
            right = self.equality()
            expr = Logical(expr, operator, right)
        return expr

    def logical_or(self):
        """Parses a logical or expression"""

        expr = self.logical_and()
        while self.match(TokenType.OR):
            operator = self.previous()
            right = self.logical_and()
            expr = Logical(expr, operator, right)
        return expr

    def assignment(self):
        """
        Parses an assignment expression
        """

        expr = self.logical_or()
        if self.match(TokenType.EQ):
            eq = self.previous()
            value = self.assignment()
            if isinstance(expr, Variable):
                name = expr.name
                return Assignment(name, value)
            elif isinstance(expr, Get):
                return Set(expr.object, expr.name, value)
            raise self.throw(eq, "Invalid syntax")
        return expr

    def expression(self):
        """
        Parses an expression
        """

        return self.assignment()

    def step(self):
        """Steps 1 token forward"""

        if not self.done():
            self.current += 1
        return self.previous()

    def del_statement(self):
        """Returns a del AST node"""

        value = self.expression()
        self.consume(TokenType.SEMICOLON, "Missing semicolon after statement")
        return Del(value)

    def expression_statement(self):
        """Returns a StatemenrExpr AST node"""

        value = self.expression()
        self.consume(TokenType.SEMICOLON, "Missing semicolon after statement")
        return StatementExpr(value)

    def block(self):
        """Returns a new environment to enable block scoping"""

        statements = []
        while not self.check(TokenType.RB) and not self.done():
            statements.append(self.declaration())
        self.consume(TokenType.RB, "Unexpected end of block")
        return statements

    def if_statement(self):
        """Parses an IF statement"""

        self.consume(TokenType.LP, "The if condition must be parenthesized")
        cond = self.expression()
        self.consume(TokenType.RP, "The if condition must be parenthesized")
        then_branch = self.statement()
        else_branch = None
        if self.match(TokenType.ELSE):
            else_branch = self.statement()
        return If(cond, then_branch, else_branch)

    def while_statement(self):
        """Parses a while statement"""

        self.consume(TokenType.LP, "The while condition must be parenthesized")
        cond = self.expression()
        self.consume(TokenType.RP, "The while condition must be parenthesized")
        body = self.statement()
        return While(cond, body)

    def for_statement(self):
        """Parses a for statement"""

        self.consume(TokenType.LP, "The for condition must be parenthesized")
        if self.match(TokenType.SEMICOLON):
            init = None
        elif self.match(TokenType.VAR):
            init = self.var_declaration()
        else:
            init = self.expression_statement()
        condition = None
        if not self.check(TokenType.SEMICOLON):
            condition = self.expression()
        self.consume(TokenType.SEMICOLON, "Missing semicolon after loop condition")
        incr = None
        if not self.check(TokenType.RP):
            incr = self.expression()
        self.consume(TokenType.RP, "The for condition must be parenthesized")
        body = self.statement()
        if incr:
            body = Block([body, StatementExpr(incr)])
        if not condition:
            condition = Literal(True)
        body = While(condition, body)
        if init:
            body = Block([init, body])
        return body

    def break_statement(self):
        """Parses a break statement"""

        if self.check(TokenType.SEMICOLON):
            return self.step()
        raise ParseError(self.peek(), "Invalid syntax")

    def return_statement(self):
        """Parses a return statement"""

        keyword = self.previous()
        value = None
        if not self.check(TokenType.SEMICOLON):
            value = self.expression()
        self.consume(TokenType.SEMICOLON, "Missing semicolon after statement")
        return Return(keyword, value)

    def statement(self):
        """Parses a statement"""

        if self.match(TokenType.IF):
            return self.if_statement()
        elif self.match(TokenType.RETURN):
            return self.return_statement()
        elif self.match(TokenType.FOR):
            return self.for_statement()
        elif self.match(TokenType.WHILE):
            return self.while_statement()
        elif self.match(TokenType.BREAK):
            return Break(self.break_statement())
        elif self.match(TokenType.LB):
            return Block(self.block())
        elif self.match(TokenType.DEL):
            return self.del_statement()
        return self.expression_statement()

    def var_declaration(self):
        """Parses a var declaration"""

        name = self.consume(TokenType.ID, "Expecting a variable name")
        init = None
        if self.match(TokenType.EQ):
            init = self.expression()
        self.consume(TokenType.SEMICOLON, "Missing semicolon after declaration")
        return Var(name, init)

    def function(self, kind: str):
        """Parses a function declaration"""

        name = self.consume(TokenType.ID, f"Expecting {kind} name")
        self.consume(TokenType.LP, f"Expecting parenthesis after {kind} name")
        parameters = []
        if not self.check(TokenType.RP):
            while True:
                if len(parameters) >= 255:
                    raise self.throw(self.peek(), "Cannot have more than 255 arguments")
                parameter = self.consume(TokenType.ID, "Expecting parameter name")
                if parameter in parameters:
                    raise self.throw(self.peek(), "Multiple parameters with the same name in function declaration are not allowed")
                parameters.append(parameter)
                if not self.match(TokenType.COMMA):
                    break
        self.consume(TokenType.RP, "Unexpected error while parsing function declaration")
        self.consume(TokenType.LB, f"Expecting '{{' before {kind} body")
        body = self.block()
        return Function(name, parameters, body)

    def class_declaration(self):
        """Parses a class declaration"""

        name = self.consume(TokenType.ID, "Expecting class name")
        superclass = None
        if self.match(TokenType.LT):
            self.consume(TokenType.ID, "Expecting superclass name")
            superclass = Variable(self.previous())
        self.consume(TokenType.LB, "Expecting '{' before class body")
        methods = []
        while not self.check(TokenType.RB) and not self.done():
            methods.append(self.function("method"))
        self.consume(TokenType.RB, "Expecting '}' after class body")
        return Class(name, methods, superclass)

    def declaration(self):
        """Parses a declaration"""

        try:
            if self.match(TokenType.CLASS):
                return self.class_declaration()
            elif self.match(TokenType.FUN):
                return self.function("function")
            elif self.match(TokenType.VAR):
                return self.var_declaration()
            return self.statement()
        except ParseError:
            self.synchronize()
            raise

    def parse(self):
        """
        Starts to parse
        """

        statements = []
        while not self.done():
            statements.append(self.declaration())
        return statements
