import sys
from JAPL.wrapper import JAPL


if __name__ == "__main__":
    if len(sys.argv) == 1:
        JAPL().repl()
    else:
        JAPL().run(sys.argv[1])
