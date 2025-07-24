# Rheos (Prototype)

**Rheos** is a high-performance, event-driven messaging system built around a custom binary protocol designed for speed, minimal memory usage, and efficient multiplexed communication.

> ⚠️ **Note:** This is a **prototype** and is still under active development. Expect breaking changes, incomplete features, and minimal validation.

---

## Features

- Custom lightweight binary protocol (`Rheos Protocol`)  
- Topic-based publish/subscribe model  
- Simple TCP-based daemon server  
- Command-line flag support for runtime configuration  

---

## Usage

### Build & Run

```bash
rheos --port 9000
````

You must specify the port using the `--port` flag.

### Example

```bash
rheos --port 7070
```

Console output:

```
Starting server at port: 7070
```

---

## Command Line Flags

| Flag     | Description             | Required | Example       |
| -------- | ----------------------- | -------- | ------------- |
| `--port` | Port on which to listen | ✅        | `--port 9000` |

---

## Protocol

The Rheos server uses a custom binary protocol for all communication. You can find the detailed protocol specification here: [`protocol.md`](./protocol.md)

---

## Status

✅ **Implemented:**

* Custom protocol parser
* Basic server daemon with connection handling
* Request decoding (CREATE, SUBSCRIBE, PUBLISH)
* Response and Acknowledgment formats

🛠️ **Work in Progress:**

* Checksum for protocol
* In-memory topic registry
* Pull based event publication
* UDP Support
* Brokered message dispatching
* Client ID management and persistence
* Fault tolerance

🧪 **Upcoming:**

* CLI tooling
* Auth layer and secure transport
* Compression and batching
* Stress tests and benchmarking

---

## Contributing

Contributions are welcome! However, since the project is still in its early stages, major design changes are likely.

---

## License

MIT (To be confirmed)

---
