package daemon

import "core:sync/chan"
import "core:net"
import "core:fmt"

import "../protocol"
import "../topic"


DaemonConnection :: struct {
	daemon: ^Daemon,
	server: net.TCP_Socket,
	client: net.TCP_Socket,
	source: net.Endpoint,
	packet: ^protocol.Packet,
	header: [protocol.RHEOS_HEADER_SIZE]u8,
	message_id: [16]u8,
	id: u64,
}

destroy_connection :: proc(connection: ^DaemonConnection) {
	protocol.destroy_packet(connection.packet)	
	net.close(connection.client)
	free(connection)
}

handleConnectionChannel :: proc(reciever: chan.Chan(^DaemonConnection, .Recv), id: int) {
	for {
		connection, ok := chan.recv(reciever)
		if !ok {
			break
		}

		err := handleConnection(connection)
		if err == nil {
			free(connection)
		}
	}

	fmt.printf("Stopping worker: %d \n", id)
}

handleConnection :: proc(connection: ^DaemonConnection) -> DaemonError {
	header := [protocol.RHEOS_HEADER_SIZE]u8{}

	n, err := net.recv_tcp(connection.client, header[:])
	if err != nil && err != net.TCP_Recv_Error.None {
		return err
	}

	if !protocol.is_rheos_protocol(header[:]) {
		return protocol.PROTOCOL_ERROR.CORRUPTED_DATA
	}

	opcode := protocol.get_opcode(header[RHEOS_HEADER_SIZE - 17])
	if opcode == .INVALID_OPERATION {
		connection.packet.operation = protocol.OP_CODE.INVALID_OPERATION
		return protocol.PROTOCOL_ERROR.INVALID_OPERATION
	}
	connection.packet.operation  = opcode

	length, _err := protocol.get_content_length(header[:])
	if _err != protocol.PROTOCOL_ERROR.NONE {
		return _err
	}

	client_id := protocol.get_client_id(header[:])
	connection.packet.client_id = client_id

	content := make([]u8, length)
	n, err = net.recv_tcp(connection.client, content)
	if err != nil && err != net.TCP_Recv_Error.None {
		free(connection.packet)
		free(connection)
		return err
	}
	connection.packet.data = content
	
	connection.daemon.connections[client_id] = connection

	packet_processing_err := process_packet(connection) 
	
	ack_packet := [18]u8{}
	if packet_processing_err != nil {
		ack_packet = protocol.create_ack_packet(connection.message_id, .FAILED)
	} else {
		ack_packet = protocol.create_ack_packet(connection.message_id)
	}
	_ = net.send_tcp(connection.client, ack_packet[:]) or_return

	
	return nil
}

process_packet :: proc(connection: ^DaemonConnection) -> DaemonError {
	packet := connection.packet
	daemon := connection.daemon
	topic_manager := daemon.topic_manager

	#partial switch packet.operation {
	 case  .CREATE:
		_topic := topic.create_topic(packet.client_id, packet.data) or_return
		topic.add_topic(topic_manager, &_topic) or_return
	
	case .SUBSCRIBE:
		topic_name := topic.get_event_name(packet.data) or_return
		topic.subscribe_topic(topic_manager, topic_name, packet.client_id) or_return
	
	case .PUBLISH:
		publish_topic(connection) or_return
	}

	return nil
}

publish_topic :: proc(connection: ^DaemonConnection) -> DaemonError {
	packet := connection.packet	
	daemon := connection.daemon
	topic_manager := daemon.topic_manager

	topic_name := topic.get_event_name(packet.data) or_return
	clients := topic.get_clients(topic_manager, topic_name) or_return

	for client in clients {
		if client == connection.packet.client_id {
			continue
		}

		client_connection := daemon.connections[client]
		data := topic.get_data(packet.data) or_return

		
	_ = net.send_tcp(client_connection.client, data[:]) or_return

	}
	
	return nil
}

