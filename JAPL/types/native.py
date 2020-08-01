from .callable import Callable
import time
from ..meta.environment import Environment
from ..meta.exceptions import ReturnException


class Clock(Callable):
    """JAPL's wrapper around time.time"""

    def __init__(self, *_):
        """Object constructor"""

        self.arity = 0

    def call(self, *args):
        return time.time()

    def __repr__(self):
        return f"<built-in function clock>"


class Type(Callable):
    """JAPL's wrapper around type"""

    def __init__(self, *_):
        """Object constructor"""

        self.arity = 1

    def call(self, _, obj):
        return type(obj[0])

    def __repr__(self):
        return f"<built-in function type>"


class JAPLFunction(Callable):
    """A generic wrapper for user-defined functions"""

    def __init__(self, declaration, closure):
        """Object constructor"""

        self.declaration = declaration
        self._repr = f"<function {self.declaration.name.lexeme}>"
        self.arity = len(self.declaration.params)
        self.closure = closure

    def bind(self, obj: object):
        """Binds a method to an object"""

        env = Environment(self.closure)
        env.define("this", obj)
        func = type(self)(self.declaration, env)
        func._repr = f"<bound method {func.declaration.name.lexeme} of object {obj.klass.name}>"
        return func

    def call(self, interpreter, arguments):
        scope = Environment(self.closure)
        for name, value in zip(self.declaration.params, arguments):
            scope.define(name.lexeme, value)
        try:
            interpreter.execute_block(self.declaration.body, scope)
        except ReturnException as error:
            return error.args[0]

    def __repr__(self):
        return self._repr

class Truthy(Callable):
    """JAPL's wrapper around bool"""

    def __init__(self, *_):
        """Object constructor"""

        self.arity = 1

    def call(self, _, obj):
        return bool(obj[0])

    def __repr__(self):
        return f"<built-in function truthy>"


class Stringify(Callable):
    """JAPL's wrapper around str()"""

    def __init__(self, *_):
        """Object constructor"""

        self.arity = 1

    def call(self, _, obj):
        return str(obj[0])

    def __repr__(self):
        return f"<built-in function stringify>"
