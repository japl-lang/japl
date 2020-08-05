from JAPL.lexer import Lexer
from JAPL.meta.exceptions import ParseError, JAPLError
from JAPL.resolver import Resolver
from JAPL.parser import Parser
from JAPL.interpreter import Interpreter


class JAPL(object):
    """Wrapper around JAPL's interpreter, lexer and parser"""

    interpreter = Interpreter()
    resolver = Resolver(interpreter)

    def run(self, file: str):
        """Runs a file"""

        if not file:
            self.repl()
        else:
            try:
                with open(file) as source_file:
                    source_code = source_file.read()
                    lexer = Lexer(source_code)
                    tokens = lexer.lex()
                    parser = Parser(tokens)
                    ast = parser.parse()
                    self.resolver.resolve(ast)
                    self.interpreter.interpret(ast)
            except FileNotFoundError:
                print(f"Error: '{file}', no such file or directory")
            except PermissionError:
                print(f"Error' '{file}', permission denied")
            except JAPLError as err:
                if len(err.args) == 2:
                    token, message = err.args
                    print(f"An exception occurred at line {token.line}, file '{file}' at '{token.lexeme}': {message}")
                else:
                    print(f"An exception occurred, details below\n\n{type(err).__name__}: {err}")

    def repl(self):
        """Starts an interactive REPL"""

        print("[JAPL 0.1.1 - Interactive REPL]")
        while True:
            try:
                source = input(">>> ")
            except (EOFError, KeyboardInterrupt):
                print()
                return
            if not source:
                continue
            lexer = Lexer(source)
            try:
                tokens = lexer.lex()
                ast = Parser(tokens).parse()
                self.resolver.resolve(ast)
                result = self.interpreter.interpret(ast)
            except ParseError as err:
                if len(err.args) == 2:
                    token, message = err.args
                    print(f"An exception occurred at line {token.line} at '{token.lexeme}': {message}")
                else:
                    print(f"\nAn exception occurred, details below\n\nParseError: {err.args[0]}")
            except JAPLError as error:
                if len(error.args) == 2:
                    token, message = error.args
                    print(f"An exception occurred at line {token.line}, file 'stdin' at '{token.lexeme}': {message}")
                else:
                    print(f"An exception occurred, details below\n\n{type(error).__name__}: {error}")
