# japl
JAPL is an interpreted, dynamically-typed and minimalistic programming language

# J.. what?

You may wonder what's the meaning of JAPL: well, it turns out to be an acronym
for Just Another Programming Language, but beware! Despite the name, the name is actually read like "JPL".

## Some backstory

JAPL is born thanks to the amazing work of Bob Nystrom that wrote a book available completely for free
at [this](https://craftinginterpreters.com) link, where he describes the implementation of a simple language called Lox.


### What has been (or will be) added from Lox

- Possibility to delete variables with the `del` statement
- `break` statement
- `continue` statement
- multi-line comments
- Nested comments
- Generators (__Coming soon__)
- A decent standard library with collections, I/O utilities and such (__Work in progress__)
- Modulo division (`%`) and exponentiation (`**`)
- `OP_CONSTANT_LONG` OpCode is implemented
- Differentiation between integers and floating point numbers
- Possibility to have more than 255 locals in scope at any given time
- String slicing, with start:end syntax as well
- All entities are actually objects (even builtins) 



Other than that, JAPL features closures, function definitions, classes, inheritance and static scoping. You can check
the provided example `.jpl` files in the repo to find out more about JAPL.

### Disclaimer

This project is currently a WIP (Work in Progress) and is not optimized nor complete.
The first version of the interpreter is written in Python, but a bytecode stack-based VM written in nim is being developed right now.

For other useful information, check the LICENSE file in this repo.

### Contributing

If you want to contribute, feel free to send a PR!
