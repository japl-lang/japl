from .tokentype import TokenType


class JAPLError(BaseException):
    """JAPL's exceptions base class"""

    def __repr__(self):
        return self.args[1]


class ParseError(JAPLError):
    """An error occurred while parsing"""

    def __repr__(self):
        if len(self.args) > 1:
            message, token = self.args
            if token.kind == TokenType.EOF:
                return f"Unexpected error while parsing at line {token.line}, at end: {message}"
            else:
                return f"Unexpected error while parsing at line {token.line} at '{token.lexeme}': {message}"
        return self.args[0]

    def __str__(self):
        return self.__repr__()


class BreakException(JAPLError):
    """Notifies a loop that it's time to break"""


class ReturnException(JAPLError):
    """Notifies a function that it's time to return"""
