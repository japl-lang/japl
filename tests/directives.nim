# Constants for communication between the test runner and the test suite
const nextTestPre = "\rNEXTTEST{"
const nextTestPost = "}"
const nextTestRe = "^\rNEXTTEST{.*}$"
const nextTestNameRe = "{(.*)}$"
