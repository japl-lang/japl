class JAPLClass(object):
    """A JAPL class"""

    def __init__(self, name: str):
        self.name = name

    def __repr__(self):
        return self.name
