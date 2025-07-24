package eventloop

import "core:fmt"

EventType :: enum {
	EVENT_JOB,
	EVENT_SHUTDOWN,
}

FD :: distinct i64

Event :: struct {
	id: u64,
	fd: FD,
	type: EventType,
	payload: rawptr,

	on_start_handler: proc(e: ^Event),
	on_end_handler: proc(e: ^Event)
}

create_event :: proc(fd: FD, type: EventType = .EVENT_JOB, payload: rawptr = nil, on_end_handler := proc(e: ^Event){}, on_start_handler := proc(e: ^Event){}) -> Event {
	return Event{
		id=0,
		fd=fd,
		payload=payload,
		type=type,
		on_start_handler=on_start_handler,
		on_end_handler=on_end_handler,
	}
}

destroy_event :: proc(event: ^Event) {
	free(event)
}

dispatch_event :: proc(event: ^Event, handlers: []proc(event: ^Event)) {
	for handler in handlers {
		handler(event)
	}
}

EventLoop :: struct {
	is_running: bool,
	event_list: ^EventList,
	handlers: map[EventType][dynamic]proc(event: ^Event),
}

event_loop_init :: proc(batch_size := 1000, allocator := context.allocator) -> EventLoop {
	event_list := event_list_init(batch_size, allocator)	
	handlers := make(map[EventType][dynamic]proc(event: ^Event), allocator)
	io := nbio.IO{}

	nbio.init(&io)

	return EventLoop{
		event_list=&event_list,
		is_running=false,
		handlers=handlers,
		io=io,
	}
}

destroy_event_loop :: proc(el: ^EventLoop) {
	for type in el.handlers {
		delete_dynamic_array(el.handlers[type])
	}

	destroy_event_list(el.event_list)
}

event_loop_attach_event :: proc(el: ^EventLoop, event: ^Event) -> u64 {
	
	return event_list_add_event(el.event_list, event) 
}

event_loop_subscribe :: proc(el: ^EventLoop, type: EventType, handler: proc(event: ^Event)) {
	handlers := el.handlers[type]
	append(&handlers, handler)	

	el.handlers[type] = handlers
}

event_loop_run :: proc(el: ^EventLoop) {
	el.is_running = true

	for el.is_running {
		for event in el.event_list.events {
			if event == nil {
				continue
			}
			
			event.on_start_handler(event)
			dispatch_event(event, el.handlers[event.type][:])
			event.on_end_handler(event)

			if event.type == EventType.EVENT_SHUTDOWN {
				el.is_running = false	
			}
			
			event_list_free_event(el.event_list, event)
		}
	}
}

