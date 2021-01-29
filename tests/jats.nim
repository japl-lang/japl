# Just Another Test Suite for running JAPL tests

import nim/nimtests
when isMainModule:
    runNimTests()

import ../src/vm
import testutils

import os, osproc, strformat, streams

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
    test.output = test.output.strip()
    test.error = test.error.strip()
    test.expectedOutput = test.expectedOutput.strip()
    test.expectedError = test.expectedError.strip()
    if test.output != test.expectedOutput or test.error != test.expectedError:
        test.result = TestResult.Mismatch
    else:
        test.result = TestResult.Success

proc evalTests(tests: seq[Test]) =
    for test in tests:
        if test.result == TestResult.ToEval:
            evalTest(test)

proc printResults(tests: seq[Test]) =
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

when isMainModule:
    const jatsVersion = "(dev)"

    if paramCount() > 0:
        if paramStr(1) == "-h":
            echo "Usage: jats [-h | -v | -i | -o filename.txt]"
            quit(0)
        elif paramStr(1) == "-v":
            echo "JATS v" & $jatsVersion
            quit(0)
    log(LogLevel.Debug, &"Welcome to JATS")
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
    tests.printResults()
    log(LogLevel.Debug, &"Quitting JATS.")

    # special options to view the entire debug log

    if paramCount() > 0:
        if paramStr(1) == "-i":
            writeFile("testresults.txt", getTotalLog())
            discard execShellCmd("less testresults.txt")
            removeFile("testresults.txt")
        if paramStr(1) == "-o":
            writeFile(paramStr(2), getTotalLog())

    

