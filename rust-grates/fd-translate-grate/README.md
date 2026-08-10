# fd-translate-grate

Virtual file descriptors for Lind. This grate maps the file descriptors seen
by a cage to the underlying descriptors used by the Lind runtime. New
descriptors receive virtual numbers, and later operations translate them
before being forwarded. This gives each cage its own descriptor namespace.

## What it handles

**Creating descriptors**: Calls such as `open()`, `socket()`, `pipe()`, and
`dup()` return virtual descriptors and store their underlying mappings.

**Using descriptors**: File, directory, and socket operations translate
virtual descriptors before forwarding the syscall.

**Polling**: `poll()`, `select()`, and epoll calls translate descriptor arrays
and sets in both directions.

**Processes**: A new process receives a copy of its parent's fdtable. On
`exec()`, close-on-exec descriptors are removed and descriptors 0-2 are kept
available.

## Intercepted syscalls

| Category | Syscalls |
|----------|----------|
| Descriptor creation and duplication | open, openat, dup, dup2, dup3, fcntl, pipe, pipe2 |
| File I/O and metadata | read, write, pread, pwrite, preadv, pwritev, readv, writev, close, lseek, ioctl, fstat, fsync, fdatasync, ftruncate, flock, fchmod, fchdir, getdents, fstatfs, sync_file_range, mmap |
| Directory-relative paths | unlinkat, symlinkat, readlinkat, fchmodat |
| Sockets | socket, socketpair, bind, listen, connect, accept, accept4, shutdown, sendto, recvfrom, sendmsg, recvmsg, setsockopt, getsockopt, getsockname, getpeername |
| Event polling | poll, ppoll, select, epoll_create, epoll_create1, epoll_ctl, epoll_wait |
| Lifecycle | clone, exec |

## Architecture

- `src/main.rs` starts the grate and manages fdtable state across `clone` and
  `exec`.
- `lib/grate-rs/src/fd_support.rs` provides the shared translation handlers.
- The `fdtables` dependency stores each cage's descriptor mappings.

## Usage

```bash
lind-wasm grates/fd-translate-grate.cwasm <program> [args...]
```

## Building

From the repository root:

```bash
make rust/fd-translate-grate
```

## Known limitations

- Only the syscalls listed above use descriptor translation.
- `select()` supports descriptors below `FD_SETSIZE` (1024).
