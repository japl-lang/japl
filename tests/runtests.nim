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

# Test runner supervisor/manager

import testobject
import logutils
import testconfig

import strformat


proc runTest(test: Test, runner: string) =
    log(LogLevel.Debug, &"Starting test {test.path}.")
    let process = startProcess(runner, args = @[test.path])
    test.process = process
    if test.input.len() > 0:
        var f: File
        let suc = f.open(process.inputHandle, fmWrite)
        if suc:
            f.write(test.input)
            f.close()
        else:
            log(LogLevel.Error, &"Stdin File handle could not be opened for test {test.path}")
            test.result = Crash

    test.result = TestResult.Running

proc readOutputs(test: Test) =
    test.output = test.process.outputStream.readAll()
    test.error = test.process.errorStream.readAll()

proc tryFinishTest(test: Test): bool =
    if test.process.running():
        return false
    test.readOutputs()
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
        log(LogLevel.Debug, &"SIGKILL sent to {test.path}")
        discard test.process.waitForExit()
        test.result = TestResult.Crash
        log(LogLevel.Error, &"Test {test.path} was killed for taking too long.")

proc killTests*(tests: seq[Test]) =
    for test in tests:
        if test.result == TestResult.Running:
            killTest(test)

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

