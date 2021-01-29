# Just Another Test Suite for running JAPL tests

import ../src/vm
import testutils

import os, osproc, strformat, streams

# Tests that represent not-yet implemented behaviour
const exceptions = ["all.jpl", "for_with_function.jpl", "runtime_interning.jpl", "problem4.jpl"]
# TODO: for_with_function.jpl and problem4.jpl should already be implemented, check on them

proc buildTest(path: string): Test =
    result = Test(
      path: path,
      result: if path.extractFilename in exceptions: TestResult.Skip
              else: TestResult.Unstarted,
      expectedOutput: compileExpectedOutput(readFile(path))
    )

proc buildTests(testDir: string): seq[Test] =
    for candidateObj in walkDir(testDir):
        let candidate = candidateObj.path
        if dirExists(candidate):
            result &= buildTests(candidate)
        else:
            result.add buildTest(candidate)

proc runTest(test: Test, runner: string) =
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
    return true

const maxAliveTests = 8
const testWait = 100

proc runTests(tests: seq[Test], runner: string) =
    var
        aliveTests = 0
        currentTest = 0

    while true:
        if aliveTests < maxAliveTests and currentTest < tests.len():
            if tests[currentTest].result == TestResult.Unstarted:
                echo &"Doing test {$currentTest}"
                tests[currentTest].runTest(runner)
                inc aliveTests
                inc currentTest
            else:
                echo &"Skipping test {$currentTest}"
                inc currentTest
            continue
        if aliveTests == 0 and currentTest >= tests.len():
            break
        for i in countup(0, min(currentTest, tests.high())):
            if tests[i].result == TestResult.Running:
                if tryFinishTest(tests[i]):
                    dec aliveTests
                    echo &"finished running {tests[i].path}"
                else:
                    echo &"{tests[i].path} still running"
                    inc tests[i].cycles
        sleep(testWait)

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
    for test in tests:
        echo &"Test {test.path} {test.result}"

when isMainModule:
    var jatr = "jatr"
    var testDir = "japl"
    if not fileExists(jatr) and fileExists("tests" / jatr):
        jatr = "tests" / jatr
        testDir = "tests" / testDir

    let tests: seq[Test] = buildTests(testDir)
    tests.runTests(jatr)
    tests.evalTests()
    tests.printResults()
    
