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


# TO BE RUN FROM /tests

import random, os, strformat, tables

# simple: lots of globals assigned to random vals
# then they are read

let longTestsPath = "japl" / "longs"

let test1Path = longTestsPath / "globAssgnRead.jpl" 

if not test1Path.fileExists():
    const varcount = 1000
    const readcount = 500
    var test1: string
    var vars: Table[string, int]

    for i in countup(0,varcount):
        let varname = "a" & $i
        let value = rand(10000)
        test1 &= &"var {varname} = {value};\n"
        vars[varname] = value

    for i in countup(1,readcount):
        let which = "a" & $rand(varcount)
        let value = vars[which]
        test1 &= &"print({which});//output:{value}\n"

    writeFile(test1Path, test1)

        
# locals
# same as above but for locals

let test2Path = longTestsPath / "locAssgnRead.jpl"

if not test2Path.fileExists():

    const varcount = 1000
    const readcount = 500
    var test2: string = "{\n"
    var vars: Table[string, int]

    for i in countup(0,varcount):
        let varname = "a" & $i
        let value = rand(10000)
        test2 &= &"var {varname} = {value};\n"
        vars[varname] = value

    for i in countup(1,readcount):
        let which = "a" & $rand(varcount)
        let value = vars[which]
        test2 &= &"print({which});//output:{value}\n"

    test2 &= "}"

    writeFile(test2Path, test2)

let test3Path = longTestsPath / "globWithSets.jpl"

if not test3Path.fileExists():

    const varcount = 1000
    const readcount = 500
    const setcount = 2500
    var test3: string = ""
    var vars: Table[string, int]

    for i in countup(0,varcount):
        let varname = "a" & $i
        let value = rand(10000)
        test3 &= &"var {varname} = {value};\n"
        vars[varname] = value

    for i in countup(1, setcount):
        let which = "a" & $rand(varcount)
        let newval = rand(4500)
        # sometimes test the old
        if rand(50) > 25:
            test3 &= &"print({which});//output:{vars[which]}\n"
        vars[which] = newval
        test3 &= &"{which} = {newval};\n"

    for i in countup(1,readcount):
        let which = "a" & $rand(varcount)
        let value = vars[which]
        test3 &= &"print({which});//output:{value}\n"


    writeFile(test3Path, test3)


let test4Path = longTestsPath / "locWithSets.jpl"
if not test4Path.fileExists():

    const varcount = 1000
    const readcount = 500
    const setcount = 2500
    var test4: string = "{\n"
    var vars: Table[string, int]

    for i in countup(0,varcount):
        let varname = "a" & $i
        let value = rand(10000)
        test4 &= &"var {varname} = {value};\n"
        vars[varname] = value

    for i in countup(1, setcount):
        let which = "a" & $rand(varcount)
        let newval = rand(4500)
        # sometimes test the old
        if rand(50) > 25:
            test4 &= &"print({which});//output:{vars[which]}\n"
        vars[which] = newval
        test4 &= &"{which} = {newval};\n"

    for i in countup(1,readcount):
        let which = "a" & $rand(varcount)
        let value = vars[which]
        test4 &= &"print({which});//output:{value}\n"

    test4 &= "}"

    writeFile(test4Path, test4)
