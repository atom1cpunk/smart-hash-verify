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

```bash
# Clone or download the script, then:
chmod +x smart-hash-verify
# Optional: install somewhere on your PATH
mkdir -p ~/bin
cp smart-hash-verify ~/bin/
# Ensure ~/bin is in PATH
