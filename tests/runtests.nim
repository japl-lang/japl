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



# Common entry point to run JAPL's tests
#
# - Assumes "japl" binary in ../src/japl built with all debugging off
# - Goes through all tests in (/tests/)
# - Runs all tests in (/tests/)japl/ and checks their output (marked by `//output:{output}`)
# 

# Imports nim tests as well
import multibyte, os, strformat, times, re


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


# Quick logging levels using procs

proc log(file: File, msg: string) =
    file.writeLine(&"[LOG] {msg}")
    echo msg


proc detail(file: File, msg: string) =
    file.writeLine(&"[DETAIL] {msg}")


when isMainModule:
    try:
        testMultibyte()
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
        # Exceptions for tests that represent not-yet implemented behaviour
        var exceptions = @["all.jpl"]
        log(testResultsFile, "Running JAPL tests")
        log(testResultsFile, &"Looking for JAPL tests in {testsDir}")
        log(testResultsFile, &"Looking for JAPL executable at {japlExec}")
        if not fileExists(japlExec):
            log(testResultsFile, "JAPL executable not found")
            quit(1)
        if not dirExists(testsDir):
            log(testResultsFile, "Tests dir not found")
            quit(1)
        for file in walkDir(testsDir):
            block singleTest:
                for exc in exceptions:
                    if exc == file.path.extractFilename:
                        log(testResultsFile, &"Skipping {file.path} because it's on the exceptions list")
                        break singleTest
                log(testResultsFile, &"Running test {file.path}")
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
                    log(testResultsFile, &"Successful test {file.path}")
                else:
                    detail(testResultsFile, &"Expected output:\n{expectedOutput}\n")
                    detail(testResultsFile, &"Received output:\n{realOutput}\n")
                    detail(testResultsFile, &"Mismatch at pos {comparison.place}")
                    if comparison.place > expectedOutput.high() or 
                        comparison.place > realOutput.high():
                        detail(testResultsFile, &"Length mismatch")
                    else:
                        detail(testResultsFile, &"Expected is '{expectedOutput[comparison.place]}' while received '{realOutput[comparison.place]}'")
                    log(testResultsFile, &"Test failed {file.path}, check 'testresults.txt' for details")
                    
        testResultsFile.close()
    except IOError:
        stderr.write(&"Fatal IO error encountered while running tesrs -> {getCurrentExceptionMsg()}")
