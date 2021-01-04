# Copyright 2020 Mattia Giambirtone
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

## Main entry point for the JAPL language


import strformat
import parseopt
import os
import config
import vm
import stdlib


proc repl() =
    var bytecodeVM = initVM()
    stdlibInit(bytecodeVM)
    echo JAPL_VERSION_STRING
    echo &"[Nim {NimVersion} on {hostOs} ({hostCPU})]"
    when DEBUG_TRACE_VM:
        echo "Debugger enabled, expect verbose output\n"
        echo "==== Runtime Constants ====\n"
        echo &"- FRAMES_MAX -> {FRAMES_MAX}"
        echo "==== Debugger started ====\n"
    var source: string = ""
    while true:
        try:
            stdout.write("=> ")
            source = readLine(stdin)
        except IOError:
            echo ""
            bytecodeVM.freeVM()
            break
        except KeyboardInterrupt:
            echo ""
            bytecodeVM.freeVM()
            break
        if source == "//clear" or source == "// clear":
            echo "\x1Bc"
            echo JAPL_VERSION_STRING
            echo &"[Nim {NimVersion} on {hostOs} ({hostCPU})]"
            continue
        elif source != "":
            var result = bytecodeVM.interpret(source, true, "stdin")
            when DEBUG_TRACE_VM:
                echo &"Result: {result}"
    when DEBUG_TRACE_VM:
        echo "==== Debugger exits ===="


proc main(file: string = "") =
    if file == "":
        repl()
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
        when DEBUG_TRACE_VM:
            echo "Debugger enabled, expect verbose output\n"
            echo "==== VM Constants ====\n"
            echo &"- FRAMES_MAX -> {FRAMES_MAX}"
            echo "==== Code starts ====\n"
        var result = bytecodeVM.interpret(source, false, file)
        bytecodeVM.freeVM()
        when DEBUG_TRACE_VM:
            echo &"Result: {result}"
        when DEBUG_TRACE_VM:
            echo "==== Code ends ===="


when isMainModule:
    var optParser = initOptParser(commandLineParams())
    var file: string = ""
    if paramCount() > 0:
        if paramCount() notin 1..<2:
            echo "usage: japl [filename]"
            quit()
    for kind, key, value in optParser.getopt():
        case kind:
            of cmdArgument:
                file = key
            of cmdLongOption:
                case key:
                    of "help":
                        echo HELP_MESSAGE
                        quit()
                    of "version":
                        echo JAPL_VERSION_STRING
                        quit()
                    else:
                        echo &"error: unkown option '{key}'"
                        quit()
            of cmdShortOption:
                case key:
                    of "h":
                        echo HELP_MESSAGE
                        quit()
                    of "v":
                        echo JAPL_VERSION_STRING
                        quit()
                    else:
                        echo &"error: unkown option '{key}'"
                        quit()   
            else:
                echo "usage: japl [filename]"
                quit()
    main(file)

