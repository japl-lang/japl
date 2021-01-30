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

# Test object helpers

import testobject, logutils, os, osproc, streams, strformat

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
      expectedError: compileExpectedError(source),
      input: compileInput(source)
    )

proc buildTests*(testDir: string): seq[Test] =
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
    if test.input.len() > 0:
        var f: File
        let suc = f.open(process.inputHandle, fmWrite)
        if suc:
            f.write(test.input)
        else:
            log(LogLevel.Error, &"Stdin File handle could not be opened for test {test.path}")
            test.result = Crash

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

proc killTest(test: Test) =
    if test.process.running():
        test.process.kill()
        discard test.process.waitForExit()
        log(LogLevel.Error, &"Test {test.path} was killed for taking too long.")
    discard test.tryFinishTest()

const maxAliveTests = 16
const testWait = 100
const timeout = 100 # number of cycles after which a test is killed for timeout

proc runTests*(tests: seq[Test], runner: string) =
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
                    buffer.updateProgressBar(&"Finished {tests[i].path}.", totalTests, finishedTests)
                    dec aliveTests
                elif tests[i].cycles >= timeout:
                    tests[i].killTest()
                    inc finishedTests
                    dec aliveTests
                    buffer.updateProgressBar(&"Killed {tests[i].path}.", totalTests, finishedTests)
                else:
                    inc tests[i].cycles
    buffer.render()
    buffer.endBuffer()

proc evalTest(test: Test) =
    test.output = test.output.tuStrip()
    test.error = test.error.tuStrip()
    test.expectedOutput = test.expectedOutput.tuStrip()
    test.expectedError = test.expectedError.tuStrip()
    if test.output != test.expectedOutput or test.error != test.expectedError:
        test.result = TestResult.Mismatch
    else:
        test.result = TestResult.Success

proc evalTests*(tests: seq[Test]) =
    for test in tests:
        if test.result == TestResult.ToEval:
            evalTest(test)

proc printResults*(tests: seq[Test]): bool =
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


