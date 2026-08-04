# devnull-grate

A grate that emulates `/dev/null` operations made by a cage. It intercepts
opens, reads, writes, and closes for `/dev/null` descriptors while forwarding
other operations through Lind's threei interposition layer.

This allows a caged program to use `/dev/null` without depending on the device
being present in the underlying filesystem. The grate does not store written
data or open a real backing file.

## How it works

1. **Handler registration**: At startup, the grate registers handlers for
   open, read, write, close, clone, execve, dup, and dup2 using `GrateBuilder`.

2. **Virtual descriptor allocation**: When the cage opens `/dev/null`, the
   grate allocates a virtual file descriptor through `fdtables` instead of
   forwarding the open call to the kernel.

3. **Null-device behavior**: Writes to a `/dev/null` descriptor return the
   requested byte count without storing any data. Reads return `0` to indicate
   end-of-file.

4. **Descriptor management and forwarding**: The grate maintains per-cage
   descriptor state across close, clone, exec, dup, and dup2 operations.
   Operations on other paths and descriptors are forwarded unchanged.

## Usage

```bash
lind-wasm grates/devnull-grate.cwasm <program> [args...]
```

### Example

Run a program with virtual `/dev/null` support:

```bash
lind-wasm grates/devnull-grate.cwasm myapp.cwasm
```

Inside the cage, writing five bytes to `/dev/null` returns `5`, while reading
from it returns `0`.

## Intercepted syscalls

| Category | Syscalls |
|----------|----------|
| File I/O | open, read, write, close |
| Descriptor management | dup, dup2 |
| Process lifecycle | clone, execve |

## Building

```bash
cd rust-grates/devnull-grate
cargo lind_compile --output-dir grates
```

## Testing

From the repository root, run only the `devnull-grate` tests:

```bash
make test GRATE=devnull-grate
```

The test verifies `/dev/null` reads and writes, multiple virtual descriptors,
large writes, closing descriptors, and pass-through access to a regular file.

## Code layout

- `src/main.rs`: handler registration through `GrateBuilder`, initial
  file-descriptor setup, and child execution.
- `src/handlers.rs`: `/dev/null` detection, virtual descriptor management,
  syscall forwarding, and process lifecycle handlers.
- `test/devnull_test.c`: tests opening, reading, writing, and closing
  `/dev/null`, multiple virtual descriptors, large writes, and pass-through
  operations on a regular file.
