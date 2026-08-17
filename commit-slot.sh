#!/bin/sh

# ============================================================
# commit-slot
# ============================================================

TIMEZONE="Asia/Kolkata"

# Generated commit timestamps cannot fall inside this window.
START="12:00"
END="18:00"

# Random gap between consecutive commit slots, in minutes.
MIN_INTERVAL=5
MAX_INTERVAL=7

# Used only by fallback RNG paths.
RNG_COUNTER=0


# ============================================================
# Must be sourced
# ============================================================

if ! (return 0 2>/dev/null); then
    echo "commit-slot: source this script instead of executing it"
    echo "commit-slot: example: source /path/to/commit-slot"
    exit 1
fi


# ============================================================
# Find Git repository
# ============================================================

GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "commit-slot: not inside a git repository"
    return 1
}

SLOT_FILE="$GIT_ROOT/commit-slot.cfg"
GITIGNORE="$GIT_ROOT/.gitignore"
LOCK_DIR="$GIT_ROOT/.commit-slot.lock"


# ============================================================
# Helpers
# ============================================================

usage() {
    cat <<EOF
commit-slot

Usage:
  commit-slot init       Enable commit-slot for this repository
  commit-slot             Generate and export the next timestamp
  commit-slot status      Show current slot information
  commit-slot reset       Reset the persisted timestamp
  commit-slot help        Show this help
EOF
}


is_valid_hhmm() {
    case "$1" in
        [0-1][0-9]:[0-5][0-9]|2[0-3]:[0-5][0-9])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}


hhmm_to_seconds() {
    hour="${1%%:*}"
    minute="${1##*:}"

    echo $((10#$hour * 3600 + 10#$minute * 60))
}


validate_config() {
    if ! is_valid_hhmm "$START"; then
        echo "commit-slot: invalid START time: $START"
        return 1
    fi

    if ! is_valid_hhmm "$END"; then
        echo "commit-slot: invalid END time: $END"
        return 1
    fi

    if (( $(hhmm_to_seconds "$START") >= $(hhmm_to_seconds "$END") )); then
        echo "commit-slot: START must be earlier than END"
        return 1
    fi

    case "$MIN_INTERVAL" in
        ''|*[!0-9]*)
            echo "commit-slot: invalid interval configuration"
            return 1
            ;;
    esac

    case "$MAX_INTERVAL" in
        ''|*[!0-9]*)
            echo "commit-slot: invalid interval configuration"
            return 1
            ;;
    esac

    if
       (( MIN_INTERVAL > MAX_INTERVAL )) ||
       (( MIN_INTERVAL < 1 )); then
        echo "commit-slot: invalid interval configuration"
        return 1
    fi

    if ! TZ="$TIMEZONE" date +%s >/dev/null 2>&1; then
        echo "commit-slot: invalid timezone: $TIMEZONE"
        return 1
    fi
}


# ============================================================
# GNU date vs BSD date
# ============================================================

if date --version >/dev/null 2>&1; then
    DATE_GNU=true
else
    DATE_GNU=false
fi


# ============================================================
# Date helpers
# ============================================================

today_midnight_epoch() {
    if $DATE_GNU; then
        TZ="$TIMEZONE" date -d "today 00:00:00" +%s
    else
        TZ="$TIMEZONE" date -v0H -v0M -v0S +%s
    fi
}


timestamp_epoch() {
    timestamp="$1"

    if $DATE_GNU; then
        TZ="$TIMEZONE" date -d "$timestamp" +%s 2>/dev/null
    else
        TZ="$TIMEZONE" date \
            -j \
            -f "%Y-%m-%dT%H:%M:%S%z" \
            "$timestamp" \
            +%s 2>/dev/null
    fi
}


epoch_to_iso() {
    epoch="$1"

    if $DATE_GNU; then
        TZ="$TIMEZONE" date -d "@$epoch" +%Y-%m-%dT%H:%M:%S%z
    else
        TZ="$TIMEZONE" date -r "$epoch" +%Y-%m-%dT%H:%M:%S%z
    fi
}


epoch_date() {
    epoch="$1"

    if $DATE_GNU; then
        TZ="$TIMEZONE" date -d "@$epoch" +%Y-%m-%d
    else
        TZ="$TIMEZONE" date -r "$epoch" +%Y-%m-%d
    fi
}


epoch_time_seconds() {
    epoch="$1"

    if $DATE_GNU; then
        value="$(TZ="$TIMEZONE" date -d "@$epoch" +%H:%M:%S)"
    else
        value="$(TZ="$TIMEZONE" date -r "$epoch" +%H:%M:%S)"
    fi

    hour="$(printf '%s' "$value" | cut -d: -f1)"
    minute="$(printf '%s' "$value" | cut -d: -f2)"
    second="$(printf '%s' "$value" | cut -d: -f3)"

    echo $((10#$hour * 3600 + 10#$minute * 60 + 10#$second))
}


date_at_time_epoch() {
    date="$1"
    time="$2"

    if $DATE_GNU; then
        TZ="$TIMEZONE" date -d "$date $time:00" +%s
    else
        TZ="$TIMEZONE" date \
            -j \
            -f "%Y-%m-%d %H:%M:%S" \
            "$date $time:00" \
            +%s 2>/dev/null
    fi
}


random_minutes() {
    range=$((MAX_INTERVAL - MIN_INTERVAL + 1))

    if command -v od >/dev/null 2>&1 && [ -r /dev/urandom ]; then
        value="$(od -An -N2 -tu2 /dev/urandom 2>/dev/null | tr -d '[:space:]')"

        case "$value" in
            ''|*[!0-9]*)
                ;;
            *)
            echo $((MIN_INTERVAL + value % range))
            return
                ;;
        esac
    fi

    if command -v shuf >/dev/null 2>&1; then
        value="$(shuf -i "$MIN_INTERVAL-$MAX_INTERVAL" -n 1 2>/dev/null)"

        if [ -n "$value" ]; then
            echo "$value"
            return
        fi
    fi

    if [ "${RANDOM+set}" = "set" ]; then
        echo $((MIN_INTERVAL + RANDOM % range))
        return
    fi

    # Seed awk with a changing value so rapid consecutive calls do not repeat.
    RNG_COUNTER=$((RNG_COUNTER + 1))
    now="$(date +%s 2>/dev/null)"

    case "$now" in
        ''|*[!0-9]*) now=0 ;;
    esac

    seed=$((now + $$ + RNG_COUNTER))
    value="$(awk -v min="$MIN_INTERVAL" -v max="$MAX_INTERVAL" -v seed="$seed" 'BEGIN { srand(seed); print int(min + rand() * (max - min + 1)) }' 2>/dev/null)"

    case "$value" in
        ''|*[!0-9]*)
            ;;
        *)
        echo "$value"
        return
            ;;
    esac

    echo "$MIN_INTERVAL"
}


# ============================================================
# Lock
# ============================================================

acquire_lock() {
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        printf '%s\n' "$$" > "$LOCK_DIR/pid"
        return 0
    fi

    lock_pid=""

    if [ -f "$LOCK_DIR/pid" ]; then
        lock_pid="$(cat "$LOCK_DIR/pid" 2>/dev/null)"
    fi

    case "$lock_pid" in
        ''|*[!0-9]*)
            ;;
        *)
    if kill -0 "$lock_pid" 2>/dev/null; then
        echo "commit-slot: another process is running (PID $lock_pid)"
        return 1
    fi
            ;;
    esac

    rm -rf "$LOCK_DIR"

    if mkdir "$LOCK_DIR" 2>/dev/null; then
        printf '%s\n' "$$" > "$LOCK_DIR/pid"
        return 0
    fi

    echo "commit-slot: failed to acquire lock"
    return 1
}


release_lock() {
    rm -rf "$LOCK_DIR"
}


# ============================================================
# Read persisted pointer
# ============================================================

read_pointer() {
    POINTER=""

    while IFS='=' read -r key value; do
        if [ "$key" = "pointer" ]; then
            POINTER="$value"
        fi
    done < "$SLOT_FILE"
}


# ============================================================
# Get latest Git commit timestamp
# ============================================================

latest_commit_epoch() {
    value="$(git log -1 --format=%cI 2>/dev/null)"

    if [ -z "$value" ]; then
        echo "0"
        return
    fi

    timestamp_epoch "$value"
}


# ============================================================
# Write persisted pointer atomically
# ============================================================

write_pointer() {
    timestamp="$1"
    tmp_file="${SLOT_FILE}.tmp.$$"
    found_pointer=false

    if ! while IFS='=' read -r key value; do
        if [ "$key" = "pointer" ]; then
            printf 'pointer=%s\n' "$timestamp"
            found_pointer=true
        else
            printf '%s=%s\n' "$key" "$value"
        fi
    done < "$SLOT_FILE" > "$tmp_file"; then
        rm -f "$tmp_file"
        echo "commit-slot: failed to read commit-slot.cfg"
        return 1
    fi

    if ! $found_pointer; then
        printf 'pointer=%s\n' "$timestamp" >> "$tmp_file"
    fi

    if ! mv "$tmp_file" "$SLOT_FILE"; then
        rm -f "$tmp_file"
        echo "commit-slot: failed to update commit-slot.cfg"
        return 1
    fi
}


# ============================================================
# init
# ============================================================

init_repository() {

    if [ ! -f "$SLOT_FILE" ]; then
        printf 'pointer=\n' > "$SLOT_FILE"
        echo "commit-slot: created commit-slot.cfg"
    else
        echo "commit-slot: commit-slot.cfg already exists"
    fi

    if git -C "$GIT_ROOT" check-ignore -q --no-index commit-slot.cfg 2>/dev/null; then
        echo "commit-slot: commit-slot.cfg is already ignored"
        return 0
    fi

    if [ ! -f "$GITIGNORE" ]; then
        printf 'commit-slot.cfg\n' > "$GITIGNORE"
        echo "commit-slot: created .gitignore"
        return 0
    fi

    if [ -s "$GITIGNORE" ]; then
        last_char="$(tail -c 1 "$GITIGNORE" 2>/dev/null)"

        if [ -n "$last_char" ]; then
            printf '\n' >> "$GITIGNORE"
        fi
    fi

    printf 'commit-slot.cfg\n' >> "$GITIGNORE"

    echo "commit-slot: added commit-slot.cfg to .gitignore"
}


# ============================================================
# status
# ============================================================

status_repository() {

    if [ ! -f "$SLOT_FILE" ]; then
        echo "commit-slot: disabled"
        return 0
    fi

    read_pointer

    latest_commit="$(git log -1 --format=%cI 2>/dev/null)"

    echo "commit-slot: enabled"
    echo "timezone:    $TIMEZONE"
    echo "restricted:  $START-$END"
    echo "interval:    $MIN_INTERVAL-$MAX_INTERVAL minutes"
    echo "slot:        ${POINTER:-not generated}"
    echo "last commit: ${latest_commit:-none}"
}


# ============================================================
# reset
# ============================================================

reset_repository() {

    if [ ! -f "$SLOT_FILE" ]; then
        echo "commit-slot: commit-slot.cfg does not exist"
        return 1
    fi

    if ! acquire_lock; then
        return 1
    fi

    printf 'pointer=\n' > "$SLOT_FILE"

    unset GIT_AUTHOR_DATE
    unset GIT_COMMITTER_DATE

    release_lock

    echo "commit-slot: timestamp pointer reset"
}


# ============================================================
# Generate next timestamp
# ============================================================

generate_slot() {

    if [ ! -f "$SLOT_FILE" ]; then
        return 0
    fi

    validate_config || return 1

    if ! acquire_lock; then
        return 1
    fi

    read_pointer

    pointer_epoch=0
    commit_epoch=0

    today_start="$(today_midnight_epoch)"

    if [ -z "$today_start" ]; then
        release_lock
        echo "commit-slot: failed to determine today's date"
        return 1
    fi

    # Timestamp from commit-slot.cfg.
    if [ -n "$POINTER" ]; then
        pointer_epoch="$(timestamp_epoch "$POINTER")"

        if [ -z "$pointer_epoch" ]; then
            release_lock
            echo "commit-slot: invalid timestamp in commit-slot.cfg: $POINTER"
            return 1
        fi
    fi

    # Timestamp of the latest Git commit.
    commit_epoch="$(latest_commit_epoch)"

    # Pick the most recent of:
    #   1. today's midnight
    #   2. latest Git commit
    #   3. commit-slot.cfg pointer
    base_epoch="$today_start"

    if (( commit_epoch > base_epoch )); then
        base_epoch="$commit_epoch"
    fi

    if (( pointer_epoch > base_epoch )); then
        base_epoch="$pointer_epoch"
    fi

    # Add a random 5-7 minute buffer.
    buffer="$(random_minutes)"
    candidate_epoch=$((base_epoch + buffer * 60))

    # If the candidate enters the restricted window,
    # jump to the end of the window and add another buffer.
    candidate_seconds="$(epoch_time_seconds "$candidate_epoch")"

    if (( candidate_seconds >= $(hhmm_to_seconds "$START") &&
          candidate_seconds < $(hhmm_to_seconds "$END") )); then

        candidate_date="$(epoch_date "$candidate_epoch")"
        end_epoch="$(date_at_time_epoch "$candidate_date" "$END")"

        if [ -z "$end_epoch" ]; then
            release_lock
            echo "commit-slot: failed to calculate restricted window"
            return 1
        fi

        buffer="$(random_minutes)"
        candidate_epoch=$((end_epoch + buffer * 60))
    fi

    timestamp="$(epoch_to_iso "$candidate_epoch")"

    if [ -z "$timestamp" ]; then
        release_lock
        echo "commit-slot: failed to generate timestamp"
        return 1
    fi

    if ! write_pointer "$timestamp"; then
        release_lock
        return 1
    fi

    release_lock

    export GIT_AUTHOR_DATE="$timestamp"
    export GIT_COMMITTER_DATE="$timestamp"

    echo "commit-slot: $timestamp"
}


# ============================================================
# Main
# ============================================================

case "${1:-}" in

    init)
        init_repository
        ;;

    status)
        status_repository
        ;;

    reset)
        reset_repository
        ;;

    help|-h|--help)
        usage
        ;;

    "")
        if [ ! -f "commit-slot.cfg" ]; then
            usage
        else
            generate_slot
        fi
        ;;

    *)
        echo "commit-slot: unknown command: $1"
        echo
        usage
        return 1
        ;;

esac
