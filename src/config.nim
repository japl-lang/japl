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



const FRAMES_MAX* = 400  # TODO: Inspect why the VM crashes if this exceeds 400
const JAPL_VERSION* = "0.2.0"
const JAPL_RELEASE* = "alpha"
const DEBUG_TRACE_VM* = true   # Traces VM execution
const DEBUG_TRACE_GC* = true    # Traces the garbage collector (TODO)
const DEBUG_TRACE_ALLOCATION* = true   # Traces memory allocation/deallocation (WIP)
const DEBUG_TRACE_COMPILER* = true   # Traces the compiler (TODO)

