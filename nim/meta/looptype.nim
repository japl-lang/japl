# A loop object

type Loop* = ref object
    depth*: int
    start*: int
    outer*: Loop
    alive*: bool
    body*: int
    loopEnd*: int
