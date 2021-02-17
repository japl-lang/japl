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

## Test runner supervisor/manager

import testobject
import logutils
import testconfig

import strformat
import os

proc runTest(test: Test) =
    ## Starts running a test
    log(LogLevel.Debug, &"Starting test {test.path}.")
    test.start()

proc tryFinishTest(test: Test): bool =
    ## Attempts to finish a test and returns true if it finished.
    ## False otherwise.
    if test.running():
        return false
    test.finish()
    log(LogLevel.Debug, &"Test {test.path} finished.")
    return true

proc killTest(test: Test) =
    ## Kills the test, logs kill reason as taking too long
    if test.running():
        test.kill()
        log(LogLevel.Error, &"Test {test.path} was killed for taking too long.")

proc killTests*(tests: seq[Test]) =
    ## kills all running tests in tests sequence
    for test in tests:
        if test.running():
            test.kill()

proc runTests*(tests: seq[Test]) =
    ## Runs all tests tests in tests, manages the maximum alive tests
    ## and launching of tests parallel. Also writes progress to the
    ## screen
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
                tests[currentTest].runTest()
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

