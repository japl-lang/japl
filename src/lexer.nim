# Copyright 2020 Mattia Giambirtone
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


## A simple tokenizer implementation with one character of lookahead.
## This module has been designed to be easily extendible in its functionality
## given that JAPL is in a state of high activity and many features are
## being added along the way. To add support for a new keyword, just create
## an appropriate TokenType entry in the enum in the file at meta/token.nim
## and then add it to the constant RESERVED table. A similar approach applies for
## other tokens, but multi-character ones require more tweaking.
## Since this lexer scans the given source string character by character, unicode
## identifiers are not supported (and are not planned to be anytime soon)

import strutils
import strformat
import tables
import meta/token


# Table of all tokens except reserved keywords
const TOKENS = to_table({
              '(': TokenType.LP, ')': TokenType.RP,
              '{': TokenType.LB, '}': TokenType.RB,
              '.': TokenType.DOT, ',': TokenType.COMMA,
              '-': TokenType.MINUS, '+': TokenType.PLUS,
              ';': TokenType.SEMICOLON, '*': TokenType.STAR,
              '>': TokenType.GT, '<': TokenType.LT,
              '=': TokenType.EQ, '!': TokenType.NEG,
              '/': TokenType.SLASH, '%': TokenType.MOD,
              '[': TokenType.LS, ']': TokenType.RS,
              ':': TokenType.COLON, '^': TokenType.CARET,
              '&': TokenType.BAND, '|': TokenType.BOR,
              '~': TokenType.TILDE})

# Constant table storing all the reserved keywords for JAPL
const RESERVED = to_table({
                "or": TokenType.OR, "and": TokenType.AND,
                "class": TokenType.CLASS, "fun": TokenType.FUN,
                "if": TokenType.IF, "else": TokenType.ELSE,
                "for": TokenType.FOR, "while": TokenType.WHILE,
                "var": TokenType.VAR, "nil": TokenType.NIL,
                "true": TokenType.TRUE, "false": TokenType.FALSE,
                "return": TokenType.RETURN,
                "this": TokenType.THIS, "super": TokenType.SUPER,
                "del": TokenType.DEL, "break": TokenType.BREAK,
                "continue": TokenType.CONTINUE, "inf": TokenType.INF,
                "nan": TokenType.NAN,
                "is": TokenType.IS})
type
    Lexer* = ref object
        source*: string
        tokens*: seq[Token]
        line*: int
        start*: int
        current*: int
        errored*: bool
        file*: string


func initLexer*(source: string, file: string): Lexer =
    ## Initializes the lexer
    result = Lexer(source: source, tokens: @[], line: 1, start: 0, current: 0, errored: false, file: file)


proc done(self: Lexer): bool =
    ## Returns true if we reached EOF
    result = self.current >= self.source.len


proc step(self: var Lexer): char =
    ## Steps one character forward in the
    ## source file. A null terminator is returned
    ## if the lexer is at EOF
    if self.done():
        return '\0'
    self.current = self.current + 1
    result = self.source[self.current - 1]


proc peek(self: Lexer): char =
    ## Returns the current character in the
    ## source file without consuming it.
    ## A null terminator is returned
    ## if the lexer is at EOF
    if self.done():
        result = '\0'
    else:
        result = self.source[self.current]


proc match(self: var Lexer, what: char): bool =
    ## Returns true if the next character matches
    ## the given character, and consumes it.
    ## Otherwise, false is returned
    if self.done():
        return false
    elif self.peek() != what:
        return false
    self.current += 1
    return true


proc peekNext(self: Lexer): char =
    ## Returns the next character
    ## in the source file without
    ## consuming it.
    ## A null terminator is returned
    ## if the lexer is at EOF
    if self.current + 1 >= self.source.len:
        result = '\0'
    else:
        result = self.source[self.current + 1]


proc createToken(self: var Lexer, tokenType: TokenType): Token =
    ## Creates a token object for later use in the parser
    result = Token(kind: tokenType,
                   lexeme: self.source[self.start..<self.current],
                   line: self.line
                   )


proc parseString(self: var Lexer, delimiter: char) =
    ## Parses string literals
    while self.peek() != delimiter and not self.done():
        if self.peek() == '\n':
            self.line = self.line + 1
        discard self.step()
    if self.done():
        stderr.write(&"A fatal error occurred while parsing '{self.file}', line {self.line} at '{self.peek()}' -> Unterminated string literal\n")
        self.errored = true
    discard self.step()
    let token = self.createToken(TokenType.STR)
    self.tokens.add(token)


proc parseNumber(self: var Lexer) =
    ## Parses numeric literals
    while isDigit(self.peek()):
        discard self.step()
    if self.peek() == '.':
        discard self.step()
        while self.peek().isDigit():
            discard self.step()
    self.tokens.add(self.createToken(TokenType.NUMBER))


proc parseIdentifier(self: var Lexer) =
    ## Parses identifiers, note that
    ## multi-character tokens such as
    ## UTF runes are not supported
    while self.peek().isAlphaNumeric():
        discard self.step()
    var text: string = self.source[self.start..<self.current]
    if text in RESERVED:
        self.tokens.add(self.createToken(RESERVED[text]))
    else:
        self.tokens.add(self.createToken(TokenType.ID))


proc parseComment(self: var Lexer) =
    ## Parses multi-line comments. They start
    ## with /* and end with */, and can be nested.
    ## A missing comment terminator will raise an
    ## error
    # TODO: Multi-line comments should be syntactically
    # relevant for documenting modules/functions/classes
    var closed = false
    while not self.done():
        var finish = self.peek() & self.peekNext()
        if finish == "/*":   # Nested comments
            discard self.step()
            discard self.step()
            self.parseComment()   # Recursively parse any other enclosing comments
        elif finish == "*/":
            closed = true
            discard self.step()   # Consume the two ends
            discard self.step()
            break
        discard self.step()
    if self.done() and not closed:
        self.errored = true
        stderr.write(&"A fatal error occurred while parsing '{self.file}', line {self.line} at '{self.peek()}' -> Unexpected EOF\n")


proc scanToken(self: var Lexer) =
    ## Scans a single token. This method is
    ## called iteratively until the source
    ## file reaches EOF
    var single = self.step()
    if single in [' ', '\t', '\r']:  # We skip whitespaces, tabs and other useless characters
        return
    elif single == '\n':
        self.line += 1
    elif single in ['"', '\'']:
        self.parseString(single)
    elif single.isDigit():
        self.parseNumber()
    elif single.isAlphaNumeric() or single == '_':
        self.parseIdentifier()
    elif single in TOKENS:
        if single == '/' and self.match('/'):
            while self.peek() != '\n' and not self.done():
                discard self.step()
        elif single == '/' and self.match('*'):
            self.parseComment()
        elif single == '=' and self.match('='):
            self.tokens.add(self.createToken(TokenType.DEQ))
        elif single == '>' and self.match('='):
            self.tokens.add(self.createToken(TokenType.GE))
        elif single == '>' and self.match('>'):
            self.tokens.add(self.createToken(TokenType.SHR))
        elif single == '<' and self.match('='):
            self.tokens.add(self.createToken(TokenType.LE))
        elif single == '<' and self.match('<'):
            self.tokens.add(self.createToken(TokenType.SHL))
        elif single == '!' and self.match('='):
            self.tokens.add(self.createToken(TokenType.NE))
        elif single == '*' and self.match('*'):
            self.tokens.add(self.createToken(TokenType.POW))
        else:
            self.tokens.add(self.createToken(TOKENS[single]))
    else:
        self.errored = true
        stderr.write(&"A fatal error occurred while parsing '{self.file}', line {self.line} at '{self.peek()}' -> Unexpected token '{single}'\n")


proc lex*(self: var Lexer): seq[Token] =
    ## Lexes a source file, converting a stream
    ## of characters into a series of tokens
    while not self.done():
        self.start = self.current
        self.scanToken()
    self.tokens.add(Token(kind: TokenType.EOF, lexeme: "EOF", line: self.line))
    return self.tokens

