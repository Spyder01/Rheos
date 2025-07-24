# Rheos Protocol Specification (Language-Agnostic)

## Overview

Rheos is a binary message protocol optimized for event-driven messaging. This specification defines the structure and behavior of messages exchanged between clients and a central broker in the Rheos system.

---

## 1. Request Packet

### Header (22 bytes)

* **Byte 0**: Magic Byte (`0xFA`) — identifies the packet as a Rheos request.
* **Bytes 1–4**: Payload Length (unsigned 32-bit integer, Little Endian).
* **Bytes 5–20**: Client ID (16-byte UUID).
* **Byte 21**: Operation Code (see below).

### Body

* **Bytes 22–N**: Payload data specific to the operation.

### Operation Codes

| Code | Name               |
| ---- | ------------------ |
| 0    | CREATE             |
| 1    | SUBSCRIBE          |
| 2    | PUBLISH            |
| 3    | INVALID\_OPERATION |

### Errors

* `CORRUPTED_DATA` – Malformed or incomplete header.
* `INVALID_OPERATION` – Unknown or out-of-range opcode.
* `NONE` – No error.

---

## 2. Acknowledgment Packet

### Format (18 bytes total)

* **Byte 0**: Acknowledgment Magic Byte (`0xAC`).
* **Bytes 1–16**: Message ID (UUID of the original message).
* **Byte 17**: Acknowledgment Code:

  * `0` – SUCCESS
  * `1` – FAILED

---

## 3. Response Packet

### Header (21 bytes)

* **Byte 0**: Header Size (fixed value `21`).
* **Bytes 1–4**: Payload Length (unsigned 32-bit integer, Little Endian).
* **Bytes 5–20**: Sender ID (16-byte UUID).

### Body

* **Bytes 21–N**: Payload content.

### Errors

* `TRANSLATION_ERROR` – Failure in encoding/decoding payload.

---

## 4. Topic Encoding

Topics are defined as binary objects that include a name, a parent ID, and a list of client IDs.

### Serialized Format

* **Bytes 0–1**: Length of topic name (unsigned 16-bit integer, Little Endian).
* **Bytes 2–(N+1)**: Topic name.
* **Bytes (N+2)–(N+3)**: Payload length (unsigned 16-bit integer, Little Endian).
* **Bytes (N+4)–(N+3+M)**: Payload data.

### Topic Object Structure

* **parent**: 16-byte UUID.
* **name**: Binary string.
* **clients**: List of 16-byte UUIDs.

### Errors

* `CORRUPTED_TOPIC` – Incomplete or malformed data.
* `DUPLICATE_TOPIC` – Topic already exists.
* `TOPIC_NOT_FOUND` – Reference to a nonexistent topic.

---

## 5. Helper Operations

### Packet Validation

* **`is_rheos_protocol(data)`**: Returns true if the first byte is `0xFA`.
* **`get_content_length(header)`**: Extracts payload length.
* **`get_opcode(opcode_byte)`**: Validates and casts opcode byte.
* **`get_client_id(header)`**: Extracts UUID from header.
### Memory Management

* Implementations should free any dynamically allocated memory associated with topic names or payloads.

---

## 6. General Notes

* All UUIDs are 16 bytes and must follow standard UUID formatting.
* Endianness: All multi-byte integers are Little Endian.
* Binary format assumes strict byte positioning. Any parsing must check bounds explicitly.
* Implementation must gracefully handle malformed packets.

---

## 7. Potential Extensions

* Message-level compression flags
* QoS (Quality of Service) levels
* Authentication headers
* Wildcard support for topics

---

## 8. Compatibility

This protocol is transport-agnostic and can be used over any reliable byte stream (e.g., TCP).

