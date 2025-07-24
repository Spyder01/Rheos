package main

import (
	"encoding/binary"
	"fmt"
	"net"
	"sync"

	"github.com/google/uuid"
)

const (
	RHEOS_MAGIC      = 0xFA
	RHEOS_HEADER_LEN = 22 // Magic (1) + Length (4) + Opcode (1) + Client ID (16)

	// Opcodes
	OP_CREATE    = 0
	OP_SUBSCRIBE = 1
	OP_PUBLISH   = 2

	OP_INVALID = 255
)

// Builds payload following protocol:
// 2 bytes event name length + event name + 4 bytes content length + content
func makePayload(eventName string, content string) []byte {
	eventNameBytes := []byte(eventName)
	contentBytes := []byte(content)

	totalLen := 2 + len(eventNameBytes) + 4 + len(contentBytes)
	payload := make([]byte, totalLen)

	// Event name length
	binary.LittleEndian.PutUint16(payload[0:2], uint16(len(eventNameBytes)))
	copy(payload[2:], eventNameBytes)

	// Content length
	offset := 2 + len(eventNameBytes)
	binary.LittleEndian.PutUint32(payload[offset:offset+4], uint32(len(contentBytes)))
	copy(payload[offset+4:], contentBytes)

	return payload
}

// Builds a Rheos protocol request
func makeRheosRequest(opcode byte, payload []byte, clientID [16]byte) []byte {
	buf := make([]byte, RHEOS_HEADER_LEN+len(payload))

	buf[0] = RHEOS_MAGIC
	binary.LittleEndian.PutUint32(buf[1:5], uint32(len(payload)))
	buf[5] = opcode
	copy(buf[6:22], clientID[:])
	copy(buf[22:], payload)

	return buf
}

func makeCorruptedMagicRequest(opcode byte, payload []byte, clientID [16]byte) []byte {
	buf := make([]byte, RHEOS_HEADER_LEN+len(payload))
	buf[0] = 0x00 // Corrupted magic
	binary.LittleEndian.PutUint32(buf[1:5], uint32(len(payload)))
	buf[5] = opcode
	copy(buf[6:22], clientID[:])
	copy(buf[22:], payload)
	return buf
}

func makeTruncatedHeaderRequest() []byte {
	return []byte{RHEOS_MAGIC, 0x00, 0x00}
}

func makeInvalidLengthRequest(opcode byte, payload []byte, clientID [16]byte) []byte {
	buf := make([]byte, RHEOS_HEADER_LEN+len(payload))
	buf[0] = RHEOS_MAGIC
	binary.LittleEndian.PutUint32(buf[1:5], uint32(len(payload)+10))
	buf[5] = opcode
	copy(buf[6:22], clientID[:])
	copy(buf[22:], payload)
	return buf
}

func sendRequest(name string, request []byte, wg *sync.WaitGroup) {
	defer wg.Done()

	conn, err := net.Dial("tcp", "localhost:9000")
	if err != nil {
		fmt.Printf("[%s] Connection error: %v\n", name, err)
		return
	}
	defer conn.Close()

	_, err = conn.Write(request)
	if err != nil {
		fmt.Printf("[%s] Write error: %v\n", name, err)
		return
	}

	resp := make([]byte, 1024)
	n, err := conn.Read(resp)
	if err != nil {
		fmt.Printf("[%s] Read error: %v\n", name, err)
		return
	}

	fmt.Printf("[%s] Received: %x\n", name, resp[:n])
}

func main() {
	var wg sync.WaitGroup

	clientID := uuid.New()

	// Create request
	wg.Add(1)
	go sendRequest("create",
		makeRheosRequest(OP_CREATE, makePayload("client", "client123"), clientID), &wg)

	// Subscribe request
	wg.Add(1)
	go sendRequest("subscribe",
		makeRheosRequest(OP_SUBSCRIBE, makePayload("client", "jhsdgvjhfg"), clientID), &wg)

	// Publish request
	wg.Add(1)
	go sendRequest("publish",
		makeRheosRequest(OP_PUBLISH, makePayload("topic:test", "Hello World"), clientID), &wg)

	// Invalid opcode
	wg.Add(1)
	go sendRequest("invalid-opcode",
		makeRheosRequest(OP_INVALID, makePayload("fail", "should fail"), clientID), &wg)

	// Corrupted magic
	wg.Add(1)
	go sendRequest("corrupted-magic",
		makeCorruptedMagicRequest(OP_PUBLISH, makePayload("bad", "bad magic"), clientID), &wg)

	// Truncated header
	wg.Add(1)
	go sendRequest("truncated-header", makeTruncatedHeaderRequest(), &wg)

	// Invalid length
	wg.Add(1)
	go sendRequest("invalid-length",
		makeInvalidLengthRequest(OP_SUBSCRIBE, makePayload("topic", "short"), clientID), &wg)

	// Concurrent publishes
	for i := 1; i <= 3; i++ {
		wg.Add(1)
		go sendRequest(fmt.Sprintf("concurrent-pub-%d", i),
			makeRheosRequest(OP_PUBLISH,
				makePayload("topic:test", fmt.Sprintf("Msg %d", i)), clientID),
			&wg)
	}

	wg.Wait()
	fmt.Println("✅ All test cases completed.")
}
