class Callable(object):
    """A generic callable"""

    def call(self, interpreter, arguments):
        raise NotImplementedError

    def __init__(self, arity):
        """Object constructor"""

        self.arity = arity

