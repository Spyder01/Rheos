package protocol

import "core:encoding/endian"
import "core:net"
import "core:fmt"

RHEOS_MAGIC :: cast(u8)0xFA
RHEOS_HEADER_SIZE :: 22

PROTOCOL_ERROR :: enum {
	CORRUPTED_DATA,
	INVALID_OPERATION,
	NONE,
}

DECODE_PROTOCOL_ERROR :: union {
	PROTOCOL_ERROR,
	net.TCP_Recv_Error,
}

OP_CODE :: enum u8 {
	CREATE = 0,
	SUBSCRIBE,
	PUBLISH,

	INVALID_OPERATION,
}

Packet :: struct {
	operation: OP_CODE,
	client_id: [16]u8,
	data: []u8	
}

destroy_packet :: proc(packet: ^Packet) {
	free(&packet.data)
	free(packet)
}

is_rheos_protocol :: proc(data: []u8) -> bool {
	if len(data) < RHEOS_HEADER_SIZE {
		return false
	}
	return data[0] == RHEOS_MAGIC
}

get_content_length :: proc(header: []u8) -> (u32, PROTOCOL_ERROR) {
	if len(header) < RHEOS_HEADER_SIZE {
		return 0, PROTOCOL_ERROR.CORRUPTED_DATA
	}

	length, ok := endian.get_u32(header[1:5], .Little)
	if !ok {
		return 0, PROTOCOL_ERROR.CORRUPTED_DATA
	}

	return length, PROTOCOL_ERROR.NONE
}

get_opcode :: proc(opcode_raw: u8) -> OP_CODE {
	if opcode_raw >= cast(u8)OP_CODE.INVALID_OPERATION {
		return .INVALID_OPERATION
	}
	
	return cast(OP_CODE)opcode_raw
}

get_client_id :: proc(header: []u8) -> [16]u8 {
	client_id: [16]u8
	copy_slice(client_id[:], header[RHEOS_HEADER_SIZE - 16:RHEOS_HEADER_SIZE])
	return client_id
}

