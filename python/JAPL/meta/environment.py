from .exceptions import JAPLError
from .tokenobject import Token
from .expression import Variable


class Environment(object):
    """
       A wrapper around a hashmap representing
       a scope
    """

    def __init__(self, enclosing=None):
        """Object constructor"""

        self.map = {}
        self.enclosing = enclosing

    def define(self, name: str, attr: object):
        """Defines a new variable in the scope"""

        self.map[name] = attr

    def get(self, name: Token):
        """Gets a variable"""

        if name.lexeme in self.map:
            return self.map[name.lexeme]
        elif self.enclosing:
            return self.enclosing.get(name)
        raise JAPLError(name, f"Undefined name '{name.lexeme}'")

    def get_at(self, distance, name):
        """Gets a variable in a specific scope"""

        return self.ancestor(distance).map.get(name)

    def ancestor(self, distance):
        """Finds the scope specified by distance"""

        env = self
        for _ in range(distance):
            env = env.enclosing
        return env

    def assign_at(self, distance, name, value):
        """Same as get_at, but assigns instead of retrieving"""

        self.ancestor(distance).map[name.lexeme] = value

    def delete(self, var):
        """Deletes a variable"""

        if var.name.lexeme in self.map:
            del self.map[var.name.lexeme]
        elif self.enclosing:
            self.enclosing.delete(var)
        else:
            raise JAPLError(var.name, f"Undefined name '{var.name.lexeme}'")

    def assign(self, name: Token, value: object):
        """Assigns a variable"""

        if name.lexeme in self.map:
            if isinstance(value, Variable):
                self.map[name.lexeme] = self.get(value.name)
            else:
                self.map[name.lexeme] = value
        elif self.enclosing:
            self.enclosing.assign(name, value)
        else:
            raise JAPLError(name, f"Undefined name '{name.lexeme}'")
