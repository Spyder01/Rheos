# Rheos Network Protocol Specification

## Overview

The **Rheos Protocol** is a lightweight binary wire format for sending events between clients and servers.
It supports three main operations (`CREATE`, `SUBSCRIBE`, `PUBLISH`) and an acknowledgement mechanism.
Each packet is composed of a **header**, a **body**, and a **CRC32 checksum** for data integrity.

---

## Constants

| Name                                 | Value      | Description                           |
| ------------------------------------ | ---------- | ------------------------------------- |
| `RHEOS_MAGIC`                        | `0xFA`     | Identifies a valid Rheos packet       |
| `RHEOS_HEADER_SIZE`                  | `22` bytes | Fixed size of the Rheos packet header |
| `RHEOS_ACKNOWLEDGEMENT_PACKET_MAGIC` | `0xAC`     | Identifies an acknowledgement packet  |

---

## Enumerations

### Operation Codes (`OP_CODE`)

| Name                | Value | Description                           |
| ------------------- | ----- | ------------------------------------- |
| `CREATE`            | `0`   | Create a new event stream             |
| `SUBSCRIBE`         | `1`   | Subscribe to an existing event stream |
| `PUBLISH`           | `2`   | Publish data to an event stream       |
| `INVALID_OPERATION` | `3`   | Reserved / Invalid                    |

---

### Acknowledgement Codes (`AcknowledmentCode`)

| Name      | Value | Description              |
| --------- | ----- | ------------------------ |
| `SUCCESS` | `0`   | Operation was successful |
| `FAILED`  | `1`   | Operation failed         |

---

## Packet Structure

### Rheos Event Packet

A Rheos Event Packet is the main format for carrying event data.

```
+----------------+--------------------+--------------------+
| Header (22B)   | Body (variable)    | CRC32 (4B)          |
+----------------+--------------------+--------------------+
```

#### **Header Layout** (`RHEOS_HEADER_SIZE` = 22 bytes)

| Offset | Size | Field          | Type      | Description                                           |
| ------ | ---- | -------------- | --------- | ----------------------------------------------------- |
| `0`    | 1    | Magic          | `u8`      | Must be `RHEOS_MAGIC` (0xFA)                          |
| `1`    | 4    | Payload Length | `u32 LE`  | Length of body in bytes (excluding header & checksum) |
| `5`    | 16   | Client ID      | `[16]u8`  | Unique identifier for the client                      |
| `21`   | 1    | Operation Code | `OP_CODE` | The type of operation                                 |

---

#### **Body Layout**

| Offset | Size | Field             | Type     | Description                     |
| ------ | ---- | ----------------- | -------- | ------------------------------- |
| `0`    | 2    | Event Name Length | `u16 LE` | Number of bytes in `event_name` |
| `2`    | 4    | Data Length       | `u32 LE` | Number of bytes in `data`       |
| `6`    | N    | Event Name        | `[]u8`   | UTF-8 encoded event name        |
| `6+N`  | M    | Data              | `[]u8`   | Raw event data                  |

---

#### **Checksum**

* **Size:** `4 bytes`
* **Position:** End of packet
* **Algorithm:** CRC32 of all bytes **before** the checksum field.
* **Purpose:** Ensures packet integrity.

---

#### **Encoding Process**

1. Compute `payload_length = 2 + 4 + event_name_length + data_length`
2. Write header fields in order.
3. Write body fields (`event_name_length`, `data_length`, `event_name`, `data`).
4. Compute CRC32 over all preceding bytes.
5. Append CRC32 (Little Endian).

---

#### **Decoding Process**

1. Validate `RHEOS_MAGIC`.
2. Read `payload_length` and verify total packet size.
3. Extract `client_id` and `op_code`.
4. Compute and verify CRC32 checksum.
5. Parse `event_name_length` and `data_length`.
6. Extract `event_name` and `data`.

---

### Acknowledgement Packet

Used for confirming the receipt or result of an operation.

```
+------------------+--------------------+------------------+
| Header (2B)      | Message ID (16B)   | CRC32 (4B)        |
+------------------+--------------------+------------------+
```

#### **Layout**

| Offset | Size | Field      | Type                | Description                                         |
| ------ | ---- | ---------- | ------------------- | --------------------------------------------------- |
| `0`    | 1    | Magic      | `u8`                | Must be `RHEOS_ACKNOWLEDGEMENT_PACKET_MAGIC` (0xAC) |
| `1`    | 1    | Ack Code   | `AcknowledmentCode` | Status of the operation                             |
| `2`    | 16   | Message ID | `[16]u8`            | Identifier of the acknowledged message              |
| `18`   | 4    | CRC32      | `u32 LE`            | Checksum over first 18 bytes                        |

---

#### **Encoding Process**

1. Write magic (`0xAC`).
2. Write acknowledgement code.
3. Write message ID.
4. Compute CRC32 over first 18 bytes.
5. Append CRC32 (Little Endian).

---

#### **Decoding Process**

1. Validate `RHEOS_ACKNOWLEDGEMENT_PACKET_MAGIC`.
2. Read acknowledgement code.
3. Read message ID.
4. Compute and verify CRC32.

---

## Error Codes

### RheosPacketError

* `CORRUPTED_DATA`: Packet failed validation (magic, length, checksum, or field bounds).

### AcknowledmentPacketError

* `CORRUPTED_DATA`: Packet failed validation (magic or checksum).

---

## Example Flow

1. Client sends `PUBLISH` packet with:

   * Client ID
   * Event name `"sensor_update"`
   * Payload containing sensor data
2. Server parses packet and processes event.
3. Server replies with an `AcknowledgementPacket` containing:

   * `SUCCESS` code
   * Original message ID

---

## Alignment & Endianness

* All multi-byte integers are **Little Endian**.
* Strings are raw byte arrays, typically UTF-8 encoded.

---
