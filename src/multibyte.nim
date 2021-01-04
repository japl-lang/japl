
proc toDouble*(input: int | uint | uint16): array[2, uint8] =
    cast[array[2, uint8]](uint16(input))

proc fromDouble*(input: array[2, uint8]): uint16 =
    copyMem(result.addr, unsafeAddr(input), sizeof(uint16))

