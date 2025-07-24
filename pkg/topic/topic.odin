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

	event_name_length, ok := endian.get_u16(data[0:2], .Little)
	if !ok {
		return []u8{}, .CORRUPTED_TOPIC
	}

	if cast(u16)len(data) < event_name_length + 2 {
		return []u8{}, .CORRUPTED_TOPIC
	}

	buffer := make([]u8, event_name_length)
	buffer = data[2:event_name_length +2]

	return buffer, nil
}


get_data :: proc(data: []u8) -> ([]u8, TopicDataError) {
	if len(data) < 2{
		return []u8{}, .CORRUPTED_TOPIC
	}
	
	event_name_length, res_ok := endian.get_u16(data[0:2], .Little)
	if !res_ok {
		return []u8{}, .CORRUPTED_TOPIC
	}


	if cast(u16)len(data) < event_name_length + 2 {
		return []u8{}, .CORRUPTED_TOPIC
	}

	data_len, ok := endian.get_u16(data[event_name_length+2:event_name_length+4], .Little)
	if !ok {
		return []u8{}, .CORRUPTED_TOPIC
	}

	buffer := make([]u8, data_len)
	buffer = data[event_name_length+4:event_name_length+data_len+6]
	
	
	return buffer, nil
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

