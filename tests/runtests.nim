# Common entry point to run JAPL's tests
#
# - Assumes "japl" binary in ../src/japl built with all debugging off
# - Goes through all tests in (/tests/)
# - Runs all tests in (/tests/)japl/ and checks their output (marked by `//output:{output}`)
# 

# go through all nim tests
import multibyte
testMultibyte()


# go through all japl tests
import os, strformat, times, re

proc compileExpectedOutput(path: string): string =
    for line in path.lines():
        if line =~ re"^.*//output:(.*)$":
            result &= matches[0] & "\n"

var testsDir = "tests" / "japl"
var japlExec = "src" / "japl"

# support running from both the japl root and the tests dir where it
# resides
var currentDir = getCurrentDir()
if currentDir.lastPathPart() == "tests":
    testsDir = "japl"
    japlExec = ".." / japlExec


let testResultsFile = open("testresults.txt", fmAppend)
testResultsFile.writeLine(&"Executing tests at {$getTime()}")

# quick logging levels using procs
proc log(msg: string) =
    testResultsFile.File.writeLine(&"[LOG] {msg}")
    echo msg

proc detail(msg: string) =
    testResultsFile.writeLine(&"[DETAIL] {msg}")

# Exceptions for tests that represent not-yet implemented behaviour
var exceptions = @["all.jpl"]

log &"Running JAPL tests"
log &"Looking for JAPL tests in {testsDir}"
log &"Looking for JAPL executable at {japlExec}"
if not fileExists(japlExec):
    log &"JAPL executable not found"
    quit(1)
if not dirExists(testsDir):
    log &"Tests dir not found"
    quit(1)


for file in walkDir(testsDir):
    block singularTest:
        for exc in exceptions:
            if exc == file.path.extractFilename:
                log &"Skipping {file.path} because it's on the exceptions list"
                break singularTest

        log &"Running test {file.path}"
        discard execShellCmd(&"{japlExec} {file.path} >>testoutput.txt")
        let expectedOutput = compileExpectedOutput(file.path)
        let realOutputFile = open("testoutput.txt", fmRead)
        let realOutput = realOutputFile.readAll()
        realOutputFile.close()
        removeFile("testoutput.txt")
        if expectedOutput == realOutput:
            log &"Successful test {file.path}"
        else:
            detail &"Expected output:\n{expectedOutput}\n"
            detail &"Received output:\n{realOutput}\n"
            log &"Test failed {file.path}, check 'testresults.txt' for details"
            



