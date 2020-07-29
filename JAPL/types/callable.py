from abc import ABC, abstractmethod
from dataclasses import dataclass

class CallableBase(ABC):
    """Abstract base class for callables"""

    def __init__(self, arity):
        """Object constructor"""

        self.arity: int = arity

    @abstractmethod
    def call(self, interpreter, arguments):
        """Calls the callable"""

        raise NotImplementedError


class Callable(CallableBase):
    """A generic callable"""

    def call(self):
        ...

    def __init__(self, arity):
        """Object constructor"""

        self.arity: int = arity

