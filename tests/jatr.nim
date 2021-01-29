# Just Another Test Runner for running JAPL tests
# a testrunner process

import ../src/vm
import os, strformat

var btvm = initVM()
try:
    discard btvm.interpret(readFile(paramStr(1)), "")
    quit(0)
except:
    let error = getCurrentException()
    writeLine stderr, error.msg
    quit(1)
   
