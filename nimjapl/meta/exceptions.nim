# Errors for JAPL

type
    ParseError* = object of CatchableError
    JAPLError* = object of CatchableError
