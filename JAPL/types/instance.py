class JAPLInstance:
    """A class instance"""

    def __init__(self, klass):
        self.klass = klass

    def __repr__(self):
        return f"<instance of '{self.klass.name}'>"
