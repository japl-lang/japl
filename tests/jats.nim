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

# Just Another Test Suite for running JAPL tests

import nim/nimtests

import testutils, logutils

import os, osproc, strformat, streams, parseopt, strutils

# Tests that represent not-yet implemented behaviour
const exceptions = ["all.jpl", "for_with_function.jpl", "runtime_interning.jpl", "problem4.jpl"]
# TODO: for_with_function.jpl and problem4.jpl should already be implemented, check on them

proc buildTest(path: string): Test =
    log(LogLevel.Debug, &"Building test {path}")
    let source = readFile(path)
    result = Test(
      path: path,
      result: if path.extractFilename in exceptions: TestResult.Skip
              else: TestResult.Unstarted,
      expectedOutput: compileExpectedOutput(source),
      expectedError: compileExpectedError(source)
    )

proc buildTests(testDir: string): seq[Test] =
    for candidateObj in walkDir(testDir):
        let candidate = candidateObj.path
        if dirExists(candidate):
            log(LogLevel.Debug, &"Descending into dir {candidate}")
            result &= buildTests(candidate)
        else:
            result.add buildTest(candidate)

proc runTest(test: Test, runner: string) =
    log(LogLevel.Debug, &"Starting test {test.path}.")
    let process = startProcess(runner, args = @[test.path])
    test.process = process
    test.result = TestResult.Running

proc tryFinishTest(test: Test): bool =
    if test.process.running():
        return false
    test.output = test.process.outputStream.readAll()
    test.error = test.process.errorStream.readAll()
    if test.process.peekExitCode() == 0:
        test.result = TestResult.ToEval
    else:
        test.result = TestResult.Crash
    test.process.close()
    log(LogLevel.Debug, &"Test {test.path} finished.")
    return true

const maxAliveTests = 8
const testWait = 10

proc runTests(tests: seq[Test], runner: string) =
    var
        aliveTests = 0
        currentTest = 0
        finishedTests = 0
        buffer = newBuffer()
    let totalTests = tests.len()

    buffer.updateProgressBar(&"", totalTests, finishedTests)
    buffer.render()
    while aliveTests > 0 or currentTest < tests.len():
        buffer.render()
        sleep(testWait)
        if aliveTests < maxAliveTests and currentTest < tests.len():
            if tests[currentTest].result == TestResult.Unstarted:
                tests[currentTest].runTest(runner)
                inc aliveTests
                inc currentTest
            else:
                inc currentTest
                inc finishedTests
        for i in countup(0, min(currentTest, tests.high())):
            if tests[i].result == TestResult.Running:
                if tryFinishTest(tests[i]):
                    inc finishedTests
                    buffer.updateProgressBar(&"", totalTests, finishedTests)
                    dec aliveTests
                else:
                    inc tests[i].cycles
    buffer.render()

proc evalTest(test: Test) =
    test.output = test.output.tuStrip()
    test.error = test.error.tuStrip()
    test.expectedOutput = test.expectedOutput.tuStrip()
    test.expectedError = test.expectedError.tuStrip()
    if test.output != test.expectedOutput or test.error != test.expectedError:
        test.result = TestResult.Mismatch
    else:
        test.result = TestResult.Success

proc evalTests(tests: seq[Test]) =
    for test in tests:
        if test.result == TestResult.ToEval:
            evalTest(test)

proc printResults(tests: seq[Test]): bool =
    var
        skipped = 0
        success = 0
        fail = 0
        crash = 0
        
    for test in tests:
        log(LogLevel.Debug, &"Test {test.path} result: {test.result}")
        case test.result:
            of TestResult.Skip:
                inc skipped
            of TestResult.Mismatch:
                inc fail
                log(LogLevel.Debug, &"[{test.path}\noutput:\n{test.output}\nerror:\n{test.error}\nexpected output:\n{test.expectedOutput}\nexpectedError:\n{test.expectedError}\n]")
            of TestResult.Crash:
                inc crash
                log(LogLevel.Debug, &"{test.path} \ncrash:\n{test.error}")
            of TestResult.Success:
                inc success
            else:
                log(LogLevel.Error, &"Probably a testing suite bug: test {test.path} has result {test.result}")
    let finalLevel = if fail == 0 and crash == 0: LogLevel.Info else: LogLevel.Error
    log(finalLevel, &"{tests.len()} tests: {success} succeeded, {skipped} skipped, {fail} failed, {crash} crashed.")

    fail == 0 and crash == 0

when isMainModule:
    const jatsVersion = "(dev)"

    var optparser = initOptParser(commandLineParams())
    type Action {.pure.} = enum
        Run, Help, Version
    var action: Action = Action.Run
    type DebugAction {.pure.} = enum
        Interactive, Stdout
    var debugActions: seq[DebugAction]
    var targetFiles: seq[string]
    var verbose = true

    type QuitValue {.pure.} = enum
        Success, Failure, ArgParseErr, InternalErr
    var quitVal = QuitValue.Success

    proc evalKey(key: string) =
        let key = key.toLower()
        if key == "h" or key == "help":
            action = Action.Help
        elif key == "v" or key == "version":
            action = Action.Version
        elif key == "i" or key == "interactive":
            debugActions.add(DebugAction.Interactive)
        elif key == "s" or key == "silent":
            verbose = false
        elif key == "stdout":
            debugActions.add(DebugAction.Stdout)
        else:
            echo &"Unknown flag: {key}"
            action = Action.Help
            quitVal = QuitValue.ArgParseErr

    proc evalKeyVal(key: string, val: string) =
        let key = key.toLower()
        if key == "o" or key == "output":
            targetFiles.add(val)
        else:
            echo &"Unknown option: {key}"
            action = Action.Help
            quitVal = QuitValue.ArgParseErr

    proc evalArg(key: string) =
        echo &"Unexpected argument"
        action = Action.Help
        quitVal = QuitValue.ArgParseErr

    while true:
        optparser.next()
        case optparser.kind:
            of cmdEnd: break
            of cmdShortOption, cmdLongOption:
                if optparser.val == "":
                    evalKey(optparser.key)
                else:
                    evalKeyVal(optparser.key, optparser.val)
            of cmdArgument:
                evalArg(optparser.key)

    proc printUsage =
        echo """
JATS - Just Another Test Suite

Usage:
jats 
Runs the tests
Flags:
-i (or --interactive) displays all debug info
-o:<filename> (or --output:<filename>) saves debug info to a file
-s (or --silent) will disable all output (except --stdout)
--stdout will put all debug info to stdout
-h (or --help) displays this help message
-v (or --version) displays the version number of JATS
"""
    proc printVersion =
        echo &"JATS - Just Another Test Suite version {jatsVersion}"
    
    if action == Action.Help:
        printUsage()
        quit int(quitVal)
    elif action == Action.Version:
        printVersion()
        quit int(quitVal)
    elif action == Action.Run:
        discard
    else:
        echo &"Unknown action {action}, please contact the devs to fix this."
        quit int(QuitValue.InternalErr)

    setVerbosity(verbose)

    # start of JATS

    log(LogLevel.Debug, &"Welcome to JATS")

    runNimTests()
    var jatr = "jatr"
    var testDir = "japl"
    if not fileExists(jatr) and fileExists("tests" / jatr):
        log(LogLevel.Debug, &"Must be in root: prepending \"tests\" to paths")
        jatr = "tests" / jatr
        testDir = "tests" / testDir

    log(LogLevel.Info, &"Running JAPL tests.")
    log(LogLevel.Info, &"Building tests...")
    let tests: seq[Test] = buildTests(testDir)
    log(LogLevel.Debug, &"Tests built.")
    log(LogLevel.Info, &"Running tests...")
    tests.runTests(jatr)
    log(LogLevel.Debug, &"Tests ran.")
    log(LogLevel.Debug, &"Evaluating tests...")
    tests.evalTests()
    log(LogLevel.Debug, &"Tests evaluated.")
    if not tests.printResults():
        quitVal = QuitValue.Failure
    
    log(LogLevel.Debug, &"Quitting JATS.")

    # special options to view the entire debug log
    let logs = getTotalLog()
    for action in debugActions:
        case action:
            of DebugAction.Interactive:
                let lessExe = findExe("less", extensions = @[""])
                let moreExe = findExe("more", extensions = @[""])
                var viewer = if lessExe == "": moreExe else: lessExe
                if viewer != "":
                    writeFile("testresults.txt", logs) # yes, testresults.txt is reserved
                    discard execShellCmd(viewer & " testresults.txt") # this way because of pipe buffer sizes
                    removeFile("testresults.txt")
                else:
                    write stderr, "Interactive mode not supported on your platform, try --stdout and piping, or install/alias 'more' or 'less' to a terminal pager.\n"
            of DebugAction.Stdout:
                echo logs
    for file in targetFiles:
        writeFile(file, logs)

    quit int(quitVal)

