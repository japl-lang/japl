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

## Base structure for values and objects in JAPL, all
## types inherit from this simple structure

import tables
import ../types/objecttype


type
    Chunk* = ref object
        ## A piece of bytecode.
        ## Consts represents (TODO newdoc)
        ## Code represents (TODO newdoc)
        ## Lines represents (TODO newdoc)
        consts*: seq[ptr Obj]
        code*: seq[uint8]
        lines*: seq[int]