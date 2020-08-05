from .callable import Callable
from .instance import JAPLInstance


class JAPLClass(Callable):
    """A JAPL class"""

    def __init__(self, name: str, methods: dict, superclass):
        self.name = name
        self.methods = methods
        self.superclass = superclass
        if self.get_method("init"):
            self.arity = self.get_method("init").arity
        else:
            self.arity = 0

    def get_method(self, name: str):
        if name in self.methods:
            return self.methods[name]
        superclass = self.superclass
        while superclass:
            if name in superclass.methods:
                return superclass.methods[name]
            superclass = superclass.superclass

    def __repr__(self):
        return f"<class '{self.name}'>"

    def call(self, interpreter, arguments):
        instance = JAPLInstance(self)
        constructor = self.get_method("init")
        if constructor:
            constructor.bind(instance).call(interpreter, arguments)
        return instance

