from JAPL.lexer import Lexer
from JAPL.parser import Parser
from JAPL.interpreter import Interpreter
from JAPL.objects import ParseError, JAPLError



def repl():
    interpreter = Interpreter()
    print("[JAPL 0.1.1 - Interactive REPL]")
    while True:
        try:
            source = input(">>> ")
        except (EOFError, KeyboardInterrupt):
            print()
            exit()
        if source:
            lexer = Lexer(source)
            try:
                tokens = lexer.lex()
            except ParseError as err:
                print(f"\nAn error occurred, details below\n\nParseError: {err.args[0]}")
            else:
                if tokens:
                    try:
                        ast = Parser(tokens).parse()
                    except ParseError as err:
                        token, message = err.args
                        print(f"An error occurred at line {token.line} at '{token.lexeme}': {message}")
                    else:
                        if ast:
                            try:
                                result = interpreter.interpret(ast)
                            except JAPLError as error:
                                token, message = error.args
                                print(f"A runtime error occurred at line {token.line} at '{token.lexeme}': {message}")
                            else:
                                if result is not None:
                                    print(repr(result))
