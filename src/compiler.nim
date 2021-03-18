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

## The JAPL bytecode compiler


import strutils
import sequtils
import algorithm
import strformat
import tables

import multibyte
import lexer
import meta/opcode
import meta/token
import meta/looptype
import types/baseObject
import types/function
import types/numbers
import types/japlString
import types/iterable
import types/arrayList
import config
when isMainModule:
    import util/debug
import types/methods
when DEBUG_TRACE_COMPILER:
    import terminal


type
    Compiler* = ref object
        ## The state of the compiler
        enclosing*: Compiler
        function*: ptr Function
        context*: FunctionType
        locals*: seq[Local]
        localCount*: int
        scopeDepth*: int
        parser*: Parser
        loop*: Loop
        objects*: ptr ArrayList[ptr Obj]
        file*: ptr String
        interned*: Table[string, ptr Obj]
        afterReturn: bool

    Local* = ref object   # A local variable
       name*: Token
       depth*: int

    Parser* = ref object  # A Parser object
        current*: int
        tokens*: ptr ArrayList[Token]
        hadError*: bool
        panicMode*: bool
        file*: ptr String

    Precedence {.pure.} = enum
        None,
        Assign,
        Or,
        And,
        Eq,
        Comp,
        As,
        Is,
        Term,
        Factor,
        Unary,
        Exp,
        Call,
        Primary

    ParseFn = proc(self: Compiler, canAssign: bool): void

    ParseRule = ref object
        prefix, infix: ParseFn
        precedence: Precedence


proc makeRule(prefix, infix: ParseFn, precedence: Precedence): ParseRule =
    ## Creates a new rule for parsing
    result = ParseRule(prefix: prefix, infix: infix, precedence: precedence)


proc advance(self: Parser): Token =
    ## Steps forward by one in the tokens' list and
    ## increments the current token index
    result = self.tokens[self.current]
    inc(self.current)


proc peek(self: Parser): Token =
    ## Returns the current token without consuming it
    return self.tokens[self.current]


proc peekNext(self: Parser): Token =
    ## Returns the next token without consuming it
    ## or an EOF token if we're at the end of the file
    if self.current <= len(self.tokens) - 1:
        return self.tokens[self.current + 1]
    return Token(kind: EOF, lexeme: "")


proc previous(self: Parser): Token =
    ## Returns the previously consumed token
    return self.tokens[self.current - 1]


proc check(self: Parser, kind: TokenType): bool =
    ## Checks if the current token is of the expected type
    ## without consuming it
    return self.peek().kind == kind


proc checkNext(self: Parser, kind: TokenType): bool =
    ## Checks if the next token is of the expected type
    ## without consuming it
    return self.peekNext().kind == kind


proc match(self: Parser, kind: TokenType): bool =
    ## Calls self.check() and consumes a token if the expected
    ## token type is encountered, in which case true
    ## is returned. False is returned otherwise
    if not self.check(kind): return false
    discard self.advance()
    return true


proc synchronize(self: Parser) =
    ## Synchronizes the parser's state. This is useful when
    ## dealing with parsing errors. When an error occurs, we
    ## note it with our nice panicMode and hadError fields, but
    ## that in itself doesn't allow the parser to go forward
    ## in the code and report other possible errors. On the
    ## other hand, attempting to start parsing the source
    ## right after an error has occurred could lead to a
    ## cascade of unhelpful error messages that complicate
    ## debugging issues. So, when an error occurs, we try
    ## to get back into a state that at least allows us to keep
    ## parsing and pretend the error never happened (the code
    ## would not be compiled anyway so we might as well tell the
    ## user if anything else is wrong with their code). The parser
    ## will skip to the next valid token for a statement, like an
    ## if or a for loop or a class declaration, and then keep
    ## parsing from there. Note that hadError is never reset, but
    ## panicMode is
    self.panicMode = false
    while self.peek().kind != TokenType.EOF:   # Infinite loops are bad, so we must take EOF into account
        if self.previous().kind == TokenType.SEMICOLON:
            return
        case self.peek().kind:
            of TokenType.CLASS, TokenType.FUN, TokenType.VAR,
                TokenType.FOR, TokenType.IF, TokenType.WHILE,
                TokenType.RETURN:   # We found a statement boundary, so the parser bails out
                return
            else:
                discard
        discard self.advance()


proc parseError(self: Parser, token: Token, message: string) =
    ## Notifies the user about parsing errors, writing them to
    ## the standard error file. This parser is designed to report
    ## all syntatical errors inside a file in one go, rather than
    ## stopping at the first error occurrence. This allows a user
    ## to identify and fix multiple errors without running the parser
    ## multiple times
    if self.panicMode:    # This serves to identify wheter an error already occurred, in which case we return
        return
    self.panicMode = true
    self.hadError = true
    stderr.write(&"A fatal error occurred while parsing '{self.file}', line {token.line}, at '{token.lexeme}' -> {message}\n")
    self.synchronize()


proc consume(self: Parser, expected: TokenType, message: string) =
    ## Attempts to consume a token if it is of the expected type
    ## or raises a parsing error with the given message otherwise
    if self.check(expected):
        discard self.advance()
        return
    self.parseError(self.peek(), message)


proc currentChunk(self: Compiler): var Chunk =
    ## Returns the current chunk being compiled
    result = self.function.chunk


proc compileError(self: Compiler, message: string) =
    ## Notifies the user about an error occurred during
    ## compilation, writing to the standard error file
    stderr.write(&"A fatal error occurred while compiling '{self.file}', line {self.parser.peek().line}, at '{self.parser.peek().lexeme}' -> {message}\n")
    self.parser.hadError = true
    self.parser.panicMode = true


proc emitByte(self: Compiler, byt: OpCode|uint8) =
    ## Emits a single bytecode instruction and writes it
    ## to the current chunk being compiled
    when DEBUG_TRACE_COMPILER:
        write stdout, &"DEBUG - Compiler: Emitting {$byt} (uint8 value of  {$(uint8 byt)}"
        if byt.int() <= OpCode.high().int():
          write stdout, &"; opcode value of {$byt.OpCode}"
        write stdout, ")\n"
          
    self.currentChunk.writeChunk(uint8 byt, self.parser.previous.line)


proc emitBytes(self: Compiler, byt1: OpCode|uint8, byt2: OpCode|uint8) =
    ## Emits multiple bytes instead of a single one, this is useful
    ## to emit operators along with their operands or for multi-byte
    ## instructions that are longer than one byte
    self.emitByte(uint8 byt1)
    self.emitByte(uint8 byt2)


proc emitBytes(self: Compiler, bytarr: array[3, uint8]) =
    ## Handy helper method to write an array of 3 bytes into
    ## the current chunk, calling emiteByte(s) on each of its
    ## elements
    self.emitBytes(bytarr[0], bytarr[1])
    self.emitByte(bytarr[2])


proc makeConstant(self: Compiler, val: ptr Obj): array[3, uint8] =
    ## Does the same as makeConstant(), but encodes the index in the
    ## chunk's constant table as an array (which is later reconstructed
    ## into an integer at runtime) to store more than 256 constants in the table
    result = self.currentChunk.addConstant(val)


proc emitConstant(self: Compiler, obj: ptr Obj) =
    ## Emits a Constant instruction along
    ## with its operand
    self.emitByte(OpCode.Constant)
    self.emitBytes(self.makeConstant(obj))


proc initParser*(tokens: seq[Token], file: string): Parser
proc getRule(kind: TokenType): ParseRule  # Forward declarations for later use
proc statement(self: Compiler)
proc declaration(self: Compiler)
proc initCompiler*(context: FunctionType, enclosing: Compiler = nil, parser: Parser = initParser(@[], ""), file: string): Compiler


proc parsePrecedence(self: Compiler, precedence: Precedence) =
    ## Parses expressions using pratt's elegant algorithm to precedence parsing
    if self.parser.peek().kind == TokenType.EOF:
        self.parser.parseError(self.parser.peek(), "Expecting expression")
        return
    else:
        discard self.parser.advance()
    var prefixRule = getRule(self.parser.previous.kind).prefix
    if prefixRule == nil:   # If there is no prefix rule then an expression is expected
        self.parser.parseError(self.parser.previous, "Expecting expression")
        return
    var canAssign = precedence <= Precedence.Assign   # This is used to detect invalid assignment targets
    # such as "hello" = 3;
    self.prefixRule(canAssign)   # otherwise call the prefix rule (e.g. for binary negation)
    if self.parser.previous.kind == EOF:
        self.parser.current -= 1    # If we're at EOF, we bail out and restore the EOF terminator so that
        # the parser behaves accordingly later on
        return
    while precedence <= (getRule(self.parser.peek.kind).precedence):  # This will parse all expressions with the same precedence
    # or lower to the current expression
        var infixRule = getRule(self.parser.advance.kind).infix
        if self.parser.peek().kind != EOF:
            self.infixRule(canAssign)
        else:
            self.parser.parseError(self.parser.previous, "Expecting expression, got EOF")
    if canAssign and self.parser.match(TokenType.EQ):
        self.parser.parseError(self.parser.peek, "Invalid assignment target")


proc expression(self: Compiler) =
    ## Parses expressions
    self.parsePrecedence(Precedence.Assign)  # The highest-level expression is assignment


proc binary(self: Compiler, canAssign: bool) =
    ## Parses binary operators
    var operator = self.parser.previous().kind
    var rule = getRule(operator)
    self.parsePrecedence(Precedence((int rule.precedence) + 1))
    case operator:
        of TokenType.PLUS:
            self.emitByte(OpCode.Add)
        of TokenType.MINUS:
            self.emitByte(OpCode.Subtract)
        of TokenType.SLASH:
            self.emitByte(OpCode.Divide)
        of TokenType.STAR:
            self.emitByte(OpCode.Multiply)
        of TokenType.MOD:
            self.emitByte(OpCode.Mod)
        of TokenType.POW:
            self.emitByte(OpCode.Pow)
        of TokenType.NE:
            self.emitBytes(OpCode.Equal, OpCode.Not)
        of TokenType.DEQ:
            self.emitByte(OpCode.Equal)
        of TokenType.GT:
            # To allow for chaining of greater/less comparisons in the future (without doing
            # weird stuff such as allowing false with the greater/less than operators)
            # we need to move their logic in another function. This will
            # also allow for a sort of short-circuiting control flow like
            # for logical ands and ors, because why not?
            self.emitByte(OpCode.Greater)
        of TokenType.GE:
            self.emitByte(OpCode.GreaterOrEqual)
        of TokenType.LT:
            self.emitByte(OpCode.Less)
        of TokenType.LE:
            self.emitByte(OpCode.LessOrEqual)
        of TokenType.CARET:
           self.emitByte(OpCode.Xor)
        of TokenType.SHL:
            self.emitByte(OpCode.Shl)
        of TokenType.SHR:
            self.emitByte(OpCode.Shr)
        of TokenType.BOR:
            self.emitByte(OpCode.Bor)
        of TokenType.BAND:
            self.emitByte(OpCode.Band)
        of TokenType.IS:
            self.emitByte(OpCode.Is)
        of TokenType.ISNOT:
            self.emitBytes(OpCode.Is, Opcode.Not)
        of TokenType.AS:
            self.emitByte(OpCode.As)
        else:
            discard # Unreachable


proc unary(self: Compiler, canAssign: bool) =
    ## Parses unary expressions such as negation or
    ## binary inversion
    var operator = self.parser.previous().kind
    if self.parser.peek().kind != EOF:
        self.parsePrecedence(Precedence.Unary)
    else:
        self.parser.parseError(self.parser.previous, "Expecting expression, got EOF")
        return
    case operator:
        of MINUS:
            self.emitByte(OpCode.Negate)
        of NEG:
            self.emitByte(OpCode.Not)
        of TILDE:
            self.emitByte(OpCode.Bnot)
        of PLUS:
            discard   # Unary + does nothing anyway
        else:
            return


template markObject*(self: Compiler, obj: ptr Obj): untyped =
    ## Marks compile-time objects (since those take up memory as well)
    ## for the VM to reclaim space later on
    let temp = obj
    self.objects.append(temp)
    temp


proc strVal(self: Compiler, canAssign: bool) =
    ## Parses string literals
    var str = self.parser.previous().lexeme
    var delimiter = &"{str[0]}"    # TODO: Add proper escape sequences support
    str = str.unescape(delimiter, delimiter)
    if str notin self.interned:
        self.interned[str] = str.asStr()
        self.emitConstant(self.markObject(self.interned[str]))
    else:
        # We intern only constant strings!
        # Note that we don't call self.markObject on an already
        # interned string because that has already been marked
        self.emitConstant(self.interned[str])


proc bracketAssign(self: Compiler, canAssign: bool) =
    ## Parses assignments such as a[0] = "something"
    discard # TODO -> Implement this


proc bracket(self: Compiler, canAssign: bool) =
    ## Parses getitem/slice expressions, such as "hello"[0:1]
    ## or someList[5]. Slices can take up to two arguments, a start
    ## and an end index in the chosen iterable.
    ## Both arguments are optional, so doing "hi"[::]
    ## will basically copy the string (gets everything from
    ## start to end of the iterable).
    ## Indexes start from 0, and while the start index is
    ## inclusive, the end index is not. If an end index is
    ## not specified--like in "hello"[0:]--, then the it is
    ## assumed to be the length of the iterable. Likewise,
    ## if the start index is missing, it is assumed to be 0.
    ## Like in Python, using an end index that's out of bounds
    ## will not raise an error. Doing "hello"[0:999] will just
    ## return the whole string instead.
    ## It has to be noted that negative indexes are allowed: -1
    ## means the last element in the iterable, -2 the element
    ## before that and so on, but that if a negative index's value
    ## goes back too far it does NOT loop back to the end of the 
    ## iterable and will cause an IndexError at runtime instead
    if self.parser.peek.kind == TokenType.COLON:
        self.emitByte(OpCode.Nil)
        discard self.parser.advance()
        if self.parser.peek().kind == TokenType.RS:
            self.emitByte(OpCode.Nil)
        else:
            self.parsePrecedence(Precedence.Term)
        self.emitByte(OpCode.Slice)
    else:
        self.parsePrecedence(Precedence.Term)
        if self.parser.peek().kind == TokenType.RS:
            self.emitByte(OpCode.GetItem)
        elif self.parser.peek().kind == TokenType.COLON:
            discard self.parser.advance()
            if self.parser.peek().kind == TokenType.RS:
                self.emitByte(OpCode.Nil)
            else:
                self.parsePrecedence(Precedence.Term)
            self.emitByte(OpCode.Slice)
    if self.parser.peek().kind == TokenType.EQ:
        discard self.parser.advance()
        self.parsePrecedence(Precedence.Term)
    self.parser.consume(TokenType.RS, "Expecting ']' after slice expression")


proc literal(self: Compiler, canAssign: bool) =
    ## Parses literal values such as true, nan and inf
    case self.parser.previous().kind:
        of TokenType.TRUE:
            self.emitByte(OpCode.True)
        of TokenType.FALSE:
            self.emitByte(OpCode.False)
        of TokenType.NIL:
            self.emitByte(OpCode.Nil)
        of TokenType.INF:
            self.emitByte(OpCode.Inf)
        of TokenType.NAN:
            self.emitByte(OpCode.Nan)
        else:
            discard  # Unreachable


proc number(self: Compiler, canAssign: bool) =
    ## Parses numerical constants
    var value = self.parser.previous().lexeme
    try:
        if "." in value:
            self.emitConstant(self.markObject(parseFloat(value).asFloat()))
        else:
            self.emitConstant(self.markObject(parseInt(value).asInt()))
    except ValueError:
        self.compileError("number literal is too big")


proc grouping(self: Compiler, canAssign: bool) =
    ## Parses parenthesized expressions. The only interesting
    ## semantic about parentheses is that they allow lower-precedence
    ## expressions where a higher precedence one is expected
    if self.parser.match(TokenType.EOF):
        self.parser.parseError(self.parser.previous, "Expecting ')'")
    elif self.parser.match(RP):
        self.emitByte(OpCode.Nil)
    else:
        self.expression()
        self.parser.consume(TokenType.RP, "Expecting ')' after parentheszed expression")


proc identifierConstant(self: Compiler, tok: Token): array[3, uint8] =
    ## Emits instructions for identifiers
    return self.makeConstant(self.markObject(asStr(tok.lexeme)))


proc addLocal(self: Compiler, name: Token) =
    ## Stores a local variable. Local name resolution
    ## happens at compile time rather than runtime,
    ## unlike global variables which are treated differently.
    ## Note that at first, a local is in a special "uninitialized"
    ## state, this is useful to detect errors such as var a = a;
    ## inside local scopes
    var local = Local(name: name, depth: -1)
    inc(self.localCount)
    self.locals.add(local)


proc declareVariable(self: Compiler) =
    ## Declares a variable, this is only useful
    ## for local variables, there is no way to
    ## "declare" a global at compile time. This
    ## assumption works because locals
    ## and temporaries have stack semantics inside
    ## local scopes
    if self.scopeDepth == 0:
        return
    var name = self.parser.previous()
    self.addLocal(name)


proc parseVariable(self: Compiler, message: string): array[3, uint8] =
    ## Parses variables and declares them
    self.parser.consume(TokenType.ID, message)
    self.declareVariable()
    if self.scopeDepth > 0:
        return [uint8 0, uint8 0, uint8 0]
    return self.identifierConstant(self.parser.previous())


proc markInitialized(self: Compiler) =
    ## Marks the latest defined global as
    ## initialized and ready for use
    if self.scopeDepth == 0:
        return
    self.locals[self.localCount - 1].depth = self.scopeDepth


proc defineVariable(self: Compiler, idx: array[3, uint8]) =
    ## Same as defineVariable, but this is used when
    ## there's more than 255 locals in the chunk's table
    if self.scopeDepth > 0:
        self.markInitialized()
        return
    self.emitByte(OpCode.DefineGlobal)
    self.emitBytes(idx)


proc resolveLocal(self: Compiler, name: Token): int =
    ## Resolves a local variable and catches errors such as
    ## var a = a
    var i = self.localCount - 1
    for local in reversed(self.locals):
        if local.name.lexeme == name.lexeme:
            if local.depth == -1:
                self.compileError("cannot read local variable in its own initializer")
            return i
        i = i - 1
    return -1


proc namedVariable(self: Compiler, tok: Token, canAssign: bool) =
    ## Handles local and global variables assignment, as well
    ## as variable resolution
    var 
        arg = self.resolveLocal(tok)
        casted = cast[array[3, uint8]](arg)
        get: OpCode
        set: OpCode
    if arg != -1:
        get = OpCode.GetLocal
        set = OpCode.SetLocal
    else:
        get = OpCode.GetGlobal
        set = OpCode.SetGlobal
        casted = self.identifierConstant(tok)
    if self.parser.match(TokenType.EQ) and canAssign:
        self.expression()
        self.emitByte(set)
        self.emitBytes(casted)
    else:
        self.emitByte(get)
        self.emitBytes(casted)


proc variable(self: Compiler, canAssign: bool) =
    ## Emits the code to declare a variable,
    ## both locally and globally
    self.namedVariable(self.parser.previous(), canAssign)


proc varDeclaration(self: Compiler) =
    ## Parses a variable declaration
    var name: array[3, uint8] = self.parseVariable("Expecting variable name")
    if self.parser.match(TokenType.EQ):
        self.expression()
    else:
        self.emitByte(OpCode.Nil)
    self.parser.consume(TokenType.SEMICOLON, "Missing semicolon after var declaration")
    self.defineVariable(name)


proc expressionStatement(self: Compiler) =
    ## Parses an expression statement, which is
    ## an expression followed by a semicolon. It then
    ## emits a pop instruction
    self.expression()
    self.parser.consume(TokenType.SEMICOLON, "Missing semicolon after expression")
    self.emitByte(OpCode.Pop)


proc delStatement(self: Compiler) =
    self.expression()
    # TODO: isLiteral?
    if self.parser.previous().kind in {TokenType.NUMBER, TokenType.STR}:
        self.compileError("cannot delete a literal")
    var code: OpCode
    if self.scopeDepth == 0:
        code = OpCode.DeleteGlobal
    else:
        code = OpCode.DeleteLocal
        self.localCount = self.localCount - 1
    var name = self.identifierConstant(self.parser.previous())
    self.emitBytes(code, name[0])
    self.emitBytes(name[1], name[2])
    self.parser.consume(TokenType.SEMICOLON, "Missing semicolon after del statement")


proc parseBlock(self: Compiler) =
    ## Parses a block statement, which is basically
    ## a list of other statements
    while not self.parser.check(TokenType.RB) and not self.parser.check(TokenType.EOF):
        self.declaration()
    self.parser.consume(TokenType.RB, "Expecting '}' after block statement")


proc beginScope(self: Compiler) =
    ## Begins a scope by increasing the
    ## current scope depth. This is literally
    ## all it takes to create a scope, since the
    ## only semantically interesting behavior of
    ## scopes is a change in names resolution
    inc(self.scopeDepth)


proc endScope(self: Compiler) =
    ## Ends a scope, popping off any local that
    ## was created inside it along the way
    self.scopeDepth = self.scopeDepth - 1
    var start: Natural = self.localCount
    while self.localCount > 0 and self.locals[self.localCount - 1].depth > self.scopeDepth:
        self.emitByte(OpCode.Pop)
        self.localCount = self.localCount - 1
    if start >= self.localCount:
        self.locals.delete(self.localCount, start)


proc emitJump(self: Compiler, opcode: OpCode): int =
    ## Emits a jump instruction with a placeholder offset
    ## that is later patched, check patchJump for more info
    ## about how jumps work
    self.emitByte(opcode)
    self.emitByte(0xff)
    self.emitByte(0xff)
    when DEBUG_TRACE_COMPILER:
        setForegroundColor(fgYellow)
        write stdout, &"DEBUG - Compiler: emit jump @ {self.currentChunk.code.len-2}\n"
        setForegroundColor(fgDefault)
    return self.currentChunk.code.len - 2


proc patchJump(self: Compiler, offset: int) =
    ## Patches a previously emitted jump instruction.
    ## Since it's impossible to know how much code
    ## needs to be jumped before compiling the code
    ## itself, jumps are first encoded with a placeholder
    ## offset. Then, after the code that has to be jumped
    ## over has been compiled, its size is known and the
    ## previously emitted offset is replaced with the actual
    ## jump size.
    ## Note that, due to how the language is designed,
    ## only up to 2^16 bytecode instructions can
    ## be jumped over, so the size of the if/else conditions
    ## or loops is limited (hopefully 65 thousands and change
    ## instructions are enough for everyone)

    when DEBUG_TRACE_COMPILER:
        setForegroundColor(fgYellow)
        write stdout, &"DEBUG - Compiler: patching jump @ {offset}"
    let jump = self.currentChunk.code.len - offset - 2
    if jump > (int uint16.high):
        when DEBUG_TRACE_COMPILER:
            setForegroundColor(fgDefault)
            write stdout, "\n"
        self.compileError("too much code to jump over")
    else:
        let casted = toDouble(jump)
        self.currentChunk.code[offset] = casted[0]
        self.currentChunk.code[offset + 1] = casted[1]
        when DEBUG_TRACE_COMPILER:
            write stdout, &" points to {casted[0]}, {casted[1]} = {jump}\n"
            setForegroundColor(fgDefault)

proc ifStatement(self: Compiler) =
    ## Parses if statements in a C-style fashion
    self.parser.consume(TokenType.LP, "The if condition must be parenthesized")
    if self.parser.peek.kind != TokenType.EOF:
        self.expression()
        if self.parser.peek.kind != TokenType.EOF:
            self.parser.consume(TokenType.RP, "The if condition must be parenthesized")
        if self.parser.peek.kind != TokenType.EOF:
            var jump: int = self.emitJump(OpCode.JumpIfFalse)
            self.emitByte(OpCode.Pop)
            self.statement()
            var elseJump = self.emitJump(OpCode.Jump)
            self.patchJump(jump)
            self.emitByte(OpCode.Pop)
            if self.parser.match(TokenType.ELSE):
                self.statement()
            self.patchJump(elseJump)
        else:
            self.parser.parseError(self.parser.previous(), "Invalid syntax")
    else:
        self.parser.parseError(self.parser.previous(), "The if condition must be parenthesized")


proc emitLoop(self: Compiler, start: int) =
    ## Creates a loop and emits related instructions.
    when DEBUG_TRACE_COMPILER:
        setForegroundColor(fgYellow)
        write stdout, &"DEBUG - Compiler: emitting loop at start {start} "
    self.emitByte(OpCode.Loop)
    var offset = self.currentChunk.code.len - start + 2
    if offset > (int uint16.high):
        when DEBUG_TRACE_COMPILER:
            setForegroundColor(fgDefault)
            write stdout, "\n"
        self.compileError("loop body is too large")
    else:
        let offsetBytes = toDouble(offset)
        self.emitByte(offsetBytes[0])
        self.emitByte(offsetBytes[1])
        when DEBUG_TRACE_COMPILER:
            write stdout, &"pointing to {offsetBytes[0]}, {offsetBytes[1]} = {offset}\n"


proc endLooping(self: Compiler) =
    ## This method is used to make
    ## the break statement work and patch
    ## it with a jump instruction
    if self.loop.loopEnd != -1:
        self.patchJump(self.loop.loopEnd)
        self.emitByte(OpCode.Pop)

    for brk in self.loop.breaks:
        when DEBUG_TRACE_COMPILER:
            setForegroundColor(fgYellow)
            write stdout, &"DEBUG - Compiler: patching break at {brk}\n"
            setForegroundColor(fgDefault)
        self.currentChunk.code[brk] = OpCode.Jump.uint8
        self.patchJump(brk + 1)
        
    self.loop = self.loop.outer


proc whileStatement(self: Compiler) =
    ## Parses while loops in a C-style fashion
    let loop = Loop(depth: self.scopeDepth, outer: self.loop, start: self.currentChunk.code.len, alive: true, loopEnd: -1)
    self.loop = loop
    self.parser.consume(TokenType.LP, "The loop condition must be parenthesized")
    if self.parser.peek.kind != TokenType.EOF:
        self.expression()
        if self.parser.peek.kind != TokenType.EOF:
            self.parser.consume(TokenType.RP, "The loop condition must be parenthesized")
        if self.parser.peek.kind != TokenType.EOF:
            self.loop.loopEnd = self.emitJump(OpCode.JumpIfFalse)
            self.emitByte(OpCode.Pop)
            self.loop.body = self.currentChunk.code.len
            self.statement()
            self.emitLoop(self.loop.start)
            #self.patchJump(self.loop.loopEnd) # Prod2: imo will get patched over by endLooping anyways
            #self.emitByte(OpCode.Pop)
        else:
            self.parser.parseError(self.parser.previous(), "Invalid syntax")
    else:
        self.parser.parseError(self.parser.previous(), "The loop condition must be parenthesized")
    self.endLooping()


proc forStatement(self: Compiler) =
    ## Parses for loops in a C-style fashion
    self.beginScope()
    self.parser.consume(TokenType.LP, "The loop condition must be parenthesized")
    if self.parser.peek.kind != TokenType.EOF:
        if self.parser.match(TokenType.SEMICOLON):
            discard
        elif self.parser.match(TokenType.VAR):
            self.varDeclaration()
        else:
            self.expressionStatement()
        var loop = Loop(depth: self.scopeDepth, outer: self.loop, start: self.currentChunk.code.len, alive: true, loopEnd: -1)
        self.loop = loop
        if not self.parser.match(TokenType.SEMICOLON):
            self.expression()
            if self.parser.previous.kind != TokenType.EOF:
                self.parser.consume(TokenType.SEMICOLON, "Expecting ';'")
                self.loop.loopEnd = self.emitJump(OpCode.JumpIfFalse)
                self.emitByte(OpCode.Pop)
            else:
                self.parser.current -= 1
                self.parser.parseError(self.parser.previous(), "Invalid syntax")
        if not self.parser.match(RP):
            var bodyJump = self.emitJump(OpCode.Jump)
            var incrementStart = self.currentChunk.code.len
            if self.parser.peek.kind != TokenType.EOF:
                self.expression()
                self.emitByte(OpCode.Pop)
                self.parser.consume(TokenType.RP, "The loop condition must be parenthesized")
                self.emitLoop(self.loop.start)
                self.loop.start = incrementStart
                self.patchJump(bodyJump)
        if self.parser.peek.kind != TokenType.EOF:
            self.loop.body = self.currentChunk.code.len
            self.statement()
            self.emitLoop(self.loop.start)
        else:
            self.parser.current -= 1
            self.parser.parseError(self.parser.previous(), "Invalid syntax")
        if self.loop.loopEnd != -1:
            self.patchJump(self.loop.loopEnd)
            self.emitByte(OpCode.Pop)
    else:
        self.parser.parseError(self.parser.previous(), "The loop condition must be parenthesized")
    self.endLooping()
    self.endScope()


proc parseBreak(self: Compiler) =
    ## Parses break statements. A break
    ## statement causes the current loop
    ## to exit and jump to its end
    if not self.loop.alive:
        self.parser.parseError(self.parser.previous, "'break' outside loop")
    else:
        self.parser.consume(TokenType.SEMICOLON, "missing semicolon after break statement")
        var i = self.localCount - 1
        while i >= 0 and self.locals[i].depth > self.loop.depth:
            self.emitByte(OpCode.Pop)
            i -= 1
        discard self.emitJump(OpCode.Break)
        self.loop.breaks.add(self.currentChunk.code.len() - 3)


proc parseAnd(self: Compiler, canAssign: bool) =
    ## Parses expressions such as a and b
    var jump = self.emitJump(OpCode.JumpIfFalse)
    self.emitByte(OpCode.Pop)
    self.parsePrecedence(Precedence.And)
    self.patchJump(jump)


proc parseOr(self: Compiler, canAssign: bool) =
    ## Parses expressions such as a or b
    var elseJump = self.emitJump(OpCode.JumpIfFalse)
    var endJump = self.emitJump(OpCode.Jump)
    self.patchJump(elseJump)
    self.emitByte(OpCode.Pop)
    self.parsePrecedence(Precedence.Or)
    self.patchJump(endJump)


proc continueStatement(self: Compiler) =
    ## Parses continue statements inside loops.
    ## The continue statement causes the loop to skip
    ## to the next iteration
    if not self.loop.alive:
        self.parser.parseError(self.parser.previous, "'continue' outside loop")
    else:
        self.parser.consume(TokenType.SEMICOLON, "missing semicolon after continue statement")
        var i = self.localCount - 1
        while i >= 0 and self.locals[i].depth > self.loop.depth:
            self.emitByte(OpCode.Pop)
            i -= 1
        self.emitLoop(self.loop.start)


proc endCompiler(self: Compiler): ptr Function =
    ## Ends the current compiler instance and returns its
    ## compiled bytecode wrapped around a function object,
    ## also emitting a return instruction with nil as operand.
    ## Because of this, all functions implicitly return nil
    ## if no return statement is supplied
    self.emitByte(OpCode.Nil)
    self.emitByte(OpCode.Return)
    return self.function


proc parseFunction(self: Compiler, funType: FunctionType) =
    ## Parses function declarations. Functions can have
    ## keyword arguments (WIP), but once a parameter is declared
    ## as a keyword one, all subsequent parameters must be
    ## keyword ones as well
    var self = initCompiler(funType, self, self.parser, self.file.toStr())
    self.beginScope()
    if self.parser.check(LB):
        self.parser.consume(LB, "Expecting '{' before function body")
        self.parseBlock()
        var fun = self.endCompiler()
        self = self.enclosing
        self.emitByte(OpCode.Constant)
        self.emitBytes(self.makeConstant(fun))
        return
    self.parser.consume(LP, "Expecting '('")
    if self.parser.hadError:
        return
    var paramNames: seq[string] = @[]
    var defaultFollows: bool = false
    if not self.parser.check(RP):
        while true:
            self.function.arity += 1
            if self.function.arity + self.function.optionals > 255:
                self.compileError("functions cannot have more than 255 arguments")
                break
            var paramIdx = self.parseVariable("expecting parameter name")
            if self.parser.hadError:
                return
            if self.parser.previous.lexeme in paramNames:
                self.compileError("duplicate parameter name in function declaration")
                return
            paramNames.add(self.parser.previous.lexeme)
            self.defineVariable(paramIdx)
            if self.parser.match(TokenType.EQ):
                if self.parser.peek.kind == EOF:
                    self.compileError("Unexpected EOF")
                    return
                self.function.arity -= 1
                self.function.optionals += 1
                self.expression()
                self.function.defaults.append(self.parser.previous.lexeme.asStr())
                defaultFollows = true
            elif defaultFollows:
                self.compileError("non-default argument follows default argument")
                return
            if not self.parser.match(COMMA):
                break
    self.parser.consume(RP, "Expecting ')' after parameters")
    self.parser.consume(LB, "Expecting '{' before function body")
    self.parseBlock()
    var fun = self.endCompiler()
    self = self.enclosing
    self.emitByte(OpCode.Constant)
    self.emitBytes(self.makeConstant(fun))


proc parseLambda(self: Compiler, canAssign: bool) =
    ## Parses lambda expressions of the form => (params) {code}
    self.parseFunction(FunctionType.LAMBDA)


proc funDeclaration(self: Compiler) =
    ## Parses function declarations and declares
    ## them in the current scope
    var funName = self.parseVariable("expecting function name")
    self.markInitialized()
    self.parseFunction(FunctionType.FUNC)
    self.defineVariable(funName)


proc argumentList(self: Compiler): tuple[pos: uint8, kw: uint8] =
    ## Parses arguments passed to function calls
    result.pos = 0
    result.kw = 0
    if not self.parser.check(RP):
        while true:
            if self.parser.check(ID) and self.parser.checkNext(TokenType.EQ):
                discard self.parser.advance()
                discard self.parser.advance()
                if self.parser.check(EOF):
                    self.parser.parseError(self.parser.previous, "Unexpected EOF")
                    return
                else:
                    self.expression()
                    if result.pos + result.kw == 255:
                        self.compileError("cannot pass more than 255 arguments")
                        return
                    if not self.parser.match(COMMA):
                        break
                    result.kw += 1
            else:
                if self.parser.check(EOF):
                    self.parser.parseError(self.parser.previous, "Unexpected EOF")
                    return
                if result.kw > 0:
                    self.parser.parseError(self.parser.peek, "positional argument follows default argument")
                    return
                self.expression()
                if result.pos == 255:
                    self.compileError("cannot pass more than 255 arguments")
                    return
                result.pos += 1
                if not self.parser.match(COMMA):
                    break
    self.parser.consume(RP, "Expecting ')' after arguments")


proc call(self: Compiler, canAssign: bool) =
    ## Emits appropriate bytecode to call
    ## a function with its arguments
    # TODO -> Keyword arguments
    let args = self.argumentList()
    self.emitBytes(OpCode.Call, args.pos)


proc returnStatement(self: Compiler) =
    ## Parses return statements and emits
    ## appropriate bytecode instructions
    ## for them
    if self.context == SCRIPT:
        self.compileError("'return' outside function")
    self.afterReturn = true
    if self.parser.match(TokenType.SEMICOLON):   # Empty return
        self.emitByte(OpCode.Nil)
        self.emitByte(OpCode.Return)
    else:
        self.expression()
        self.parser.consume(TokenType.SEMICOLON, "missing semicolon after return statement")
        self.emitByte(OpCode.Return)


proc statement(self: Compiler) =
    ## Parses statements
    if self.parser.match(TokenType.FOR):
        self.forStatement()
    elif self.parser.match(TokenType.IF):
        self.ifStatement()
    elif self.parser.match(TokenType.WHILE):
        self.whileStatement()
    elif self.parser.match(TokenType.RETURN):
        self.returnStatement()
    elif self.parser.match(TokenType.CONTINUE):
        self.continueStatement()
    elif self.parser.match(TokenType.BREAK):
        self.parseBreak()
    elif self.parser.match(TokenType.DEL):
        self.delStatement()
    elif self.parser.match(TokenType.LB):
        self.beginScope()
        self.parseBlock()
        self.endScope()
    else:
        self.expressionStatement()


proc declaration(self: Compiler) =
    ## Parses declarations
    # TODO -> Fix this
#    if self.afterReturn:
 #       self.compileError("dead code after return statement")
  #      self.parser.tokens.append(Token(kind: TokenType.EOF, lexeme: ""))
    if self.parser.match(FUN):
        self.funDeclaration()
    elif self.parser.match(VAR):
        self.varDeclaration()
    else:
        self.statement()


proc freeCompiler*(self: Compiler) =
    ## Frees all the allocated objects
    ## from the compiler
    when DEBUG_TRACE_ALLOCATION:
        var objCount = len(self.objects)
        var objFreed = 0
    for obj in reversed(self.objects):
        freeObject(obj)
        discard self.objects.pop()
        when DEBUG_TRACE_ALLOCATION:
            objFreed += 1
    when DEBUG_TRACE_ALLOCATION:
        echo &"DEBUG - Compiler: Freed {objFreed} objects out of {objCount} compile-time objects"


# The array of all parse rules.
# This array instructs our Pratt parser on how
# to parse expressions and statements.
# makeRule defines rules for unary and binary
# operators as well as the token's precedence
var rules: array[TokenType, ParseRule] = [
    makeRule(nil, binary, Precedence.Term), # PLUS
    makeRule(unary, binary, Precedence.Term), # MINUS
    makeRule(nil, binary, Precedence.Factor), # SLASH
    makeRule(nil, binary, Precedence.Factor), # STAR
    makeRule(unary, nil, Precedence.None), # NEG
    makeRule(nil, binary, Precedence.Eq), # NE
    makeRule(nil, nil, Precedence.None), # EQ
    makeRule(nil, binary, Precedence.Comp), # DEQ
    makeRule(nil, binary, Precedence.Comp), # LT
    makeRule(nil, binary, Precedence.Comp), # GE
    makeRule(nil, binary, Precedence.Comp), # LE
    makeRule(nil, binary, Precedence.Factor), # MOD
    makeRule(nil, binary, Precedence.Exp), # POW
    makeRule(nil, binary, Precedence.Comp), # GT
    makeRule(grouping, call, Precedence.Call), # LP
    makeRule(nil, nil, Precedence.None), # RP
    makeRule(nil, bracket, Precedence.Call), # LS
    makeRule(nil, nil, Precedence.None), # LB
    makeRule(nil, nil, Precedence.None), # RB
    makeRule(nil, nil, Precedence.None), # COMMA
    makeRule(nil, nil, Precedence.None), # DOT
    makeRule(variable, nil, Precedence.None), # ID
    makeRule(nil, nil, Precedence.None), # RS
    makeRule(number, nil, Precedence.None), # NUMBER
    makeRule(strVal, nil, Precedence.None), # STR
    makeRule(nil, nil, Precedence.None), # SEMICOLON
    makeRule(nil, parseAnd, Precedence.And), # AND
    makeRule(nil, nil, Precedence.None), # CLASS
    makeRule(nil, nil, Precedence.None), # ELSE
    makeRule(nil, nil, Precedence.None), # FOR
    makeRule(nil, nil, Precedence.None), # FUN
    makeRule(literal, nil, Precedence.None), # FALSE
    makeRule(nil, nil, Precedence.None), # IF
    makeRule(literal, nil, Precedence.None), # NIL
    makeRule(nil, nil, Precedence.None), # RETURN
    makeRule(nil, nil, Precedence.None), # SUPER
    makeRule(nil, nil, Precedence.None), # THIS
    makeRule(nil, parseOr, Precedence.Or), # OR
    makeRule(literal, nil, Precedence.None), # TRUE
    makeRule(nil, nil, Precedence.None), # VAR
    makeRule(nil, nil, Precedence.None), # WHILE
    makeRule(nil, nil, Precedence.None), # DEL
    makeRule(nil, nil, Precedence.None), # BREAK
    makeRule(nil, nil, Precedence.None), # EOF
    makeRule(nil, nil, Precedence.None), # COLON
    makeRule(nil, nil, Precedence.None), # CONTINUE
    makeRule(nil, binary, Precedence.Term), # CARET
    makeRule(nil, binary, Precedence.Term), # SHL
    makeRule(nil, binary, Precedence.Term), # SHR
    makeRule(literal, nil, Precedence.Term), # INF
    makeRule(literal, nil, Precedence.Term), # NAN
    makeRule(nil, binary, Precedence.Term), # BAND
    makeRule(nil, binary, Precedence.Term), # BOR
    makeRule(unary, nil, Precedence.None), # TILDE
    makeRule(nil, binary, Precedence.Is),   # IS
    makeRule(nil, binary, Precedence.As),   # AS
    makeRule(parseLambda, nil, Precedence.None), # LAMBDA
    makeRule(nil, binary, Precedence.Is),   # ISNOT

]


proc getRule(kind: TokenType): ParseRule =
    ## Returns an appropriate precedence rule
    ## object for a given token type
    result = rules[kind]


proc compile*(self: Compiler, source: string): ptr Function =
    ## Compiles a source string into a function
    ## object. This wires up all the code
    ## inside the parser and the lexer
    var scanner = initLexer(source, self.file.toStr())
    var tokens = scanner.lex()
    if not scanner.errored:
        self.parser = initParser(tokens, self.file.toStr())
        while not self.parser.match(EOF):
            self.declaration()
        var function = self.endCompiler()
        if not self.parser.hadError:
            when DEBUG_TRACE_COMPILER:
                echo "DEBUG - Compiler: Result -> Ok"
            return function
        else:
            when DEBUG_TRACE_COMPILER:
                echo "DEBUG - Compiler: Result -> ParseError"
            return nil
    else:
        when DEBUG_TRACE_COMPILER:
            echo "DEBUG - Compiler: Result -> LexingError"
        return nil


proc initParser*(tokens: seq[Token], file: string): Parser =
    ## Initializes a new Parser obvject and returns a reference
    ## to it
    # TODO -> Make the parser independent of the compiler. As
    # of now, the compiler is what drives the parser and while
    # that might be easier for us it is not an ideal design.
    # We'll have to devise a standard interface for other people
    # to try and hook their parsers into JAPL with ease (pretty
    # much like our lexer now has the sole requirement of
    # having a lex() procedure that returns a list of tokens)
    result = Parser(current: 0, tokens: newArrayList[Token](), hadError: false, panicMode: false, file: file.asStr())
    result.tokens.extend[:Token](tokens)


proc initCompiler*(context: FunctionType, enclosing: Compiler = nil, parser: Parser = initParser(@[], ""), file: string): Compiler =
    ## Initializes a new Compiler object and returns a reference
    ## to it
    result = new(Compiler)
    result.parser = parser
    result.function = nil   # Garbage collection paranoia
    result.locals = @[]
    result.scopeDepth = 0
    result.localCount = 0
    result.loop = Loop(alive: false, loopEnd: -1)
    result.objects = newArrayList[ptr Obj]()
    result.context = context
    result.enclosing = enclosing
    result.file = file.asStr()
    result.objects.append(result.file)
    result.parser.file = result.file
    result.locals.add(Local(depth: 0, name: Token(kind: EOF, lexeme: "")))
    inc(result.localCount)
    result.afterReturn = false
    case context:
        of FunctionType.Func:
            result.function = result.markObject(newFunction(enclosing.parser.previous().lexeme, newChunk()))
        of FunctionType.Lambda:
            result.function = result.markObject(newLambda(newChunk()))
        else:  # Script
            result.function = result.markObject(newFunction("", newChunk()))
            result.function.name = nil


# This way the compiler can be executed on its own
# without the VM
when isMainModule:
    echo "JAPL Compiler REPL"
    while true:
        try:
            var compiler: Compiler = initCompiler(SCRIPT, file="test")
            stdout.write("=> ")
            var compiled = compiler.compile(stdin.readLine())
            if compiled != nil:
                disassembleChunk(compiled.chunk, "test")
        except IOError:
            echo ""
            break

