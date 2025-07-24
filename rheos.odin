package rheos

import "core:net"
import "core:fmt"

import "pkg/daemon"

main :: proc () {
	_daemon, _	:= daemon.new_daemon(net.Endpoint{
		port=9000,
		address=net.IP4_Address{0,0,0,0}
	})
	defer daemon.close(&_daemon)

	fmt.println("Starting server.")	
	err := daemon.start(&_daemon)
	if err != net.Create_Socket_Error.None || err != nil {
		fmt.println("Error occured while creating server")
	}
}

