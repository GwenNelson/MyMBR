# Common loop-device handling for scripts.

LOOP=""
LOOP_OWNED=0
LOOP_IMAGE=""
LOOP_STATE=""

LOOP_FUNCS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

loop_state_for_image()
{
    local image="$1"

    printf '%s.loop-device\n' "$(realpath "$image")"
}

loop_verify()
{
    local loop="$1"
    local image="$2"

    local expected
    local actual

    expected=$(realpath "$image") || return 1

    [ -b "$loop" ] || {
        echo "FAILED: recorded loop device '$loop' does not exist" >&2
        return 1
    }

    actual=$(sudo losetup -n -O BACK-FILE "$loop") || {
        echo "FAILED: could not determine backing file for '$loop'" >&2
        return 1
    }

    actual=$(realpath "$actual") || return 1

    [ "$actual" = "$expected" ] || {
        echo "FAILED: $loop is attached to '$actual', expected '$expected'" >&2
        return 1
    }
}

loop_acquire()
{
    local image="${1:-}"

    [ -n "$image" ] || {
        echo "FAILED: loop_acquire requires an image filename" >&2
        return 1
    }

    [ -f "$image" ] || {
        echo "FAILED: image '$image' does not exist" >&2
        return 1
    }

    LOOP_IMAGE=$(realpath "$image") || return 1
    LOOP_STATE=$(loop_state_for_image "$LOOP_IMAGE") || return 1

    if [ -f "$LOOP_STATE" ]; then
        LOOP=$(cat "$LOOP_STATE")
        LOOP_OWNED=0

        loop_verify "$LOOP" "$LOOP_IMAGE" ||
            return 1

        echo "Using existing loop device $LOOP for $LOOP_IMAGE" >&2
    else
        LOOP=$("$LOOP_FUNCS_DIR/attach-loop.sh" "$LOOP_IMAGE") ||
            return 1

        LOOP_OWNED=1
    fi
}

loop_cleanup()
{
    if [ "$LOOP_OWNED" -eq 1 ]; then
        "$LOOP_FUNCS_DIR/detach-loop.sh" "$LOOP_IMAGE"
        LOOP_OWNED=0
    fi
}
