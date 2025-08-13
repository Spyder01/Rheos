package rheos_protocol

import "core:encoding/endian"
import "core:hash"


RHEOS_MAGIC :: cast(u8)0xFA
RHEOS_HEADER_SIZE :: 22

OP_CODE :: enum u8 {
	CREATE = 0,
	SUBSCRIBE,
	PUBLISH,

	INVALID_OPERATION,
}

RheosPacketHeader :: struct {
	payload_length: u32,			
	client_id: [16]u8,
	op_code: OP_CODE,
}

RheosPacketBody :: struct {
	event_name_length: u16,
	data_len: u32,	
	event_name: []u8,
	data: []u8,
}

RheosPacket :: struct {
	header: ^RheosPacketHeader,
	body: ^RheosPacketBody,
}

RheosPacketError :: enum {
	CORRUPTED_DATA
}

destroy_rheos_protocol :: proc(packet: ^RheosPacket) {
	free(packet.header)
	free(&packet.body.event_name)
	free(&packet.body.data)
	free(packet.body)
	free(packet)
}

rheos_packet_to_bytes :: proc(packet: RheosPacket, allocator := context.allocator) -> []u8 {
	packet.header.payload_length = 2 + 4 + packet.body.event_name_length + packet.body.data_len
	buffer_size := RHEOS_HEADER_SIZE + packet.header.payload_length + 4
	
	buffer := make([]u8, buffer_size, allocator)
	
	// header
	buffer[0] = RHEOS_MAGIC
	endian.put_u32(buffer[1:5], .Little, packet.header.payload_length)
	for i in 0..<16 {
		buffer[5+i] = packet.header.client_id[i]
	}
	buffer[21] = packet.header.op_code
	offset := RHEOS_HEADER_SIZE
	
	// body
	endian.put_u16(buffer[offset:offset+2], .Little, packet.body.event_name_length)	
	offset += 2

	endian.put_u32(buffer[offset:offset+4], .Little, packet.body.data_len)	
	offset += 4

	for i in 0..<packet.body.event_name_length {
		buffer[offset+i] = packet.body.event_name[i]
	}
	offset += packet.body.event_name_length

	for i in 0..<packet.body.data_len {
		buffer[offset + i] = packet.body.data[i]
	}
	offset += packet.body.data_len
	
	// checksum
	checksum := hash.crc32(buffer[:offset])
	endian.put_u32(buffer[offset:offset+4], .Little, checksum)	

	return buffer
}

parse_rheos_packet :: proc(raw_packet: []u8, allocator := context.allocator) -> (packet: RheosPacket, err: RheosPacketError) {
    offset := 0

    // Validate magic
    if raw_packet[offset] != RHEOS_MAGIC {
        return packet, .CORRUPTED_DATA
    }
    offset += 1

    // Read payload length
    payload_length, ok := endian.get_u32(raw_packet[offset:offset+4], .Little)
    if !ok {
        return packet, .CORRUPTED_DATA
    }
    offset += 4

    // Validate total size
    expected_size := RHEOS_HEADER_SIZE + int(payload_length) + 4
    if len(raw_packet) < expected_size {
        return packet, .CORRUPTED_DATA
    }

    // Read client_id
    client_id: [16]u8
    for i in 0..<16 {
        client_id[i] = raw_packet[offset+i]
    }
    offset += 16

    // Read op_code
    op_code := cast(OP_CODE)raw_packet[offset]
    offset += 1

    // Verify checksum
    raw_checksum, ok := endian.get_u32(raw_packet[expected_size-4:expected_size], .Little)
    if !ok {
        return packet, .CORRUPTED_DATA
    }
    computed_checksum := hash.crc32(raw_packet[:expected_size-4])
    if raw_checksum != computed_checksum {
        return packet, .CORRUPTED_DATA
    }

    // --- Parse body ---
    event_name_length, ok := endian.get_u16(raw_packet[offset:offset+2], .Little)
    if !ok {
        return packet, .CORRUPTED_DATA
    }
    offset += 2

    data_len, ok := endian.get_u32(raw_packet[offset:offset+4], .Little)
    if !ok {
        return packet, .CORRUPTED_DATA
    }
    offset += 4

    // Validate body bounds
    if offset + int(event_name_length) + int(data_len) > expected_size-4 {
        return packet, .CORRUPTED_DATA
    }

    // Copy event_name
    event_name := make([]u8, event_name_length, allocator)
    for i in 0..<event_name_length {
        event_name[i] = raw_packet[offset+i]
    }
    offset += event_name_length

    // Copy data
    data := make([]u8, data_len, allocator)
    for i in 0..<data_len {
        data[i] = raw_packet[offset+i]
    }
    offset += data_len

    // Allocate and fill structs
    header := new(RheosPacketHeader, allocator)
    header.payload_length = payload_length
    header.client_id = client_id
    header.op_code = op_code

    body := new(RheosPacketBody, allocator)
    body.event_name_length = event_name_length
    body.data_len = data_len
    body.event_name = event_name
    body.data = data
		
		packet.header = header
		packet.body = body

    return packet, nil
}

parse_rheos_header :: proc(raw_packet: []u8, allocator := context.allocator) -> (header: RheosPacketHeader, err: RheosPacketError) {
    offset := 0

    // Validate minimum size for header
    if len(raw_packet) < RHEOS_HEADER_SIZE {
        return header, .CORRUPTED_DATA
    }

    // Validate magic
    if raw_packet[offset] != RHEOS_MAGIC {
        return header, .CORRUPTED_DATA
    }
    offset += 1

    // Read payload length
    payload_length, ok := endian.get_u32(raw_packet[offset:offset+4], .Little)
    if !ok {
        return header, .CORRUPTED_DATA
    }
    offset += 4

    // Read client_id
    client_id: [16]u8
    for i in 0..<16 {
        client_id[i] = raw_packet[offset+i]
    }
    offset += 16

    // Read op_code
    op_code := cast(OP_CODE)raw_packet[offset]
    offset += 1

    // Allocate and fill header
    header.payload_length = payload_length
    header.client_id = client_id
    header.op_code = op_code

    return header, nil
}

