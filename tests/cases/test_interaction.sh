#!/usr/bin/env bash

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
library="$(cd -- "$script_dir/../.." && pwd)/dotfiles-lib.sh"

setUp() {
    case_dir="$(mktemp -d "$SHUNIT_TMPDIR/interaction.XXXXXX")"
}

exercise_confirmation() {
    local answer=$1 quiet=$2 redirected=$3 directory=$case_dir/$1-$2-$3
    mkdir -p "$directory/home"
    printf 'new\n' > "$directory/source"
    printf 'old\n' > "$directory/home/config"
    cat > "$directory/copy.sh" <<'EOF'
set -euo pipefail
source "$DFL_PTY_LIB"
dfl_safe_install "$DFL_PTY_SOURCE" "$HOME/config"
printf 'completed\n' >&2
EOF
    if [[ -n ${DFL_TEST_CONSUMER:-} ]]; then
        mkdir -p "$directory/repo/dotfiles/pty-test"
        cp "$DFL_TEST_CONSUMER" "$directory/repo/install.sh"
        cp -a "$(dirname -- "$DFL_TEST_CONSUMER")/vendor" "$directory/repo/"
        cp "$directory/copy.sh" "$directory/repo/dotfiles/pty-test/install.sh"
    fi
    cat > "$directory/probe.sh" <<'EOF'
set -euo pipefail
if [[ $DFL_PTY_REDIRECT == true ]]; then exec > "$DFL_PTY_DIR/stdout"; fi
if [[ -n ${DFL_TEST_CONSUMER:-} ]]; then
    args=()
    if [[ $_dfl_quiet == true ]]; then args+=(--quiet); fi
    exec bash "$DFL_PTY_DIR/repo/install.sh" "${args[@]}" pty-test
else
    exec bash "$DFL_PTY_DIR/copy.sh"
fi
EOF
    local command pid code=0 ready=false attempt
    printf -v command 'bash %q' "$directory/probe.sh"
    mkfifo "$directory/input"
    # Hold the FIFO open until the prompt appears, then send terminal input.
    local input_fd
    exec {input_fd}<> "$directory/input"
    HOME="$directory/home" TERM=dumb _dfl_force=false _dfl_quiet="$quiet" \
        DFL_PTY_LIB="$library" DFL_PTY_SOURCE="$directory/source" \
        DFL_PTY_DIR="$directory" DFL_PTY_REDIRECT="$redirected" \
        env --default-signal=INT --default-signal=QUIT \
        timeout --kill-after=2 10 script -qefc "$command" /dev/null \
        < "$directory/input" > "$directory/terminal" 2>&1 &
    pid=$!
    for ((attempt=0; attempt<500; attempt++)); do
        if grep -q '\[y/N\] ' "$directory/terminal"; then ready=true; break; fi
        if ! kill -0 "$pid" 2>/dev/null; then break; fi
        sleep 0.01
    done
    if [[ $ready == true ]]; then
        case $answer in
            yes) printf 'y\n' >&"$input_fd" ;;
            no) printf 'n\n' >&"$input_fd" ;;
            eof) printf '\004' >&"$input_fd" ;;
            interrupt) printf '\003' >&"$input_fd" ;;
        esac
    else
        kill "$pid" 2>/dev/null || true
    fi
    wait "$pid" || code=$?
    exec {input_fd}>&-
    tr -d '\r' < "$directory/terminal" > "$directory/plain"
    assertEquals 'The prompt must appear before input is sent' true "$ready"
    assertNotEquals 'The interaction must not time out' 124 "$code"
    assertNotEquals 'The interaction must not need SIGKILL' 137 "$code"
    assertTrue "grep -q '^--- ' '$directory/plain'"
    assertTrue "grep -q 'overwrite .*by new file' '$directory/plain'"
    if [[ $answer == yes ]]; then
        assertEquals new "$(cat "$directory/home/config")"
    else
        assertEquals old "$(cat "$directory/home/config")"
    fi
    if [[ $answer == interrupt ]]; then
        assertNotEquals 0 "$code"
        assertFalse "grep -q 'completed' '$directory/plain'"
    else
        assertEquals 0 "$code"
        assertTrue "grep -q '^completed$' '$directory/plain'"
    fi
    if [[ $answer == eof ]]; then
        assertTrue "grep -q '\[y/N\] $' '$directory/plain'"
    fi
    if [[ $redirected == true ]]; then
        assertFalse "grep -q 'overwrite\|^--- ' '$directory/stdout'"
        if [[ $quiet == true ]]; then assertEquals '' "$(cat "$directory/stdout")"; fi
    fi
    if [[ $quiet == true ]]; then
        assertFalse "grep -q 'information:\|warning:' '$directory/plain'"
    fi
}

run_combinations() {
    local quiet redirected
    for quiet in false true; do
        for redirected in false true; do
            exercise_confirmation "$1" "$quiet" "$redirected"
        done
    done
}

test_confirmation_yes() { run_combinations yes; }
test_confirmation_no() { run_combinations no; }
test_confirmation_ctrl_d() { run_combinations eof; }
test_confirmation_ctrl_c() { run_combinations interrupt; }

# shellcheck source=/dev/null
source "${SHUNIT2:-/usr/share/shunit2/shunit2}"
