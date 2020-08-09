import vm
import strformat
import parseopt
import os


proc repl(debug: bool = false) =
    var bytecodeVM = initVM()
    echo &"[JAPL 0.2.0 - Nim {NimVersion} - {CompileDate} {CompileTime}]"
    var source: string = ""
    while true:
        try:
            stdout.write(">>> ")
            source = readLine(stdin)
        except IOError:
            break
        if source == "":
            continue
        else:
            if debug:
                echo "Debug mode is enabled, bytecode will be disassembled"
            var result = bytecodeVM.interpret(source, debug)
            if debug:
                echo &"Result: {result}"


proc main(file: string = "", debug: bool = false) =
    if file == "":
        repl(debug)
    else:
        var sourceFile: File
        try:
            sourceFile = open(filename=file)
        except IOError:
            echo &"Error: '{file}' could not be opened, probably the file doesn't exist or you don't have permission to read it"
            return
        var source: string
        try:
            source = readAll(sourceFile)
        except IOError:
            echo &"Error: '{file}' could not be read, probably you don't have the permission to read it"
        var bytecodeVM = initVM()
        if debug:
            echo "Debug mode is enabled, bytecode will be disassembled"
        var result = bytecodeVM.interpret(source, debug)
        if debug:
            echo &"Result: {result}"


when isMainModule:
    var parser = initOptParser(commandLineParams())
    var file: string = ""
    var debug: bool = false
    if paramCount() > 0:
        if paramCount() notin 1..<3:
            echo "usage: japl [filename] [--debug]"
            quit()
    for kind, key, value in parser.getopt():
        case kind:
            of cmdArgument:
                file = key
            of cmdLongOption:
                if key == "debug":
                    debug = true
                else:
                    echo &"Unkown option '{key}'"
                    quit()
            else:
                echo "usage: japl [filename] [--debug]"
                quit()
    main(file, debug)

