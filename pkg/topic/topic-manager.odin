package topic

import "core:fmt"

TopicManager :: struct {
	topics: map[string]^Topic,
}

destroy_topic_manager :: proc(topic_manager: ^TopicManager) {
	for _, topic in topic_manager.topics {
		destroy(topic)
	}

	delete(topic_manager.topics)
	free(topic_manager)
}

add_topic :: proc(topic_manager: ^TopicManager, topic: ^Topic) -> TopicDataError {
	if cast(string)topic.name in topic_manager.topics {
		return .DUPLICATE_TOPIC
	}

	topic_manager.topics[cast(string)topic.name] = topic
	return nil
}

subscribe_topic :: proc(topic_manager: ^TopicManager, topic_name: []u8, client_id: [16]u8) -> TopicDataError {
	name := cast(string)topic_name
	if name not_in topic_manager.topics {
		return .TOPIC_NOT_FOUND
	}

	topic := topic_manager.topics[name]

	append(&topic.clients, client_id)

	fmt.println(client_id, name)
	
	return nil
}

get_clients :: proc(topic_manager: ^TopicManager, topic_name: []u8) -> ([][16]u8,TopicDataError) {
	name := cast(string)topic_name
	if name not_in topic_manager.topics {
		return [][16]u8{}, .TOPIC_NOT_FOUND
	}

	topic := topic_manager.topics[name]
	return topic.clients[:], nil
}


