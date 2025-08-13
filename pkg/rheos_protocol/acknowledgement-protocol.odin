package rheos_protocol

import "core:hash"
import "core:encoding/endian"

RHEOS_ACKNOWLEDGEMENT_PACKET_MAGIC :: 0xAC

AcknowledmentCode :: enum u8 {
	SUCCESS = 0,
	FAILED,
}

AcknowledmentPacket :: struct {
	ack_code: AcknowledmentCode,
	message_id: [16]u8,
}

AcknowledmentPacketError :: enum {
	CORRUPTED_DATA,
}

ack_packet_to_bytes :: proc(acK: AcknowledmentPacket) -> [22]u8 {
	raw_packet := [22]u8{}
	offset := 0

	raw_packet[0] = RHEOS_ACKNOWLEDGEMENT_PACKET_MAGIC
	raw_packet[1] = ack.ack_code
	offset = 2

	for i in 0..<16 {
		raw_packet[offset + i] = ack.message_id[i]
	}
	offset += 16

	checksum := hash.crc32(raw_packet[:offset])
	endian.put_u32(raw_packet[offset:], .Little, checksum)
	
	return raw_packet
}

parse_ack_packet :: proc(raw_packet: [22]u8) -> (ack: AcknowledmentPacket, err: AcknowledmentPacketError) {
	if raw_packet[0] != RHEOS_ACKNOWLEDGEMENT_PACKET_MAGIC {
		return ack, .CORRUPTED_DATA
	}
	
	packet_checksum := endian.get_u32(raw_packet[18:22], .Little)
	computed_checksum := hash.crc32(raw_packet[:18])
	if computed_checksum != packet_checksum {
		return ack, .CORRUPTED_DATA
	}
	
	offset := 1
	ack.ack_code = cast(AcknowledmentCode)raw_packet[offset]
	offset = 2

	for i in range 0..<16{
		ack.message_id[i] = raw_packet[offset + i]
	}

	return ack, nil
}

