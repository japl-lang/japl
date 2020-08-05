from .meta.tokenobject import Token
from .meta.tokentype import TokenType
from .meta.exceptions import ParseError
from typing import List


class Lexer(object):
    """
       A simple tokenizer for the JAPL programming
       language, scans a input source file and
       produces a list of tokens. Some errors
       are caught here as well.
    """

    TOKENS = {"(": TokenType.LP, ")": TokenType.RP,
              "{": TokenType.LB, "}": TokenType.RB,
              ".": TokenType.DOT, ",": TokenType.COMMA,
              "-": TokenType.MINUS, "+": TokenType.PLUS,
              ";": TokenType.SEMICOLON, "*": TokenType.STAR,
              ">": TokenType.GT, "<": TokenType.LT,
              "=": TokenType.EQ, "!": TokenType.NEG,
              "/": TokenType.SLASH, "%": TokenType.MOD}

    RESERVED = {"or": TokenType.OR, "and": TokenType.AND,
                "class": TokenType.CLASS, "fun": TokenType.FUN,
                "if": TokenType.IF, "else": TokenType.ELSE,
                "for": TokenType.FOR, "while": TokenType.WHILE,
                "var": TokenType.VAR, "nil": TokenType.NIL,
                "true": TokenType.TRUE, "false": TokenType.FALSE,
                "return": TokenType.RETURN,
                "this": TokenType.THIS, "super": TokenType.SUPER,
                "del": TokenType.DEL, "break": TokenType.BREAK}

    def __init__(self, source: str):
        """Object constructor"""

        self.source = source
        self.tokens: List[Token] = []
        self.line: int = 1   # Points to the line being lexed
        self.start: int = 0  # The position of the first character of the current lexeme
        self.current: int = 0  # The position of the current character being lexed

    def step(self) -> str:
        """
        'Steps' one character in the source code and returns it
        """

        if self.done():
            return ""
        self.current += 1
        return self.source[self.current - 1]

    def peek(self) -> str:
        """
        Returns the current character without consuming it
        or an empty string if all text has been consumed
        """

        if self.done():
            return ""
        return self.source[self.current]

    def peek_next(self) -> str:
        """
        Returns the next character after self.current
        or an empty string if the input has been consumed
        """

        if self.current + 1 >= len(self.source):
            return ""
        return self.source[self.current + 1]

    def string(self, delimiter: str):
        """Parses a string literal"""

        while self.peek() != delimiter and not self.done():
            if self.peek() == "\n":
                self.line += 1
            self.step()
        if self.done():
            raise ParseError(f"unterminated string literal at line {self.line}")
        self.step()   # Consume the '"'
        value = self.source[self.start + 1:self.current - 1]  # Get the actual string
        self.tokens.append(self.create_token(TokenType.STR, value))

    def number(self):
        """Parses a number literal"""

        convert = int
        while self.peek().isdigit():
            self.step()
        if self.peek() == ".":
            self.step()  # Consume the "."
            while self.peek().isdigit():
                self.step()
            convert = float
        self.tokens.append(self.create_token(TokenType.NUM,
                                             convert(self.source[self.start:self.current])))

    def identifier(self):
        """Parses identifiers and reserved keywords"""

        while self.peek().isalnum() or self.is_identifier(self.peek()):
            self.step()
        kind = TokenType.ID
        value = self.source[self.start:self.current]
        if self.RESERVED.get(value, None):
            kind = self.RESERVED[value]
        self.tokens.append(self.create_token(kind))

    def comment(self):
        """Handles multi-line comments"""

        closed = False
        while not self.done():
            end = self.peek() + self.peek_next()
            if end == "/*":   # Nested comments
                self.step()
                self.step()
                self.comment()
            elif end == "*/":
                closed = True
                self.step()   # Consume the two ends
                self.step()
                break
            self.step()
        if self.done() and not closed:
            raise ParseError(f"Unexpected EOF at line {self.line}")

    def match(self, char: str) -> bool:
        """
        Returns True if the current character in self.source matches
        the given character
        """

        if self.done():
            return False
        elif self.source[self.current] != char:
            return False
        self.current += 1
        return True

    def done(self) -> bool:
        """
        Helper method that's used by the lexer
        to know if all source has been consumed
        """

        return self.current >= len(self.source)

    def create_token(self, kind: TokenType, literal: object = None) -> Token:
        """
        Creates and returns a token object
        """

        return Token(kind, self.source[self.start:self.current], literal, self.line)

    def is_identifier(self, char: str):
        """Returns if a character can be an identifier"""

        if char.isalpha() or char in ("_", ):  # More coming soon
            return True

    def scan_token(self):
        """
        Scans for a single token and adds it to
        self.tokens
        """

        char = self.step()
        if char in (" ", "\t", "\r"):  # Useless characters
            return
        elif char == "\n":   # New line
            self.line += 1
        elif char in ("'", '"'):   # A string literal
            self.string(char)
        elif char.isdigit():
            self.number()
        elif self.is_identifier(char):  # Identifier or reserved keyword
            self.identifier()
        elif char in self.TOKENS:
            if char == "/" and self.match("/"):
                while self.peek() != "\n" and not self.done():
                    self.step()   # Who cares about comments?
            elif char == "/" and self.match("*"):
                self.comment()
            elif char == "=" and self.match("="):
                self.tokens.append(self.create_token(TokenType.DEQ))
            elif char == ">" and self.match("="):
                self.tokens.append(self.create_token(TokenType.GE))
            elif char == "<" and self.match("="):
                self.tokens.append(self.create_token(TokenType.LE))
            elif char == "!" and self.match("="):
                self.tokens.append(self.create_token(TokenType.NE))
            elif char == "*" and self.match("*"):
                self.tokens.append(self.create_token(TokenType.POW))
            else:
                self.tokens.append(self.create_token(self.TOKENS[char]))
        else:
            raise ParseError(f"unexpected character '{char}' at line {self.line}")

    def lex(self) -> List[Token]:
        """
        Performs lexical analysis on self.source
        and returns a list of tokens
        """

        while not self.done():
            self.start = self.current
            self.scan_token()
        self.tokens.append(Token(TokenType.EOF, "", None, self.line))
        return self.tokens
