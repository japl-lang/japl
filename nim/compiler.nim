import strutils
import algorithm
import strformat
import lexer
import common
import meta/chunk
import meta/tokenobject
import meta/valueobject
import meta/tokentype
import meta/looptype
import types/stringtype
import types/functiontype
import tables


type
    Precedence = enum
        PREC_NONE,
        PREC_ASSIGNMENT,
        PREC_OR,
        PREC_AND,
        PREC_EQUALITY,
        PREC_COMPARISON,
        PREC_TERM,
        PREC_FACTOR,
        PREC_UNARY,
        PREC_CALL,
        PREC_PRIMARY

    ParseFn = proc(self: ref Compiler, canAssign: bool): void

    ParseRule = ref object
        prefix, infix: ParseFn
        precedence: Precedence


proc makeRule(prefix, infix: ParseFn, precedence: Precedence): ParseRule =
    return ParseRule(prefix: prefix, infix: infix, precedence: precedence)


proc advance(self: var Parser): Token =
    result = self.tokens[self.current]
    inc(self.current)


proc peek(self: Parser): Token =
    return self.tokens[self.current]


proc previous(self: Parser): Token =
    return self.tokens[self.current - 1]


proc check(self: Parser, kind: TokenType): bool =
    return self.peek().kind == kind


proc match(self: var Parser, kind: TokenType): bool =
    if not self.check(kind): return false
    discard self.advance()
    return true


proc parseError(self: var Parser, token: Token, message: string) =
    if self.panicMode:
        return
    self.panicMode = true
    self.hadError = true
    echo &"Traceback (most recent call last):"
    echo &"  File '{self.file}', line {token.line}, at '{token.lexeme}'"
    echo &"ParseError: {message}"


proc consume(self: var Parser, expected: TokenType, message: string) =
    if self.peek().kind == expected:
        discard self.advance()
        return
    self.parseError(self.peek(), message)


proc compileError(self: ref Compiler, message: string) =
    echo &"Traceback (most recent call last):"
    echo &"  File '{self.file}', line {self.parser.peek.line}, at '{self.parser.peek.lexeme}'"
    echo &"CompileError: {message}"
    self.parser.hadError = true
    self.parser.panicMode = true


proc emitByte(self: ref Compiler, byt: OpCode|uint8) =
    self.function.chunk.writeChunk(uint8 byt, self.parser.previous.line)


proc emitBytes(self: ref Compiler, byt1: OpCode|uint8, byt2: OpCode|uint8) =
    self.emitByte(uint8 byt1)
    self.emitByte(uint8 byt2)


proc emitBytes(self: ref Compiler, bytarr: array[3, uint8]) =
    self.emitBytes(bytarr[0], bytarr[1])
    self.emitByte(bytarr[2])


proc makeConstant(self: ref Compiler, val: Value): uint8 =
    result = uint8 self.function.chunk.addConstant(val)


proc makeLongConstant(self: ref Compiler, val: Value): array[3, uint8] =
    result = self.function.chunk.writeConstant(val)


proc emitConstant(self: ref Compiler, value: Value) =
    if self.function.chunk.consts.values.len > 255:
        self.emitByte(OP_CONSTANT_LONG)
        self.emitBytes(self.makeLongConstant(value))
    else:
        self.emitBytes(OP_CONSTANT, self.makeConstant(value))


proc getRule(kind: TokenType): ParseRule  # Forward declarations
proc statement(self: ref Compiler)
proc declaration(self: ref Compiler)
proc initCompiler*(vm: ptr VM, context: FunctionType, enclosing: ref Compiler = nil, parser: Parser = initParser(@[], ""), file: string): ref Compiler


proc endCompiler(self: ref Compiler): ptr Function =
    self.emitByte(OP_NIL)
    self.emitByte(OP_RETURN)
    return self.function


proc parsePrecedence(self: ref Compiler, precedence: Precedence) =
    discard self.parser.advance()
    var prefixRule = getRule(self.parser.previous.kind).prefix
    if prefixRule == nil:
        self.parser.parseError(self.parser.previous, "Expecting expression")
        return
    var canAssign = precedence <= PREC_ASSIGNMENT
    self.prefixRule(canAssign)
    if self.parser.previous.kind == EOF:
        self.parser.current -= 1
        return
    while precedence <= (getRule(self.parser.peek.kind).precedence):
        var infixRule = getRule(self.parser.advance.kind).infix
        if self.parser.peek.kind != EOF:
            self.infixRule(canAssign)
        else:
            self.parser.parseError(self.parser.previous, "Expecting expression, got EOF")
    if canAssign and self.parser.match(EQ):
        self.parser.parseError(self.parser.peek, "Invalid assignment target")


proc expression(self: ref Compiler) =
    self.parsePrecedence(PREC_ASSIGNMENT)


proc binary(self: ref Compiler, canAssign: bool) =
    var operator = self.parser.previous.kind
    var rule = getRule(operator)
    self.parsePrecedence(Precedence((int rule.precedence) + 1))
    case operator:
        of PLUS:
            self.emitByte(OP_ADD)
        of MINUS:
            self.emitByte(OP_SUBTRACT)
        of SLASH:
            self.emitByte(OP_DIVIDE)
        of STAR:
            self.emitByte(OP_MULTIPLY)
        of MOD:
            self.emitByte(OP_MOD)
        of POW:
            self.emitByte(OP_POW)
        of NE:
            self.emitBytes(OP_EQUAL, OP_NOT)
        of DEQ:
            self.emitByte(OP_EQUAL)
        of GT:
            self.emitByte(OP_GREATER)
        of GE:
            self.emitBytes(OP_LESS, OP_NOT)
        of LT:
            self.emitByte(OP_LESS)
        of LE:
            self.emitBytes(OP_GREATER, OP_NOT)
        of CARET:
           self.emitByte(OP_XOR)
        of SHL:
            self.emitByte(OP_SHL)
        of SHR:
            self.emitByte(OP_SHR)
        else:
            return


proc unary(self: ref Compiler, canAssign: bool) =
    var operator = self.parser.previous().kind
    if self.parser.peek().kind != EOF:
        self.parsePrecedence(PREC_UNARY)
    else:
        self.parser.parseError(self.parser.previous, "Expecting expression, got EOF")
        return
    case operator:
        of MINUS:
            self.emitByte(OP_NEGATE)
        of NEG:
            self.emitByte(OP_NOT)
        else:
            return


template markObject*(self: ref Compiler, obj: untyped): untyped =
    self.vm.objects.add(obj)
    obj


proc strVal(self: ref Compiler, canAssign: bool) =
    var str = self.parser.previous().lexeme
    var delimiter = &"{str[0]}"
    str = str.unescape(delimiter, delimiter)
    self.emitConstant(Value(kind: OBJECT, obj: self.markObject(newString(str))))


proc bracketAssign(self: ref Compiler, canAssign: bool) =
    discard # TODO -> Implement this


proc bracket(self: ref Compiler, canAssign: bool) =
    if self.parser.peek.kind == COLON:
        self.emitByte(OP_NIL)
        discard self.parser.advance()
        if self.parser.peek.kind == RS:
            self.emitByte(OP_NIL)
        else:
            self.parsePrecedence(PREC_TERM)
        self.emitByte(OP_SLICE_RANGE)
    else:
        self.parsePrecedence(PREC_TERM)
        if self.parser.peek.kind == RS:
            self.emitByte(OP_SLICE)
        elif self.parser.peek.kind == COLON:
            discard self.parser.advance()
            if self.parser.peek.kind == RS:
                self.emitByte(OP_NIL)
            else:
                self.parsePrecedence(PREC_TERM)
            self.emitByte(OP_SLICE_RANGE)
    if self.parser.peek.kind == EQ:
        discard self.parser.advance()
        self.parsePrecedence(PREC_TERM)
    self.parser.consume(TokenType.RS, "Expecting ']' after slice expression")


proc literal(self: ref Compiler, canAssign: bool) =
    case self.parser.previous().kind:
        of TRUE:
            self.emitByte(OP_TRUE)
        of FALSE:
            self.emitByte(OP_FALSE)
        of TokenType.NIL:
            self.emitByte(OP_NIL)
        of TokenType.INF:
            self.emitByte(OP_INF)
        of TokenType.NAN:
            self.emitByte(OP_NAN)
        else:
            discard  # Unreachable


proc number(self: ref Compiler, canAssign: bool) =
    var value = self.parser.previous().literal
    self.emitConstant(value)


proc grouping(self: ref Compiler, canAssign: bool) =
    if self.parser.match(EOF):
        self.parser.parseError(self.parser.previous, "Expecting ')'")
    elif self.parser.match(RP):
        self.emitByte(OP_NIL)
    else:
        self.expression()
        self.parser.consume(RP, "Expecting ')' after parentheszed expression")


proc synchronize(self: ref Compiler) =
    self.parser.panicMode = false
    while self.parser.peek.kind != EOF:
        if self.parser.previous().kind == SEMICOLON:
            return
        case self.parser.peek.kind:
            of TokenType.CLASS, FUN, VAR, TokenType.FOR, IF, TokenType.WHILE, RETURN:
                return
            else:
                discard
        discard self.parser.advance()


proc identifierConstant(self: ref Compiler, tok: Token): uint8 =
    return self.makeConstant(Value(kind: OBJECT, obj: self.markObject(newString(tok.lexeme))))


proc identifierLongConstant(self: ref Compiler, tok: Token): array[3, uint8] =
    return self.makeLongConstant(Value(kind: OBJECT, obj: self.markObject(newString(tok.lexeme))))


proc addLocal(self: ref Compiler, name: Token) =
    var local = Local(name: name, depth: -1)
    inc(self.localCount)
    self.locals.add(local)


proc declareVariable(self: ref Compiler) =
    if self.scopeDepth == 0:
        return
    var name = self.parser.previous()
    self.addLocal(name)


proc parseVariable(self: ref Compiler, message: string): uint8 =
    self.parser.consume(ID, message)
    self.declareVariable()
    if self.scopeDepth > 0:
        return uint8 0
    return self.identifierConstant(self.parser.previous)


proc parseLongVariable(self: ref Compiler, message: string): array[3, uint8] =
    self.parser.consume(ID, message)
    self.declareVariable()
    if self.scopeDepth > 0:
        return [uint8 0, uint8 0, uint8 0]
    return self.identifierLongConstant(self.parser.previous)


proc markInitialized(self: ref Compiler) =
    if self.scopeDepth == 0:
        return
    self.locals[self.localCount - 1].depth = self.scopeDepth


proc defineVariable(self: ref Compiler, idx: uint8) =
    if self.scopeDepth > 0:
        self.markInitialized()
        return
    self.emitBytes(OP_DEFINE_GLOBAL, idx)


proc defineVariable(self: ref Compiler, idx: array[3, uint8]) =
    if self.scopeDepth > 0:
        self.markInitialized()
        return
    self.emitByte(OP_DEFINE_GLOBAL)
    self.emitBytes(idx)


proc resolveLocal(self: ref Compiler, name: Token): int =
    var i = self.localCount - 1
    for local in reversed(self.locals):
        if local.name.lexeme == name.lexeme:
            if local.depth == -1:
                self.compileError("cannot read local variable in its own initializer")
            return i
        i = i - 1
    return -1


proc namedVariable(self: ref Compiler, tok: Token, canAssign: bool) =
    var arg = self.resolveLocal(tok)
    var
        get: OpCode
        set: OpCode
    if arg != -1:
        get = OP_GET_LOCAL
        set = OP_SET_LOCAL
    else:
        get = OP_GET_GLOBAL
        set = OP_SET_GLOBAL
        arg = int self.identifierConstant(tok)
    if self.parser.match(EQ) and canAssign:
        self.expression()
        self.emitBytes(set, uint8 arg)
    else:
        self.emitBytes(get, uint8 arg)


proc namedLongVariable(self: ref Compiler, tok: Token, canAssign: bool) =
    var arg = self.resolveLocal(tok)
    var casted = cast[array[3, uint8]](arg)
    var
        get: OpCode
        set: OpCode
    if arg != -1:
        get = OP_GET_LOCAL
        set = OP_SET_LOCAL
    else:
        get = OP_GET_GLOBAL
        set = OP_SET_GLOBAL
        casted = self.identifierLongConstant(tok)
    if self.parser.match(EQ) and canAssign:
        self.expression()
        self.emitByte(set)
        self.emitBytes(casted)
    else:
        self.emitByte(get)
        self.emitBytes(casted)



proc variable(self: ref Compiler, canAssign: bool) =
    if self.locals.len < 255:
        self.namedVariable(self.parser.previous(), canAssign)
    else:
        self.namedLongVariable(self.parser.previous(), canAssign)


proc varDeclaration(self: ref Compiler) =
    var shortName: uint8
    var longName: array[3, uint8]
    var useShort: bool = true
    if self.function.chunk.consts.values.len < 255:
        shortName = self.parseVariable("Expecting variable name")
    else:
        useShort = false
        longName = self.parseLongVariable("Expecting variable name")
    if self.parser.match(EQ):
        self.expression()
    else:
        self.emitByte(OP_NIL)
    self.parser.consume(SEMICOLON, "Missing semicolon after var declaration")
    if useShort:
        self.defineVariable(shortName)
    else:
        self.defineVariable(longName)


proc expressionStatement(self: ref Compiler) =
    self.expression()
    self.parser.consume(SEMICOLON, "Missing semicolon after expression")
    self.emitByte(OP_POP)


proc deleteVariable(self: ref Compiler, canAssign: bool) =
    self.expression()
    if self.parser.previous().kind in [NUMBER, STR]:
        self.compileError("cannot delete a literal")
    var code: OpCode
    if self.scopeDepth == 0:
        code = OP_DELETE_GLOBAL
    else:
        code = OP_DELETE_LOCAL
    self.localCount = self.localCount - 1
    if self.function.chunk.consts.values.len < 255:
        var name = self.identifierConstant(self.parser.previous())
        self.locals.delete(name)
        self.emitBytes(code, name)
    else:
        var name = self.identifierLongConstant(self.parser.previous())
        self.emitBytes(code, name[0])
        self.emitBytes(name[1], name[2])


proc parseBlock(self: ref Compiler) =
    while not self.parser.check(RB) and not self.parser.check(EOF):
        self.declaration()
    self.parser.consume(RB, "Expecting '}' after block statement")


proc beginScope(self: ref Compiler) =
    inc(self.scopeDepth)


proc endScope(self: ref Compiler) =
    self.scopeDepth = self.scopeDepth - 1
    while self.localCount > 0 and self.locals[self.localCount - 1].depth > self.scopeDepth:
        self.emitByte(OP_POP)
        self.localCount = self.localCount - 1


proc emitJump(self: ref Compiler, opcode: OpCode): int =
    self.emitByte(opcode)
    self.emitByte(0xff)
    self.emitByte(0xff)
    return self.function.chunk.code.len - 2


proc patchJump(self: ref Compiler, offset: int) =
    var jump = self.function.chunk.code.len - offset - 2
    if jump > (int uint16.high):
        self.compileError("too much code to jump over")
    else:
        self.function.chunk.code[offset] = uint8 (jump shr 8) and 0xff
        self.function.chunk.code[offset + 1] = uint8 jump and 0xff


proc ifStatement(self: ref Compiler) =
    self.parser.consume(LP, "The if condition must be parenthesized")
    if self.parser.peek.kind != EOF:
        self.expression()
        if self.parser.peek.kind != EOF:
            self.parser.consume(RP, "The if condition must be parenthesized")
        if self.parser.peek.kind != EOF:
            var jump: int = self.emitJump(OP_JUMP_IF_FALSE)
            self.emitByte(OP_POP)
            self.statement()
            var elseJump = self.emitJump(OP_JUMP)
            self.patchJump(jump)
            self.emitByte(OP_POP)
            if self.parser.match(ELSE):
                self.statement()
            self.patchJump(elseJump)
        else:
            self.parser.parseError(self.parser.previous, "Invalid syntax")
    else:
        self.parser.parseError(self.parser.previous, "The if condition must be parenthesized")


proc emitLoop(self: ref Compiler, start: int) =
    self.emitByte(OP_LOOP)
    var offset = self.function.chunk.code.len - start + 2
    if offset > (int uint16.high):
        self.compileError("loop body is too large")
    else:
        self.emitByte(uint8 (offset shr 8) and 0xff)
        self.emitByte(uint8 offset and 0xff)


proc endLooping(self: ref Compiler) =
    if self.loop.loopEnd != -1:
        self.patchJump(self.loop.loopEnd)
        self.emitByte(OP_POP)
    var i = self.loop.body
    while i < self.function.chunk.code.len:
        if self.function.chunk.code[i] == uint OP_BREAK:
            self.function.chunk.code[i] = uint8 OP_JUMP
            self.patchJump(i + 1)
            i += 3
        else:
            i += 1
    self.loop = self.loop.outer


proc whileStatement(self: ref Compiler) =
    var loop = Loop(depth: self.scopeDepth, outer: self.loop, start: self.function.chunk.code.len, alive: true, loopEnd: -1)
    self.loop = loop
    self.parser.consume(LP, "The loop condition must be parenthesized")
    if self.parser.peek.kind != EOF:
        self.expression()
        if self.parser.peek.kind != EOF:
            self.parser.consume(RP, "The loop condition must be parenthesized")
        if self.parser.peek.kind != EOF:
            self.loop.loopEnd = self.emitJump(OP_JUMP_IF_FALSE)
            self.emitByte(OP_POP)
            self.loop.body = self.function.chunk.code.len
            self.statement()
            self.emitLoop(self.loop.start)
            self.patchJump(self.loop.loopEnd)
            self.emitByte(OP_POP)
        else:
            self.parser.parseError(self.parser.previous, "Invalid syntax")
    else:
        self.parser.parseError(self.parser.previous, "The loop condition must be parenthesized")
    self.endLooping()


proc forStatement(self: ref Compiler) =
    self.beginScope()
    self.parser.consume(LP, "The loop condition must be parenthesized")
    if self.parser.peek.kind != EOF:
        if self.parser.match(SEMICOLON):
            discard
        elif self.parser.match(VAR):
            self.varDeclaration()
        else:
            self.expressionStatement()
        var loop = Loop(depth: self.scopeDepth, outer: self.loop, start: self.function.chunk.code.len, alive: true, loopEnd: -1)
        self.loop = loop
        if not self.parser.match(SEMICOLON):
            self.expression()
            if self.parser.previous.kind != EOF:
                self.parser.consume(SEMICOLON, "Expecting ';'")
                self.loop.loopEnd = self.emitJump(OP_JUMP_IF_FALSE)
                self.emitByte(OP_POP)
            else:
                self.parser.current -= 1
                self.parser.parseError(self.parser.previous, "Invalid syntax")
        if not self.parser.match(RP):
            var bodyJump = self.emitJump(OP_JUMP)
            var incrementStart = self.function.chunk.code.len
            if self.parser.peek.kind != EOF:
                self.expression()
                self.emitByte(OP_POP)
                self.parser.consume(RP, "The loop condition must be parenthesized")
                self.emitLoop(self.loop.start)
                self.loop.start = incrementStart
                self.patchJump(bodyJump)
        if self.parser.peek.kind != EOF:
            self.loop.body = self.function.chunk.code.len
            self.statement()
            self.emitLoop(self.loop.start)
        else:
            self.parser.current -= 1
            self.parser.parseError(self.parser.previous, "Invalid syntax")
        if self.loop.loopEnd != -1:
            self.patchJump(self.loop.loopEnd)
            self.emitByte(OP_POP)
    else:
        self.parser.parseError(self.parser.previous, "The loop condition must be parenthesized")
    self.endLooping()
    self.endScope()


proc parseBreak(self: ref Compiler) =
    if not self.loop.alive:
        self.parser.parseError(self.parser.previous, "'break' outside loop")
    else:
        self.parser.consume(SEMICOLON, "missing semicolon after statement")
        var i = self.localCount - 1
        while i >= 0 and self.locals[i].depth > self.loop.depth:
            self.emitByte(OP_POP)
            i -= 1
        discard self.emitJump(OP_BREAK)

proc parseAnd(self: ref Compiler, canAssign: bool) =
    var jump = self.emitJump(OP_JUMP_IF_FALSE)
    self.emitByte(OP_POP)
    self.parsePrecedence(PREC_AND)
    self.patchJump(jump)


proc parseOr(self: ref Compiler, canAssign: bool) =
    var elseJump = self.emitJump(OP_JUMP_IF_FALSE)
    var endJump = self.emitJump(OP_JUMP)
    self.patchJump(elseJump)
    self.emitByte(OP_POP)
    self.parsePrecedence(PREC_OR)
    self.patchJump(endJump)


proc continueStatement(self: ref Compiler) =
    if not self.loop.alive:
        self.parser.parseError(self.parser.previous, "'continue' outside loop")
    else:
        self.parser.consume(SEMICOLON, "missing semicolon after statement")
        var i = self.localCount - 1
        while i >= 0 and self.locals[i].depth > self.loop.depth:
            self.emitByte(OP_POP)
            i -= 1
        self.emitLoop(self.loop.start)


proc parseFunction(self: ref Compiler, funType: FunctionType) =
    var self = initCompiler(self.vm, funType, self, self.parser, self.file)
    self.beginScope()
    self.parser.consume(LP, "Expecting '(' after function name")
    if self.parser.hadError:
        return
    var paramNames: seq[string] = @[]
    var defaultFollows: bool = false
    if not self.parser.check(RP):
        while true:
            self.function.arity += 1
            if self.function.arity + self.function.optionals > 255:
                self.compileError("cannot have more than 255 arguments")
                break
            var paramIdx = self.parseVariable("expecting parameter name")
            if self.parser.hadError:
                return
            if self.parser.previous.lexeme in paramNames:
                self.compileError("duplicate parameter name in function declaration")
                return
            paramNames.add(self.parser.previous.lexeme)
            self.defineVariable(paramIdx)
            if self.parser.match(EQ):
                if self.parser.peek.kind == EOF:
                    self.compileError("Unexpected EOF")
                    return
                self.function.arity -= 1
                self.function.optionals += 1
                self.expression()
                self.function.defaults[paramNames[len(paramNames) - 1]] = self.parser.previous.literal
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
    if self.function.chunk.consts.values.len < 255:
        self.emitBytes(OP_CONSTANT, self.makeConstant(Value(kind: OBJECT, obj: fun)))
    else:
        self.emitByte(OP_CONSTANT_LONG)
        self.emitBytes(self.makeLongConstant(Value(kind: OBJECT, obj: fun)))


proc funDeclaration(self: ref Compiler) =
    var funName = self.parseVariable("expecting function name")
    self.markInitialized()
    self.parseFunction(FunctionType.FUNC)
    self.defineVariable(funName)


proc argumentList(self: ref Compiler): uint8 =
    result = 0
    if not self.parser.check(RP):
        while true:
            self.expression()
            if result == 255:
                self.compileError("cannot have more than 255 arguments")
                return
            result += 1
            if not self.parser.match(COMMA):
                break
    self.parser.consume(RP, "Expecting ')' after arguments")


proc call(self: ref Compiler, canAssign: bool) =
    var argCount = self.argumentList()
    self.emitBytes(OP_CALL, argCount)


proc statement(self: ref Compiler) =
    if self.parser.match(TokenType.FOR):
        self.forStatement()
    elif self.parser.match(IF):
        self.ifStatement()
    elif self.parser.match(TokenType.WHILE):
        self.whileStatement()
    elif self.parser.match(CONTINUE):
        self.continueStatement()
    elif self.parser.match(BREAK):
        self.parseBreak()
    elif self.parser.match(LB):
        self.beginScope()
        self.parseBlock()
        self.endScope()
    else:
        self.expressionStatement()


proc declaration(self: ref Compiler) =
    if self.parser.match(FUN):
        self.funDeclaration()
    elif self.parser.match(VAR):
        self.varDeclaration()
    else:
        self.statement()
    if self.parser.panicMode:
        self.synchronize()


var rules: array[TokenType, ParseRule] = [
    makeRule(nil, binary, PREC_TERM), # PLUS
    makeRule(unary, binary, PREC_TERM), # MINUS
    makeRule(nil, binary, PREC_FACTOR), # SLASH
    makeRule(nil, binary, PREC_FACTOR), # STAR
    makeRule(unary, nil, PREC_NONE), # NEG
    makeRule(nil, binary, PREC_EQUALITY), # NE
    makeRule(nil, nil, PREC_NONE), # EQ
    makeRule(nil, binary, PREC_COMPARISON), # DEQ
    makeRule(nil, binary, PREC_COMPARISON), # LT
    makeRule(nil, binary, PREC_COMPARISON), # GE
    makeRule(nil, binary, PREC_COMPARISON), # LE
    makeRule(nil, binary, PREC_FACTOR), # MOD
    makeRule(nil, binary, PREC_FACTOR), # POW
    makeRule(nil, binary, PREC_COMPARISON), # GT
    makeRule(grouping, call, PREC_CALL), # LP
    makeRule(nil, nil, PREC_NONE), # RP
    makeRule(nil, bracket, PREC_CALL), # LS
    makeRule(nil, nil, PREC_NONE), # LB
    makeRule(nil, nil, PREC_NONE), # RB
    makeRule(nil, nil, PREC_NONE), # COMMA
    makeRule(nil, nil, PREC_NONE), # DOT
    makeRule(variable, nil, PREC_NONE), # ID
    makeRule(nil, nil, PREC_NONE), # RS
    makeRule(number, nil, PREC_NONE), # NUMBER
    makeRule(strVal, nil, PREC_NONE), # STR
    makeRule(nil, nil, PREC_NONE), # SEMICOLON
    makeRule(nil, parseAnd, PREC_AND), # AND
    makeRule(nil, nil, PREC_NONE), # CLASS
    makeRule(nil, nil, PREC_NONE), # ELSE
    makeRule(nil, nil, PREC_NONE), # FOR
    makeRule(nil, nil, PREC_NONE), # FUN
    makeRule(literal, nil, PREC_NONE), # FALSE
    makeRule(nil, nil, PREC_NONE), # IF
    makeRule(literal, nil, PREC_NONE), # NIL
    makeRule(nil, nil, PREC_NONE), # RETURN
    makeRule(nil, nil, PREC_NONE), # SUPER
    makeRule(nil, nil, PREC_NONE), # THIS
    makeRule(nil, parseOr, PREC_OR), # OR
    makeRule(literal, nil, PREC_NONE), # TRUE
    makeRule(nil, nil, PREC_NONE), # VAR
    makeRule(nil, nil, PREC_NONE), # WHILE
    makeRule(deleteVariable, nil, PREC_NONE), # DEL
    makeRule(nil, nil, PREC_NONE), # BREAK
    makeRule(nil, nil, PREC_NONE), # EOF
    makeRule(nil, nil, PREC_NONE), # COLON
    makeRule(nil, nil, PREC_NONE), # CONTINUE
    makeRule(nil, binary, PREC_TERM), # CARET
    makeRule(nil, binary, PREC_TERM), # SHL
    makeRule(nil, binary, PREC_TERM), # SHR
    makeRule(literal, nil, PREC_NONE), # INF
    makeRule(literal, nil, PREC_NONE), # NAN
]


proc getRule(kind: TokenType): ParseRule =
    result = rules[kind]


proc compile*(self: ref Compiler, source: string): ptr Function =
    var scanner = initLexer(source, self.file)
    var tokens = scanner.lex()
    if len(tokens) > 1 and not scanner.errored:
        self.parser = initParser(tokens, self.file)
        while not self.parser.match(EOF):
            self.declaration()
        var function = self.endCompiler()
        if not self.parser.hadError:
            return function
        else:
            return nil
    else:
        return nil


proc initCompiler*(vm: ptr VM, context: FunctionType, enclosing: ref Compiler = nil, parser: Parser = initParser(@[], ""), file: string): ref Compiler =
    result = new(Compiler)
    result.parser =   parser
    result.function = nil
    result.locals =  @[]
    result.scopeDepth = 0
    result.localCount = 0
    result.loop = Loop(alive: false, loopEnd: -1)
    result.vm =  vm
    result.context = context
    result.enclosing = enclosing
    result.file =  file
    result.parser.file = file
    result.locals.add(Local(depth: 0, name: Token(kind: EOF, lexeme: "")))
    inc(result.localCount)
    result.function = result.markObject(newFunction())
    if context != SCRIPT:
        result.function.name = newString(enclosing.parser.previous().lexeme)

