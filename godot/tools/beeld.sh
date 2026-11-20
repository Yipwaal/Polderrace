#!/bin/sh
# Beeld survey: run a Godot tool scene under xvfb with this worktree's own save folder; the log goes to
# godot/tests/.out/beeld/<scene>.log and the lines that matter are printed at the end.
#   godot/tools/beeld.sh shot_beeld tracks=polder out=/abs/dir ...
#   godot/tools/beeld.sh runner perf memory        (the tests with a renderer)
#   RES=2560x1440 TIMEOUT=600 godot/tools/beeld.sh ...
cd "$(dirname "$0")/../.." || exit 1
export XDG_DATA_HOME="$PWD/.xdg"
scene="$1"; shift
case "$scene" in
  runner) path="res://tests/runner.tscn" ;;
  *) path="res://tools/$scene.tscn" ;;
esac
RES="${RES:-1280x720}"
mkdir -p godot/tests/.out/beeld
log="godot/tests/.out/beeld/${LOG:-$scene}.log"
timeout "${TIMEOUT:-1800}" xvfb-run -a -s "-screen 0 ${RES}x24" godot --path godot --rendering-driver opengl3 --resolution "$RES" "$path" -- "$@" > "$log" 2>&1
code=$?
grep -v "ALSA lib\|^$\|audio_driver\|audio_server\|init_output_device\|All audio drivers" "$log" | tail -n "${TAIL:-40}"
echo "exit $code"
exit $code
