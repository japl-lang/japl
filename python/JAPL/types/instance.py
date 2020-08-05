from ..meta.exceptions import JAPLError
from ..meta.tokenobject import Token


class JAPLInstance:
    """A class instance"""

    def __init__(self, klass):
        self.klass = klass
        self.fields = {}

    def __repr__(self):
        return f"<instance of '{self.klass.name}'>"

    def get(self, name: Token):
        if name.lexeme in self.fields:
            return self.fields[name.lexeme]
        meth = self.klass.get_method(name.lexeme)
        if meth:
            return meth.bind(self)
        raise JAPLError(name, f"Undefined property '{name.lexeme}'")

    def set(self, name: Token, value: object):
        self.fields[name.lexeme] = value
