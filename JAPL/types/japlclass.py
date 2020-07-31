from .callable import Callable
from .instance import JAPLInstance


class JAPLClass(Callable):
    """A JAPL class"""

    def __init__(self, name: str):
        self.name = name
        self.arity = 0

    def __repr__(self):
        return f"<class '{self.name}'>"

    def call(self, interpreter, arguments):
        return JAPLInstance(self)
