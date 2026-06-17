# fchmod-grate

A grate that clamps file permission bits by ANDing the `mode` argument of
every `fchmod(2)` and `fchmodat(2)` call with a configurable mask before the
syscall reaches the kernel.

This lets an operator enforce a maximum permission ceiling on any file a cage
touches via either permission-change syscall — without modifying the cage
program and without requiring any privileges.

## How it works

1. **Mode masking**: When a cage calls `fchmod(fd, mode)` or
   `fchmodat(dirfd, path, mode, flags)`, the grate intercepts the syscall,
   computes `masked_mode = mode & MASK`, and forwards the syscall with
   `masked_mode` in place of `mode`. All other arguments are passed through
   unchanged.

2. **Shared mask**: Both syscalls consult the same mask, so a single
   `--mask` value applies a consistent permission ceiling regardless of
   whether the cage uses an fd-based or path-based call.

3. **Transparent return**: The cage receives the return value of the real
   kernel syscall, including any errors (`ENOTSUP` for `AT_SYMLINK_NOFOLLOW`
   on Linux, `EBADF` for bad fds, etc.).

Bits not present in the mask are silently stripped. For example, with
`--mask 644`:

- `fchmod(fd, 0777)` → kernel sees `0644`
- `fchmod(fd, 0755)` → kernel sees `0644`
- `fchmod(fd, 0600)` → kernel sees `0600` (within mask, preserved)
- `fchmod(fd, 04755)` → kernel sees `0644` (setuid bit stripped)
- `fchmodat(AT_FDCWD, "file", 0777, 0)` → kernel sees `0644`
- `fchmodat(dirfd, "file", 04755, 0)` → kernel sees `0644`

The default mask (`07777`) passes all bits through unchanged, so the grate
is a no-op without `--mask`.

## Usage

```bash
lind-wasm grates/fchmod-grate.cwasm [--mask <octal>] <program> [args...]
```

### Example

Prevent any cage file from receiving execute or setuid bits:

```bash
lind-wasm grates/fchmod-grate.cwasm --mask 644 myapp.cwasm
```

## Options

| Flag | Description |
|------|-------------|
| `--mask <octal>` | Octal permission mask ANDed with every `fchmod`/`fchmodat` mode. Default: `7777` (no restriction). |

## Intercepted syscalls

| Syscall | Effect |
|---------|--------|
| `fchmod(fd, mode)` | `mode` is replaced with `mode & MASK` before dispatch. |
| `fchmodat(dirfd, path, mode, flags)` | `mode` is replaced with `mode & MASK` before dispatch; all other arguments pass through unchanged. |

## Building

```bash
cd rust-grates/fchmod-grate
cargo lind_compile --output-dir grates
```

## Code layout

- `src/main.rs`: argument parsing, mask initialisation, handler registration
  via `GrateBuilder`, and the `fchmod` and `fchmodat` handlers.
