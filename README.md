# japl
JAPL is an interpreted, dynamically-typed, garbage-collected and minimalistic programming language

# J.. what?

You may wonder what's the meaning of JAPL: well, it turns out to be an acronym
for __Just Another Programming Language__, but beware! Despite the name, the pronounciation is actually the same as "JPL".

## Some backstory

JAPL is born thanks to the amazing work of Bob Nystrom that wrote a book available completely for free
at [this](https://craftinginterpreters.com) link, where he describes the implementation of a simple language called Lox.


### What has been (or will be) added from Lox

- Possibility to delete variables with the `del` statement
- `break` statement
- `continue` statement
- Multi-line comments (`/* like this */`)
- Nested comments
- Modulo division (`%`) and exponentiation (`**`)
- `OP_CONSTANT_LONG` OpCode is implemented
- Differentiation between integers and floating point numbers
- `inf`, and `nan` types
- Possibility to have more than 255 locals in scope at any given time
- String slicing, with start:end syntax as well
- All entities are actually objects (even builtins) 
- Bitwise operators (AND, OR, XOR)
- Functions default and keyword arguments
- A proper import system (__Coming soon__)
- Native asynchronous (`await`/`async fun`) support (__Coming soon__)
- Multiple inheritance (__Coming Soon__)
- Bytecode optimizations such as constant folding and stack caching (__Coming Soon__)
- Arbitrary-precision arithmetic (__Coming soon__)
- Generators (__Coming soon__)
- A standard library with collections, I/O utilities, scientific modules, etc (__Coming soon__)
- Multithreading and multiprocessing support (with a global VM Lock like CPython)


Other than that, JAPL features closures, function definitions, classes, inheritance and static scoping. You can check
the provided example `.jpl` files in the repo to find out more about JAPL.

### Disclaimer

This project is currently a WIP (Work in Progress) and is not optimized nor complete.
The first version of the interpreter is written in Python, but a bytecode stack-based VM written in nim is being developed right now.

For other useful information, check the LICENSE file in this repo.

### Contributing

If you want to contribute, feel free to send a PR!
