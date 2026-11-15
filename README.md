# smart-hash-verify

Interactive SHA-256 verification tool for Linux.

Verify downloaded ISOs, images, archives, and RPMs against a checksum file or a pasted hash — from the terminal or with a short command line.

**Version:** 2.1.2

---

## Features

- Interactive menus or fully non-interactive CLI use
- Auto-detect common download files and checksum files in the current directory
- Accept a raw SHA-256 hash or a checksum file as the second argument
- Support common hash prefixes: `SHA-256:`, `sha256:`, `sha:` (with or without a space after the colon)
- Drag-and-drop path entry and `~/path` expansion
- Auto-match by filename inside multi-entry checksum files
- Clear success/failure output with file path, full hash, and timing
- `Ctrl+C` to cancel at any prompt
- Terminal colors with `NO_COLOR` support

---

## Requirements

- Bash 4+
- GNU coreutils (`find`, `sort`, `sha256sum`, `basename`, `date`)
- Linux (tested with Fedora; other modern distros should work)

---

## Installation

Clone or download the script, then:

    chmod +x smart-hash-verify

Optional: install somewhere on your PATH

    mkdir -p ~/bin
    cp smart-hash-verify ~/bin/

Ensure ~/bin is in your PATH.

---

## Usage

    smart-hash-verify [TARGET_FILE [CHECKSUM_FILE | HASH]]
    smart-hash-verify [TARGET_FILE SHA-256: HASH]
    smart-hash-verify -h | --help
    smart-hash-verify -v | --version

### Examples

Fully interactive:

    smart-hash-verify

Target only (still prompts for hash source):

    smart-hash-verify ubuntu.iso

Target + checksum file:

    smart-hash-verify ubuntu.iso SHA256SUMS

Target + hash on the command line:

    smart-hash-verify ubuntu.iso sha:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef

Prefix with space (quoted):

    smart-hash-verify ubuntu.iso "SHA-256: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

Prefix and hash as separate arguments:

    smart-hash-verify ubuntu.iso SHA-256: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef

### Interactive tips

- Choose a local candidate from the menu, or enter a path manually
- Paths may use ~ (e.g. ~/Downloads/ubuntu.iso)
- Drag-and-drop a file into the terminal is supported on most desktop terminals
- Option 2 accepts a plain 64-character hash or a SHA-256: / sha: prefixed value

---

## Output

Success:

    ==================================================
     SUCCESS: SHA-256 hashes match! File is intact.
    ==================================================
    File:     ubuntu.iso
    SHA-256:  0123456789abcdef...
    Time:     12.4s

Failure:

    ==================================================
     FAILURE: SHA-256 hashes DO NOT match!
    ==================================================
    File:     ubuntu.iso
    Expected: 0123456789abcdef...
    Actual:   fedcba9876543210...
    Time:     < 1s

Timing is always shown: < 1s for short runs, or seconds to one decimal place when longer.

---

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Hashes match |
| 1 | Hashes do not match, or a runtime error |
| 2 | Invalid usage / too many arguments |
| 130 | Interrupted with Ctrl+C |

---

## Supported checksum formats

- HASH  filename
- HASH *filename (binary indicator)

Prefixed manual input:

- SHA-256: followed by 64 hex digits
- sha256: followed by 64 hex digits
- sha: followed by 64 hex digits
- Plain 64-character hex string

GNU-escaped or newline-containing filenames in checksum manifests are not supported (normal ISO/archive names are fine).

---

## Environment

| Variable | Effect |
|----------|--------|
| NO_COLOR | Disable colored output when set to any value |

---

## License

This project is licensed under the **GNU General Public License v3.0**.

See the [LICENSE](LICENSE) file for the full text.
