from dataclasses import dataclass
from .tokentype import TokenType

@dataclass
class Token(object):
    """The representation of a JAPL token"""

    kind: TokenType
    lexeme: str
    literal: object
    line: int


