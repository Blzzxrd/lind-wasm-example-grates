# strace-grate

A grate that logs system calls made by a cage. It records each registered
syscall's name, arguments, and return value while forwarding the call through
Lind's threei interposition layer.

This allows a cage's behavior to be observed without modifying the caged
program. The grate does not intentionally change syscall arguments or return
values.

## How it works

1. **Handler registration**: At startup, the grate registers handlers for 86
   supported syscalls using `GrateBuilder`.

2. **Argument formatting**: Numeric arguments are printed as decimal values.
   Arguments marked as C strings are copied from cage memory and printed as
   quoted strings. String reads are limited to 256 bytes, and an unreadable
   pointer is displayed as `<bad_ptr>`.

3. **Transparent forwarding**: Each handler forwards the original syscall
   number and arguments using `make_threei_call`.

4. **Trace output**: The syscall name and arguments are printed before the
   call is forwarded. The returned value is printed after the call completes
   and is then returned to the cage.

## Usage

```bash
lind-wasm grates/strace-grate.cwasm <program> [args...]
```

### Example

Trace the system calls made by `myapp.cwasm`:

```bash
lind-wasm grates/strace-grate.cwasm myapp.cwasm
```

Example output:

```text
open_syscall("/tmp/example.txt", 578, 420) = 3
write_syscall(3, "hello", 5) = 5
close_syscall(3) = 0
```

## Intercepted syscalls

| Category | Syscalls |
|----------|----------|
| File I/O and descriptors | read, write, open, close, poll, lseek, ioctl, pread, pwrite, readv, writev, pipe, select, dup, dup2, dup3, fcntl, flock, fsync, fdatasync, getdents, pipe2, sync_file_range |
| Filesystem and paths | stat, fstat, access, truncate, ftruncate, getcwd, chdir, fchdir, rename, unlink, unlinkat, readlink, readlinkat, chmod, fchmod, statfs, fstatfs |
| Memory, timing, and synchronization | mmap, mprotect, munmap, brk, sched_yield, nanosleep, setitimer, futex, clock_gettime, getrandom |
| System V IPC | shmget, shmat, shmctl, shmdt |
| Networking and event polling | socket, connect, accept, sendto, recvfrom, shutdown, bind, listen, getsockname, getpeername, socketpair, setsockopt, getsockopt, epoll_create, epoll_create1, epoll_wait, epoll_ctl |
| Processes, signals, and identity | clone, fork, exec, exit, waitpid, kill, sigaction, sigprocmask, getpid, getppid, getuid, geteuid, getgid, getegid, gethostname |

## Building

```bash
cd rust-grates/strace-grate
cargo lind_compile --output-dir grates
```

## Code layout

- `src/main.rs`: defines and registers the syscall handlers, starts the child
  program, and reports the final grate result.
- `src/strace.rs`: formats arguments, copies strings from cage memory, forwards
  syscalls, and defines the handler-generating macro.
- `test/strace_test.c`: exercises representative syscall categories and checks
  that the forwarded operations still succeed.
