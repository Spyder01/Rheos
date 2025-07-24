package eventloop

import "core:fmt"
import "core:math"

EventList :: struct {
    events: [dynamic]^Event,
    free_indices: [dynamic]u64,
}

event_list_init :: proc(batch_size: int = 1000, allocator := context.allocator) -> EventList {
    return EventList{
        events = make([dynamic]^Event, allocator),
        free_indices = make([dynamic]u64, allocator),
    };
}

_preallocate_event_list :: proc(el: ^EventList, batch_size := 1000) {
    start := len(el.events);
    for i in start..<start + batch_size {
        append(&el.events, nil);
        append(&el.free_indices, cast(u64)i);
    }
}

destroy_event_list :: proc(el: ^EventList) {
    for event in el.events {
        if event != nil {
            destroy_event(event);
        }
    }
    delete_dynamic_array(el.events);
    delete_dynamic_array(el.free_indices);
}

event_list_add_event :: proc(el: ^EventList, event: ^Event) -> u64 {
    if len(el.free_indices) == 0 {
        _preallocate_event_list(el); // Default batch_size
    }

    last_index := len(el.free_indices) - 1;
    index := el.free_indices[last_index];
		free_indices := make([dynamic]u64)

    append(&free_indices, ..el.free_indices[0:last_index])

		el.free_indices = free_indices

    event.id = index;
    el.events[index] = event;
    return index;
}

event_list_free_event :: proc(el: ^EventList, event: ^Event) {
    id := event.id;
    if id >= cast(u64)len(el.events) {
        fmt.println("Invalid free id", id);
        return;
    }

    destroy_event(event);
    el.events[id] = nil;
    append(&el.free_indices, id);
}

event_list_len :: proc(el: ^EventList) -> int {
    return len(el.events) - len(el.free_indices);
}

event_list_get_event :: proc(el: ^EventList, id: u64) -> ^Event {
    if id >= cast(u64)len(el.events) {
        return nil;
    }
    return el.events[id];
}
