package rheos

import "core:net"
import "core:fmt"
import "core:os"
import "core:flags"

import "pkg/daemon"

/*main :: proc () {
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
} */


Config :: struct {
	port: int `args:"name=port,required"`,
}

main :: proc () {
	config := Config{}

	err := flags.parse(&config, os.args[1:])
	if err != nil {
		fmt.printf("Error parsing args: %s", err)
		return
	}

	_daemon, daemon_err := daemon.new_daemon(net.Endpoint{
		port=config.port,
		address=net.IP4_Address{0,0,0,0}
	})
	if daemon_err != nil {
		fmt.printf("Error occured while creating daemon: %s", daemon_err)
	}

	defer daemon.close(&_daemon)

	fmt.printf("Starting server at port: %d", config.port)	
	err_ := daemon.start(&_daemon)
	if err_ != net.Create_Socket_Error.None || err != nil {
		fmt.printf("Error occured while creating server: %s", err_)
	}
	
}

