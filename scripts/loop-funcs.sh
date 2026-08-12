# Common loop-device handling for scripts.

LOOP=""
LOOP_OWNED=0

LOOP_FUNCS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOOP_PROJECT_DIR="$LOOP_FUNCS_DIR/.."
LOOP_STATE="$LOOP_PROJECT_DIR/.loop-device"

loop_acquire()
{
    local image="${1:-$LOOP_PROJECT_DIR/mbr-test.img}"

    if [ -f "$LOOP_STATE" ]; then
        LOOP=$(cat "$LOOP_STATE")
        LOOP_OWNED=0

        [ -b "$LOOP" ] || {
            echo "FAILED: recorded loop device '$LOOP' does not exist" >&2
            return 1
        }

        echo "Using existing loop device $LOOP" >&2
    else
        LOOP=$("$LOOP_FUNCS_DIR/attach-loop.sh" "$image") || return 1
        LOOP_OWNED=1
    fi
}

loop_cleanup()
{
    if [ "$LOOP_OWNED" -eq 1 ]; then
        "$LOOP_FUNCS_DIR/detach-loop.sh"
        LOOP_OWNED=0
    fi
}
