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

const jatsVersion* = "(dev)"

# Tests that represent not-yet implemented behaviour
const exceptions* = ["all.jpl", "for_with_function.jpl", "runtime_interning.jpl"]
# TODO: for_with_function.jpl should already be implemented, check on it

var maxAliveTests* = 16 # number of tests that can run parallel
const testWait* = 100 # number of milliseconds per cycle
const timeout* = 100 # number of cycles after which a test is killed for timeout

var testRunner* = "jatr"

const outputStripReplaces* = [ "\[DEBUG.*\n", "[\n\r ]*$" ]
const outputStripReplaceTargets* = [ "", "" ]
