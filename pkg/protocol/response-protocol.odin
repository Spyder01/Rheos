package protocol

import "core:encoding/endian"

RHEOS_RESPONSE_MAGIC :: cast(u8)0xFA
RHEOS_RESPONSE_HEADER_SIZE :: 21

RESPONSE_PROTOCOL_ERROR :: enum {
	TRANSLATION_ERROR,
}

create_response_protocol :: proc(sender_id: [16]u8, data: []u8, allocator := context.allocator) -> ([]u8, RESPONSE_PROTOCOL_ERROR)  {
	buffer := make([]u8, RHEOS_RESPONSE_HEADER_SIZE + len(data), allocator)

	buffer[0] = RHEOS_RESPONSE_HEADER_SIZE
	
	ok := endian.put_u32(buffer[1:5], .Little, cast(u32)len(data))
	if !ok {
		free(&buffer)
		return []u8{}, .TRANSLATION_ERROR
	}

	for index, byte in sender_id {
		buffer[5+index] = cast(u8)byte
	}
	
	for i in 0..<len(data) {
		buffer[RHEOS_RESPONSE_HEADER_SIZE + i] = data[i]  
	}
	
	return buffer, nil
}

