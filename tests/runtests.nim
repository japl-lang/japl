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

proc deepComp(left, right: string): tuple[same: bool, place: int] =
    result.same = true
    if left.high() != right.high():
        result.same = false
    for i in countup(0, left.high()):
        result.place = i
        if i > right.high():
            # already false bc of the len check at the beginning
            # already correct place bc it's updated every i
            return
        if left[i] != right[i]:
            result.same = false
            return


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
        if fileExists("testoutput.txt"):
            removeFile("testoutput.txt") # in case this crashed
        discard execShellCmd(&"{japlExec} {file.path} >>testoutput.txt")
        let expectedOutput = compileExpectedOutput(file.path).replace(re"(\n*)$", "")
        let realOutputFile = open("testoutput.txt", fmRead)
        let realOutput = realOutputFile.readAll().replace(re"([\n\r]*)$", "")
        realOutputFile.close()
        removeFile("testoutput.txt")
        let comparison = deepComp(expectedOutput, realOutput)
        if comparison.same:
            log &"Successful test {file.path}"
        else:
            detail &"Expected output:\n{expectedOutput}\n"
            detail &"Received output:\n{realOutput}\n"
            detail &"Mismatch at pos {comparison.place}"
            if comparison.place > expectedOutput.high() or 
                comparison.place > realOutput.high():
                detail &"Length mismatch"
            else:
                detail &"Expected is '{expectedOutput[comparison.place]}' while received '{realOutput[comparison.place]}'"
            log &"Test failed {file.path}, check 'testresults.txt' for details"
            
testResultsFile.close()
