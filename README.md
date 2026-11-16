# smart-hash-verify

Interactive SHA-256 verification tool for Linux (**SHA-256 only** — no MD5, SHA-1, or SHA-512).

Verify downloaded ISOs, images, archives, and RPMs against a checksum file or a pasted hash — from the terminal or with a short command line.

**Version:** 2.2.1

**Repository:** [https://github.com/atom1cpunk/smart-hash-verify](https://github.com/atom1cpunk/smart-hash-verify)

---

## Features

- Interactive menus or fully non-interactive CLI use
- Auto-detect common download files and checksum files in the current directory
- Accept a raw SHA-256 hash or a checksum file as the second argument
- Support common hash prefixes: `SHA-256:`, `sha256:`, `sha:` (with or without a space after the colon)
- Read both GNU-style and BSD-style checksum files (for example Fedora `CHECKSUM` files)
- Drag-and-drop path entry and `~/path` expansion
- Auto-match by filename inside multi-entry checksum files
- Clear success/failure output with file path, full hash, and timing
- `Ctrl+C` to cancel at any prompt
- Terminal colors with `NO_COLOR` support

---

## Requirements

- Linux
- Bash 4.0 or newer (uses `mapfile` and `${var,,}`)
- GNU coreutils (`sha256sum`, `sort`, `basename`, `date` with `%N` support)
- GNU findutils (`find` with `-printf`)
- `awk`

macOS ships Bash 3.2 and BSD versions of these tools, so the script is not expected to work there without changes.

---

## Installation

### Clone the repository

```
git clone https://github.com/atom1cpunk/smart-hash-verify.git
cd smart-hash-verify
chmod +x smart-hash-verify
```

### Optional: install on your PATH

For your user only:

```
install -Dm755 smart-hash-verify ~/.local/bin/smart-hash-verify
```

`~/.local/bin` is on the `PATH` by default on many distributions. If yours does not include it, add this to your shell profile (for example `~/.bashrc`):

```
export PATH="$HOME/.local/bin:$PATH"
```

For all users:

```
sudo install -Dm755 smart-hash-verify /usr/local/bin/smart-hash-verify
```

Then run:

```
smart-hash-verify --help
```

---

## Usage

```
smart-hash-verify [TARGET_FILE [CHECKSUM_FILE | HASH]]
smart-hash-verify [TARGET_FILE SHA-256: HASH]
smart-hash-verify -h | --help
smart-hash-verify -v | --version
```

Unknown options (anything else starting with `-`) are rejected with an error and exit code `2`. To verify a file whose name begins with `-`, put `--` first or use `./`.

### Examples

```
# Fully interactive
smart-hash-verify

# Target only — still prompts for hash source
smart-hash-verify ubuntu.iso

# Target + checksum file
smart-hash-verify ubuntu.iso SHA256SUMS

# Target + hash on the command line
smart-hash-verify ubuntu.iso sha:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef

# Prefix with space (quoted)
smart-hash-verify ubuntu.iso "SHA-256: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

# Prefix and hash as separate arguments
smart-hash-verify ubuntu.iso SHA-256: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
```

### Interactive tips

- Choose a local candidate from the menu, or enter a path manually
- Paths may use `~` (e.g. `~/Downloads/ubuntu.iso`) or be absolute
- Drag-and-drop a file into the terminal is supported on most desktop terminals
- Option 2 accepts a plain 64-character hash or a `SHA-256:` / `sha:` prefixed value

---

## Output

**Success**

```
==================================================
 SUCCESS: SHA-256 hashes match! File is intact.
==================================================
File:     ubuntu.iso
SHA-256:  0123456789abcdef...
Time:     12.4s
```

**Failure**

```
==================================================
 FAILURE: SHA-256 hashes DO NOT match!
==================================================
File:     ubuntu.iso
Expected: 0123456789abcdef...
Actual:   fedcba9876543210...
Time:     < 1s
```

Timing is always shown: `< 1s` for short runs, or seconds to one decimal place when longer.

---

## Verifying authenticity

A matching hash proves the file was not corrupted or altered **relative to the hash you supplied**. It only proves the file is genuine if that hash came from a source you trust. Get hashes from the project's official HTTPS site, and where the project publishes a signed checksum file (Fedora, Ubuntu, Debian, and others do), verify its GPG signature as well. This tool does not check signatures.

---

## Exit codes

| Code  | Meaning                                                  |
| ----- | -------------------------------------------------------- |
| `0`   | Hashes match                                             |
| `1`   | Hashes do not match, or a runtime error                  |
| `2`   | Invalid usage: unknown option or too many arguments      |
| `130` | Interrupted with Ctrl+C                                  |

---

## Supported checksum formats

Checksum files:

- GNU: `HASH  filename`
- GNU binary indicator: `HASH *filename`
- BSD: `SHA256 (filename) = HASH` (used by Fedora `CHECKSUM` files and others)

Blank lines and `#` comment lines are ignored, as are other lines that do not match, such as PGP signature armor in signed checksum files.

Prefixed manual input:

- `SHA-256: <64 hex digits>`
- `sha256: <64 hex digits>`
- `sha: <64 hex digits>`
- Plain 64-character hex string

GNU-escaped or newline-containing filenames in checksum manifests are not supported (normal ISO/archive names are fine). Only SHA-256 entries are read; entries for other algorithms (for example `SHA512 (file) = ...`) are ignored.

---

## Environment

| Variable   | Effect                                       |
| ---------- | -------------------------------------------- |
| `NO_COLOR` | Disable colored output when set to any value |

---

## License

This project is licensed under the **GNU General Public License v3.0**.

See the [LICENSE](LICENSE) file for the full text.
