package topic

import "core:encoding/endian"
import "core:fmt"


Topic :: struct {
	parent: [16]u8,
	name: []u8,
	clients: [dynamic][16]u8,
}

TopicDataError :: enum {
	CORRUPTED_TOPIC,
	DUPLICATE_TOPIC,
	TOPIC_NOT_FOUND,
}

get_event_name :: proc(data: []u8) -> ([]u8, TopicDataError) {
	if len(data) < 2 {
		return []u8{}, .CORRUPTED_TOPIC
	}
	
	offset := 0
	event_name_length, ok := endian.get_u16(data[offset:offset + 2], .Little)
	if !ok {
		return []u8{}, .CORRUPTED_TOPIC
	}
	offset += 2

	// Shifting offset to after data length (4 bytes)
	offset += 4

	if len(data) < int(event_name_length + 2) {
		return []u8{}, .CORRUPTED_TOPIC
	}

	return data[offset:offset +cast(int)event_name_length], nil
}

get_data :: proc(data: []u8) -> ([]u8, TopicDataError) {
    if len(data) < 6 { // 2 for event_name_length, 4 for data_len
        return []u8{}, .CORRUPTED_TOPIC
    }
    
    offset := 0
    event_name_length, ok := endian.get_u16(data[offset:offset+2], .Little)
    if !ok {
        return []u8{}, .CORRUPTED_TOPIC
    }
    offset += 2

    data_len, data_len_ok := endian.get_u32(data[offset:offset+4], .Little)
    if !data_len_ok {
        return []u8{}, .CORRUPTED_TOPIC
    }
    offset += 4

    if len(data) < offset + int(event_name_length) + int(data_len) {
        return []u8{}, .CORRUPTED_TOPIC
    }

    offset += cast(int)event_name_length
    return data[offset:offset + cast(int)data_len], nil
}

parse_topic_payload :: proc(data: []u8) -> ([]u8, []u8, TopicDataError) {
    if len(data) < 6 {
        return []u8{}, []u8{}, .CORRUPTED_TOPIC
    }

    offset := 0
    event_name_length, ok := endian.get_u16(data[offset:offset+2], .Little)
    if !ok {
        return []u8{}, []u8{}, .CORRUPTED_TOPIC
    }
    offset += 2

    data_len, data_len_ok := endian.get_u32(data[offset:offset+4], .Little)
    if !data_len_ok {
        return []u8{}, []u8{}, .CORRUPTED_TOPIC
    }
    offset += 4

    if len(data) < offset + int(event_name_length) + int(data_len) {
        return []u8{}, []u8{}, .CORRUPTED_TOPIC
    }

    event_name := data[offset:offset+cast(int)event_name_length]
    offset += cast(int)event_name_length

    payload := data[offset:offset+cast(int)data_len]

    return event_name, payload, nil
}

create_topic :: proc(parent: [16]u8, data: []u8) -> (Topic, TopicDataError) {
	event_name, err := get_event_name(data) 
	if err != nil {
		return Topic{}, err
	}
	
	clients := make([dynamic][16]u8)

	return Topic{
		name=event_name,
		parent=parent,
		clients=clients,
	}, nil
}

destroy :: proc(topic: ^Topic) {
	delete(topic.clients)
	free(&topic.name)
	free(topic)	
}

