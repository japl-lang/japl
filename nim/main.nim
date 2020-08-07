import vm
import meta/chunk
import util/debug
import meta/valueobject
import strformat


proc main() =
    echo "Initializing the JAPL virtual machine"
    var bytecodeVM = initVM()
    echo "Creating arbitrary chunk"
    var chunk: Chunk = initChunk()
    var index: int = chunk.addConstant(Value(kind: FLOAT, floatValue: 1.2))
    var index2: array[3, uint8] = chunk.writeConstant(Value(kind: INT, intValue: 56))
    chunk.writeChunk(uint8 OP_CONSTANT, 1)
    chunk.writeChunk(uint8 index, 1)
    chunk.writeChunk(uint8 OP_CONSTANT_LONG, 1)
    chunk.writeChunk(index2, 1)
    chunk.writeChunk(uint8 OP_RETURN, 1)
    echo "Disassembling chunk"
    chunk.disassembleChunk("test chunk")
    echo "Interpreting bytecode instructions"
    echo fmt"Result: {bytecodeVM.interpret(chunk)}"
    bytecodeVM.freeVM()
    chunk.freeChunk()



when isMainModule:
    main()

