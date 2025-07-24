package hash 

import "core:mem"
import "core:strconv"

murmur_hash3_x86_32 :: proc(data: []u8, seed: u32) -> u32 {
    c1 := u32(0xcc9e2d51)
    c2 := u32(0x1b873593)

    hash := seed
    nblocks := len(data) / 4

    for i in 0..<nblocks {
        k := mem.bytes_to_value<u32>(data[i*4..][0..4])
        k *= c1
        k = (k << 15) | (k >> (32 - 15))
        k *= c2

        hash ^= k
        hash = (hash << 13) | (hash >> (32 - 13))
        hash = hash*5 + 0xe6546b64
    }

    tail := data[nblocks*4..]
    k1 := u32(0)

    switch len(tail) {
    case 3:
        k1 ^= u32(tail[2]) << 16
        fallthrough
    case 2:
        k1 ^= u32(tail[1]) << 8
        fallthrough
    case 1:
        k1 ^= u32(tail[0])
        k1 *= c1
        k1 = (k1 << 15) | (k1 >> (32 - 15))
        k1 *= c2
        hash ^= k1
    }

    hash ^= u32(len(data))
    hash ^= (hash >> 16)
    hash *= 0x85ebca6b
    hash ^= (hash >> 13)
    hash *= 0xc2b2ae35
    hash ^= (hash >> 16)

    return hash
}
