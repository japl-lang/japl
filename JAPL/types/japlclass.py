from .callable import Callable
from .instance import JAPLInstance


class JAPLClass(Callable):
    """A JAPL class"""

    def __init__(self, name: str, methods: dict):
        self.name = name
        self.methods = methods
        self.arity = 0

    def __repr__(self):
        return f"<class '{self.name}'>"

    def call(self, interpreter, arguments):
        return JAPLInstance(self)
