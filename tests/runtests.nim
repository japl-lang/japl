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


# Imports nim tests as well
import multibyte, os, strformat, times, re, terminal


# Exceptions for tests that represent not-yet implemented behaviour
const exceptions = ["all.jpl"]

type LogLevel {.pure.} = enum
    Debug, # always written to file only (large outputs, such as the entire output of the failing test or stacktrace)
    Info, # important information about the progress of the test suite
    Error, # failing tests (printed with red)
    Stdout, # always printed to stdout only (for cli experience)


const echoedLogs = { LogLevel.Info, LogLevel.Error, LogLevel.Stdout }
const savedLogs = { LogLevel.Debug, LogLevel.Info, LogLevel.Error }


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
            # already false because of the len check at the beginning
            # already correct place because it's updated every i
            return
        if left[i] != right[i]:
            result.same = false
            return


proc logWithLevel(level: LogLevel, file: File, msg: string) =
    let msg = &"[{$level} - {$getTime()}] {msg}" 

    if level in savedLogs:
        file.writeLine(msg)
    if level in echoedLogs:
        if level == LogLevel.Error:
            setForegroundColor(fgRed)
        echo msg
        if level == LogLevel.Error:
            setForegroundColor(fgDefault)




proc main(testsDir: string, japlExec: string, testResultsFile: File): tuple[numOfTests: int, successTests: int, failedTests: int, skippedTests: int] =
    template detail(msg: string) =
        logWithLevel(LogLevel.Debug, testResultsFile, msg)
    template log(msg: string) =
        logWithLevel(LogLevel.Info, testResultsFile, msg)
    template error(msg: string) =
        logWithLevel(LogLevel.Error, testResultsFile, msg)

    var numOfTests = 0
    var successTests = 0
    var failedTests = 0
    var skippedTests = 0
    try:
        for file in walkDir(testsDir):
            block singleTest:
                if file.path.extractFilename in exceptions:
                    detail(&"Skipping '{file.path}'")
                    numOfTests += 1
                    skippedTests += 1
                    break singleTest
                elif file.path.dirExists():
                    detail(&"Descending into '" & file.path & "'")
                    var subTestResult = main(file.path, japlExec, testResultsFile)
                    numOfTests += subTestResult.numOfTests
                    successTests += subTestResult.successTests
                    failedTests += subTestResult.failedTests
                    skippedTests += subTestResult.skippedTests
                    break singleTest
                detail(&"Running test '{file.path}'")
                if fileExists("testoutput.txt"):
                    removeFile("testoutput.txt") # in case this crashed
                let retCode = execShellCmd(&"{japlExec} {file.path} >> testoutput.txt")
                numOfTests += 1
                if retCode != 0:
                    failedTests += 1
                    error(&"Test '{file.path}' has crashed!")
                else:
                    let expectedOutput = compileExpectedOutput(file.path).replace(re"(\n*)$", "")
                    let realOutputFile = open("testoutput.txt", fmRead)
                    let realOutput = realOutputFile.readAll().replace(re"([\n\r]*)$", "")
                    realOutputFile.close()
                    removeFile("testoutput.txt")
                    let comparison = deepComp(expectedOutput, realOutput)
                    if comparison.same:
                        successTests += 1
                        log(&"Test '{file.path}' was successful")
                    else:
                        failedTests += 1
                        detail(&"Expected output:\n{expectedOutput}\n")
                        detail(&"Received output:\n{realOutput}\n")
                        detail(&"Mismatch at pos {comparison.place}")
                        if comparison.place > expectedOutput.high() or comparison.place > realOutput.high():
                            detail(&"Length mismatch")
                        else:
                            detail(&"Expected is '{expectedOutput[comparison.place]}' while received '{realOutput[comparison.place]}'")
                        error(&"Test '{file.path}' failed")
        result = (numOfTests: numOfTests, successTests: successTests, failedTests: failedTests, skippedTests: skippedTests)
    except IOError:
        stderr.write(&"Fatal IO error encountered while running tests -> {getCurrentExceptionMsg()}")


when isMainModule:
    let testResultsFile = open("testresults.txt", fmWrite)
    template log (msg: string) =
        logWithLevel(LogLevel.Info, testResultsFile, msg)
    log("Running Nim tests")
    # Nim tests
    logWithLevel(LogLevel.Debug, testResultsFile, "Running testMultiByte")
    testMultiByte()
    # JAPL tests
    log("Running JAPL tests")
    var testsDir = "tests" / "japl"
    var japlExec = "src" / "japl"
    var currentDir = getCurrentDir()
    # Supports running from both the project root and the tests dir itself
    if currentDir.lastPathPart() == "tests":
        testsDir = "japl"
        japlExec = ".." / japlExec
    log(&"Looking for JAPL tests in {testsDir}")
    log(&"Looking for JAPL executable at {japlExec}")
    if not fileExists(japlExec):
        log("JAPL executable not found")
        quit(1)
    if not dirExists(testsDir):
        log("Tests dir not found")
        quit(1)
    let testResult = main(testsDir, japlExec, testResultsFile)
    log(&"Found {testResult.numOfTests} tests: {testResult.successTests} were successful, {testResult.failedTests} failed and {testResult.skippedTests} were skipped.")
    logWithLevel(LogLevel.Stdout, testResultsFile, "Check 'testresults.txt' for details")
    testResultsfile.close()

