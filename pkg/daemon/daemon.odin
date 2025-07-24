package daemon

import "base:runtime"

import "core:net"
import "core:fmt"
import "core:os"
import "core:sync/chan"
import "core:thread"
import "core:encoding/uuid"

import "../protocol"
import "../topic"

RHEOS_HEADER_SIZE :: protocol.RHEOS_HEADER_SIZE
WORKER_COUNT :: 4

Daemon :: struct {
	endpoint: net.Endpoint,
	is_running: bool,
	connection_number: u64,
	server_fd: net.TCP_Socket,
	connections: map[[16]u8]^DaemonConnection,
	worker_chans: [WORKER_COUNT]chan.Chan(^DaemonConnection),
	topic_manager: ^topic.TopicManager,
}

new_daemon :: proc(endpoint: net.Endpoint, allocator := context.allocator) -> (Daemon, runtime.Allocator_Error) {
	worker_chans := [WORKER_COUNT]chan.Chan(^DaemonConnection){}
	topic_manager := new(topic.TopicManager)

	for i in 0..<WORKER_COUNT {
		c, err := chan.create(chan.Chan(^DaemonConnection), allocator)
		if err != nil {
			return Daemon{}, err
		}
		worker_chans[i] = c
	}


	return Daemon{
		endpoint=endpoint,
		is_running=false,
		connection_number=1,
		worker_chans=worker_chans,
		topic_manager=topic_manager,
	}, nil
}

close :: proc(daemon: ^Daemon) {
	for client_id in daemon.connections {
		connection := daemon.connections[client_id]
		if connection.packet == nil {
			continue
		}

		destroy_connection(connection)
	}

	delete(daemon.connections)

	for worker_chan in daemon.worker_chans {
		chan.destroy(worker_chan)
	}

	net.close(daemon.server_fd)
	topic.destroy_topic_manager(daemon.topic_manager)
}

DaemonError :: union {
	protocol.PROTOCOL_ERROR,
	net.TCP_Recv_Error,
	net.Accept_Error,
	net.TCP_Send_Error,
	topic.TopicDataError,
}

start :: proc(daemon: ^Daemon) -> net.Network_Error {
	socket := net.listen_tcp(daemon.endpoint) or_return
	daemon.server_fd = socket
	daemon.is_running = true

	consumer_threads := [WORKER_COUNT]^thread.Thread{}
	sender_chan := [WORKER_COUNT]chan.Chan(^DaemonConnection, .Send){}

	for i in 0..<WORKER_COUNT {
		consumer_threads[i] = thread.create_and_start_with_poly_data2(chan.as_recv(daemon.worker_chans[i]), i, handleConnectionChannel)

		sender_chan[i] = chan.as_send(daemon.worker_chans[i])
	}

	for daemon.is_running {
		id := (daemon.connection_number - 1)%WORKER_COUNT
		daemon_loop(daemon, socket, sender_chan[id], cast(u8)id)
		daemon.connection_number += 1
	}

	thread.join_multiple(..consumer_threads[:])


	for i in 0..<WORKER_COUNT {
		thread.destroy(consumer_threads[i])
	}

	return net.Create_Socket_Error.None
}

daemon_loop :: proc(daemon: ^Daemon, socket: net.TCP_Socket, sender: chan.Chan(^DaemonConnection, .Send), worker_id: u8) -> net.Accept_Error {
	conn, source := net.accept_tcp(daemon.server_fd) or_return
	
	connection := new(DaemonConnection)

	connection.daemon = daemon
	connection.server = socket
	connection.client = conn
	connection.source = source
	connection.packet = new(protocol.Packet)
	connection.id = daemon.connection_number
	//connection.message_id = cast([16]u8)uuid.generate_v4()

	success := chan.send(sender, connection)	

	return nil
}

