# Token types enumeration

type
  TokenType* = enum
    PLUS, MINUS, SLASH, STAR,
    NEG, NE, EQ, DEQ, LT, GE,
    LE, MOD, POW, GT, LP, RP, LS
    LB, RB, COMMA, DOT,
    ID, RS, NUMBER, STR,
    SEMICOLON, AND, CLASS,
    ELSE, FOR, FUN, FALSE,
    IF, NIL, RETURN, SUPER,
    THIS, OR, TRUE, VAR,
    WHILE, DEL, BREAK, EOF,
    COLON
