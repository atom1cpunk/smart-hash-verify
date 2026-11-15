#!/usr/bin/env bash
set -Eeuo pipefail

TOOL_NAME="smart-hash-verify"
VERSION="2.1.2"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    PRIMARY=$'\033[38;5;208m'
    NC=$'\033[0m'
else
    RED='' GREEN='' YELLOW='' PRIMARY='' NC=''
fi

print_error() { printf '\n%b[Error] %s%b\n' "$RED" "$1" "$NC" >&2; }
exit_error()  { print_error "$1"; exit 1; }

PROGRAM_NAME=$(basename -- "$0")

show_help() {
    cat <<EOF
${TOOL_NAME} v${VERSION} — Smart SHA-256 Verification Tool

Verify a file against an expected SHA-256 checksum.

USAGE
    $PROGRAM_NAME [TARGET_FILE [CHECKSUM_FILE | HASH]]
    $PROGRAM_NAME [TARGET_FILE SHA-256: HASH]
    $PROGRAM_NAME -h | --help
    $PROGRAM_NAME -v | --version

ARGUMENTS
    TARGET_FILE      File to verify (optional).
                     If omitted, the script will prompt you to select one.

    CHECKSUM_FILE    Checksum file containing expected SHA-256 hashes (optional).

    HASH             Expected SHA-256 hash (optional).
                     Accepts plain 64-char hex, or with a prefix:
                       sha:HASH
                       SHA-256:HASH
                       "SHA-256: HASH"   (space after colon is fine)

EXAMPLES
    $PROGRAM_NAME
        Fully interactive mode.

    $PROGRAM_NAME ubuntu.iso
        Target file pre-selected; still prompts for the hash source.

    $PROGRAM_NAME ubuntu.iso SHA256SUMS
        Both files pre-selected; auto-matches when possible.
        If no unique match is found, you will be prompted to select an entry.

    $PROGRAM_NAME ubuntu.iso sha:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
        Target + hash on the command line; verifies immediately.

    $PROGRAM_NAME ubuntu.iso "SHA-256: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        Same, with space after the colon (common when copying from websites).

    $PROGRAM_NAME ubuntu.iso SHA-256: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
        Unquoted form also works (prefix and hash as separate arguments).

    $PROGRAM_NAME -h
        Show this help.

    $PROGRAM_NAME --version
        Show version information.

NOTES
    - Supports drag-and-drop of files into the terminal.
    - Paths entered in the UI may use ~ (e.g. ~/Downloads/file.iso).
    - Auto-matches by filename when a checksum file is used.
    - Works with standard formats: "HASH  filename" and "HASH *filename".
    - Prefixed hashes must contain only the prefix and the 64-character digest.
    - Calculation time is always shown (< 1s for short runs).
    - Press Ctrl+C at any prompt to cancel.
EOF
}

show_version() {
    printf '%s %s\n' "$TOOL_NAME" "$VERSION"
}

# Expand a leading ~ to $HOME (for paths from interactive input).
expand_tilde() {
    local p=$1
    if [[ $p == ~/* || $p == '~' ]]; then
        p="${HOME}${p:1}"
    fi
    printf '%s' "$p"
}

# Extract a SHA-256 hash from a string.
# Prefixed forms (sha: / SHA-256:) must be exact: prefix + optional spaces + 64 hex.
# Plain hash may be followed by a filename (copied checksum line).
# Sets HASH_TO_CHECK on success; returns 0/1.
parse_hash_string() {
    local input=$1
    local cleaned

    # Trim leading/trailing whitespace
    cleaned="${input#"${input%%[![:space:]]*}"}"
    cleaned="${cleaned%"${cleaned##*[![:space:]]}"}"

    # Prefixed forms: strict — no trailing junk after the digest
    if [[ $cleaned =~ ^[Ss][Hh][Aa]-?256:[[:space:]]*([0-9A-Fa-f]{64})[[:space:]]*$ ]]; then
        HASH_TO_CHECK=${BASH_REMATCH[1],,}
        return 0
    fi

    if [[ $cleaned =~ ^[Ss][Hh][Aa]:[[:space:]]*([0-9A-Fa-f]{64})[[:space:]]*$ ]]; then
        HASH_TO_CHECK=${BASH_REMATCH[1],,}
        return 0
    fi

    # Plain hash: allow optional trailing filename (HASH filename)
    if [[ $cleaned =~ ^([0-9A-Fa-f]{64})([[:space:]]|$) ]]; then
        HASH_TO_CHECK=${BASH_REMATCH[1],,}
        return 0
    fi

    return 1
}

# Format elapsed seconds for display.
# < 1.0  →  "< 1s"
# ≥ 1.0  →  "12.4s"
format_elapsed() {
    awk -v t="$1" 'BEGIN {
        if (t + 0 < 1.0)
            print "< 1s"
        else
            printf "%.1fs", t
    }'
}

case ${1:-} in
    -h|--help)
        show_help
        exit 0
        ;;
    -v|--version)
        show_version
        exit 0
        ;;
    --)
        shift
        ;;
esac

if (( $# > 3 )); then
    print_error "Too many arguments."
    printf '\n' >&2
    show_help >&2
    exit 2
fi

strip_quotes() {
    local v=$1
    if [[ ${#v} -ge 2 ]]; then
        if [[ $v == \"*\" && $v == *\" ]]; then
            v=${v:1:${#v}-2}
        elif [[ $v == \'*\' && $v == *\' ]]; then
            v=${v:1:${#v}-2}
        fi
    fi
    printf '%s' "$v"
}

prompt_path() {
    local input
    read -e -r -p "$1" input
    input=$(strip_quotes "$input")
    expand_tilde "$input"
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || exit_error "Required command '$1' not found."
}

trap 'printf "\n%bOperation canceled.%b\n" "$YELLOW" "$NC"; exit 130' INT

require_cmd find
require_cmd sort
require_cmd sha256sum
require_cmd basename

if (( $# == 0 )) && [[ -t 1 ]]; then
    clear 2>/dev/null || true
fi

printf '%b\n' "${PRIMARY}==================================================${NC}"
printf '%b\n' "${PRIMARY}        ${TOOL_NAME} v${VERSION}                 ${NC}"
printf '%b\n' "${PRIMARY}==================================================${NC}"
printf '%b\n' "${YELLOW}              Ctrl+C to cancel${NC}"
printf '\n'

TARGET_FILE=${1:-}
SECOND_ARG=${2:-}
THIRD_ARG=${3:-}
HASH_FILE=''
HASH_TO_CHECK=''

# Expand ~ on CLI args too (rarely needed; shell usually expands first)
[[ -n $TARGET_FILE ]] && TARGET_FILE=$(expand_tilde "$TARGET_FILE")
[[ -n $SECOND_ARG  ]] && SECOND_ARG=$(expand_tilde "$SECOND_ARG")

if [[ -n $TARGET_FILE ]]; then
    [[ -f $TARGET_FILE ]] || exit_error "Target file '$TARGET_FILE' was not found."
    [[ -r $TARGET_FILE ]] || exit_error "Target file '$TARGET_FILE' is not readable."
fi

# Resolve the second and optional third arguments.
if [[ -n $THIRD_ARG ]]; then
    # Three arguments are valid only for: TARGET_FILE SHA-256: HASH
    if [[ ${SECOND_ARG,,} =~ ^(sha-?256:|sha:)$ ]]; then
        if parse_hash_string "${SECOND_ARG} ${THIRD_ARG}"; then
            printf '%bUsing hash from command line.%b\n' "$PRIMARY" "$NC"
        else
            exit_error "Invalid SHA-256 hash after prefix: '$THIRD_ARG'"
        fi
    else
        exit_error "A third argument is valid only after 'SHA-256:', 'sha256:', or 'sha:'."
    fi
elif [[ -n $SECOND_ARG ]]; then
    if parse_hash_string "$SECOND_ARG"; then
        printf '%bUsing hash from command line.%b\n' "$PRIMARY" "$NC"
    elif [[ -f $SECOND_ARG ]]; then
        [[ -r $SECOND_ARG ]] ||
            exit_error "Checksum file '$SECOND_ARG' is not readable."
        HASH_FILE=$SECOND_ARG
        printf '%bChecksum file:%b %s\n' "$PRIMARY" "$NC" "$HASH_FILE"
    else
        exit_error \
            "Second argument is neither a valid SHA-256 hash nor a checksum file: '$SECOND_ARG'"
    fi
fi

printf '\n'

# --- STEP 1: Target file ----------------------------------------------------
if [[ -z $TARGET_FILE ]]; then
    printf '%b\n\n' "${PRIMARY}[1/2] Select the file to verify:${NC}"

    mapfile -d '' -t LOCAL_TARGETS < <(
        find . -maxdepth 1 -type f \
            \( -iname '*.iso' -o -iname '*.img' -o -iname '*.zip' \
               -o -iname '*.tar' -o -iname '*.tar.*' -o -iname '*.gz' \
               -o -iname '*.bz2' -o -iname '*.xz' -o -iname '*.qcow2' \
               -o -iname '*.7z' -o -iname '*.rpm' \) \
            -printf '%P\0' | sort -z
    )

    if (( ${#LOCAL_TARGETS[@]} > 0 )); then
        printf 'Found files in current directory:\n\n'
        for i in "${!LOCAL_TARGETS[@]}"; do
            printf '  %d) %q\n' "$((i+1))" "${LOCAL_TARGETS[$i]}"
        done
        printf '  0) Enter path manually / drag & drop\n\n'
        printf '%b' "${PRIMARY}Select option [0-${#LOCAL_TARGETS[@]}]: ${NC}"
        read -r T_CHOICE

        if [[ $T_CHOICE =~ ^[1-9][0-9]*$ ]] && (( T_CHOICE <= ${#LOCAL_TARGETS[@]} )); then
            TARGET_FILE=${LOCAL_TARGETS[$((T_CHOICE-1))]}
        elif [[ $T_CHOICE != 0 ]]; then
            printf '%b\n' "${YELLOW}[!] Invalid selection. Switching to manual entry.${NC}"
        fi
    fi

    if [[ -z $TARGET_FILE ]]; then
        printf '\n%b\n' "${YELLOW}Tip: Drag and drop a file, or use ~/path${NC}"
        TARGET_FILE=$(prompt_path "${PRIMARY}Enter path to target file: ${NC}")
    fi
fi

[[ -n $TARGET_FILE ]] || exit_error 'No target file specified.'
[[ -f $TARGET_FILE ]] || exit_error "File '$TARGET_FILE' not found."
[[ -r $TARGET_FILE ]] || exit_error "File '$TARGET_FILE' is not readable."

TARGET_BASENAME=$(basename -- "$TARGET_FILE")
printf '%bSelected:%b %s\n\n' "$GREEN" "$NC" "$TARGET_FILE"

# --- STEP 2: Hash source (skip if already have HASH_TO_CHECK from CLI) ------
if [[ -z $HASH_TO_CHECK && -z $HASH_FILE ]]; then
    printf '%b\n' "${PRIMARY}[2/2] How would you like to provide the expected hash?${NC}"
    printf '  1) Select a checksum file\n'
    printf '  2) Paste a SHA-256 hash manually\n\n'
    printf '%b' "${PRIMARY}Select input method [1-2]: ${NC}"
    read -r HASH_METHOD

    case $HASH_METHOD in
        1)
            mapfile -d '' -t LOCAL_SUMS < <(
                find . -maxdepth 1 -type f \
                    \( -iname '*.sha256' -o -iname '*.sha256sum' \
                       -o -iname '*sha256sums*' -o -iname 'SHA256SUMS' \
                       -o -iname 'CHECKSUMS' -o -iname '*checksum*' \
                       -o -iname '*checksums*' -o -iname '*sum*' \
                       -o -iname '*.txt' \) \
                    -printf '%P\0' | sort -z
            )

            if (( ${#LOCAL_SUMS[@]} > 0 )); then
                printf '\nFound checksum files:\n\n'
                for i in "${!LOCAL_SUMS[@]}"; do
                    printf '  %d) %q\n' "$((i+1))" "${LOCAL_SUMS[$i]}"
                done
                printf '  0) Enter path manually / drag & drop\n\n'
                printf '%b' "${PRIMARY}Select option [0-${#LOCAL_SUMS[@]}]: ${NC}"
                read -r S_CHOICE

                if [[ $S_CHOICE =~ ^[1-9][0-9]*$ ]] && (( S_CHOICE <= ${#LOCAL_SUMS[@]} )); then
                    HASH_FILE=${LOCAL_SUMS[$((S_CHOICE-1))]}
                elif [[ $S_CHOICE != 0 ]]; then
                    printf '%b\n' "${YELLOW}[!] Invalid selection. Switching to manual entry.${NC}"
                fi
            fi

            if [[ -z $HASH_FILE ]]; then
                printf '\n%b\n' "${YELLOW}Tip: Drag and drop, or use ~/path${NC}"
                HASH_FILE=$(prompt_path "${PRIMARY}Enter path to checksum file: ${NC}")
            fi
            ;;
        2)
            printf '\n%b\n' "${YELLOW}Accepts plain hash or with prefix (SHA-256: / sha:)${NC}"
            printf '%b' "${PRIMARY}Paste the expected SHA-256 hash: ${NC}"
            read -r EXPECTED_HASH

            if ! parse_hash_string "$EXPECTED_HASH"; then
                exit_error "'$EXPECTED_HASH' is not a valid SHA-256 hash (need 64 hex chars, optional SHA-256: prefix)."
            fi
            ;;
        *)
            exit_error 'Invalid input method selected.'
            ;;
    esac
fi

# Process checksum file (whether from argument or menu)
if [[ -n $HASH_FILE && -z $HASH_TO_CHECK ]]; then
    [[ -f $HASH_FILE ]] || exit_error "Checksum file '$HASH_FILE' not found."
    [[ -r $HASH_FILE ]] || exit_error "Checksum file '$HASH_FILE' is not readable."

    declare -a HASHES=() FILES=()

    while IFS= read -r line || [[ -n $line ]]; do
        # Strip trailing CR (Windows line endings)
        line=${line%$'\r'}

        [[ $line =~ ^[[:space:]]*$ || $line =~ ^[[:space:]]*# ]] && continue
        if [[ $line =~ ^[[:space:]]*([0-9A-Fa-f]{64})[[:space:]]+(\*?)(.*)$ ]]; then
            [[ -n ${BASH_REMATCH[3]} ]] || continue
            HASHES+=("${BASH_REMATCH[1]}")
            FILES+=("${BASH_REMATCH[3]}")
        fi
    done < "$HASH_FILE"

    (( ${#HASHES[@]} > 0 )) || exit_error "No valid SHA-256 entries in '$HASH_FILE'."

    SELECTED_INDEX=-1
    for i in "${!FILES[@]}"; do
        if [[ ${FILES[$i]} == "$TARGET_BASENAME" || ${FILES[$i]} == "./$TARGET_BASENAME" ]]; then
            SELECTED_INDEX=$i
            break
        fi
    done

    if (( SELECTED_INDEX == -1 )); then
        BASENAME_MATCH=-1
        BASENAME_MATCH_COUNT=0
        for i in "${!FILES[@]}"; do
            if [[ $(basename -- "${FILES[$i]}") == "$TARGET_BASENAME" ]]; then
                BASENAME_MATCH=$i
                ((BASENAME_MATCH_COUNT += 1))
            fi
        done
        (( BASENAME_MATCH_COUNT == 1 )) && SELECTED_INDEX=$BASENAME_MATCH
    fi

    if (( SELECTED_INDEX != -1 )); then
        HASH_TO_CHECK=${HASHES[$SELECTED_INDEX],,}
        printf "%b[*] Matched '%s' in checksum file.%b\n" \
            "$GREEN" "${FILES[$SELECTED_INDEX]}" "$NC"
    else
        printf '\n%b[!] No unique filename match.%b\n' "$YELLOW" "$NC"
        printf 'Select entry for %q:\n\n' "$TARGET_BASENAME"
        for i in "${!HASHES[@]}"; do
            printf '  %d) %q (%s...)\n' "$((i+1))" "${FILES[$i]}" "${HASHES[$i]:0:16}"
        done
        printf '\n%b' "${PRIMARY}Select option [1-${#HASHES[@]}]: ${NC}"
        read -r CHOICE

        if [[ $CHOICE =~ ^[1-9][0-9]*$ ]] && (( CHOICE <= ${#HASHES[@]} )); then
            HASH_TO_CHECK=${HASHES[$((CHOICE-1))],,}
        else
            exit_error 'Invalid checksum selection.'
        fi
    fi
fi

[[ -n $HASH_TO_CHECK ]] || exit_error 'No hash to check.'

[[ $HASH_TO_CHECK =~ ^[0-9a-f]{64}$ ]] ||
    exit_error "'$HASH_TO_CHECK' is not a valid 64-character SHA-256 hash."

printf '\n%b[*] Calculating SHA-256... please wait%b\n\n' "$YELLOW" "$NC"

START_TIME=$(date +%s.%N)

if ! ACTUAL_OUTPUT=$(sha256sum < "$TARGET_FILE"); then
    exit_error "Failed to calculate SHA-256 of '$TARGET_FILE'."
fi

END_TIME=$(date +%s.%N)
ELAPSED=$(awk -v s="$START_TIME" -v e="$END_TIME" 'BEGIN { printf "%.3f", e - s }')
TIME_DISPLAY=$(format_elapsed "$ELAPSED")

ACTUAL_HASH=${ACTUAL_OUTPUT%% *}
ACTUAL_HASH=${ACTUAL_HASH,,}
[[ $ACTUAL_HASH =~ ^[0-9a-f]{64}$ ]] ||
    exit_error "sha256sum returned unexpected output."

if [[ $ACTUAL_HASH == "$HASH_TO_CHECK" ]]; then
    printf '%b\n' "${GREEN}==================================================${NC}"
    printf '%b\n' "${GREEN} SUCCESS: SHA-256 hashes match! File is intact.   ${NC}"
    printf '%b\n' "${GREEN}==================================================${NC}"
    printf 'File:     %s\n' "$TARGET_FILE"
    printf 'SHA-256:  %s\n' "$ACTUAL_HASH"
    printf 'Time:     %s\n' "$TIME_DISPLAY"
    exit 0
else
    printf '%b\n' "${RED}==================================================${NC}"
    printf '%b\n' "${RED} FAILURE: SHA-256 hashes DO NOT match!            ${NC}"
    printf '%b\n' "${RED}==================================================${NC}"
    printf 'File:     %s\n' "$TARGET_FILE"
    printf 'Expected: %s\n' "$HASH_TO_CHECK"
    printf 'Actual:   %s\n' "$ACTUAL_HASH"
    printf 'Time:     %s\n' "$TIME_DISPLAY"
    exit 1
fi
