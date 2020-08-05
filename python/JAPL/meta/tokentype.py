from enum import Enum, auto

class TokenType(Enum):
    """
    An enumeration for all JAPL types
    """

    LP = auto()
    RP = auto()
    LB = auto()
    RB = auto()
    COMMA = auto()
    DOT = auto()
    PLUS = auto()
    MINUS = auto()
    SLASH = auto()
    SEMICOLON = auto()
    STAR = auto()


    NEG = auto()
    NE = auto()
    EQ = auto()
    DEQ = auto()
    GT = auto()
    LT = auto()
    GE = auto()
    LE = auto()
    MOD = auto()
    POW = auto()

    ID = auto()
    STR = auto()
    NUM = auto()


    AND = auto()
    CLASS = auto()
    ELSE = auto()
    FOR = auto()
    FUN = auto()
    FALSE = auto()
    IF = auto()
    NIL = auto()
    OR = auto()
    RETURN = auto()
    SUPER = auto()
    THIS = auto()
    TRUE = auto()
    VAR = auto()
    WHILE = auto()
    DEL = auto()
    BREAK = auto()

    EOF = auto()
