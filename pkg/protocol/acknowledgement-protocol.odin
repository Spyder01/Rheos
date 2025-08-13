package protocol

import "core:encoding/uuid"
import "core:hash"
import "core:encoding/endian"

RHEOS_ACKNOWLEDGEMENT_PACKET_MAGIC :: 0xAC

AcknowledmentCode :: enum u8 {
	SUCCESS = 0,
	FAILED,
}

create_ack_packet :: proc(message_id: [16]u8, ack_code := AcknowledmentCode.SUCCESS) -> [22]u8 {
		packet := [22]u8{}

		packet[0] = RHEOS_ACKNOWLEDGEMENT_PACKET_MAGIC
		for i in 1..<17 {
			packet[i] = message_id[i-1] 
		}
		packet[17] = cast(u8)ack_code

		checksum := hash.crc32(packet[:18])
		endian.put_u32(packet[18:], .Little, checksum)

		return packet
}

