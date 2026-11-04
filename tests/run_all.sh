#!/usr/bin/env bash
# Runs every test headless and prints one line per test file.
#   tests/test_kinematics.gd  - the formulas, solvers and rocket maths
#   tests/scenarios/*.gd      - the game itself: launches, abilities, practice,
#                               levels, collisions... (each prints ok/FAIL lines)
# Usage: tests/run_all.sh            (from the project folder)
#        tests/run_all.sh -v         (show every ok/FAIL line)
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-$HOME/.local/bin/godot}"
VERBOSE="$1"
failed=0

run() {
	local name="$1" script="$2"
	local output
	output=$(timeout 600 "$GODOT" --headless --path . --script "$script" 2>&1 | grep -v "^Godot Engine")
	if [ "$VERBOSE" = "-v" ]; then echo "$output"; fi
	if echo "$output" | grep -qE "FAIL|SCRIPT ERROR" || ! echo "$output" | grep -qE "DONE, fails=0|All kinematics tests passed"; then
		echo "FAIL  $name"
		echo "$output" | grep -E "FAIL|SCRIPT ERROR" | head -5 | sed 's/^/      /'
		failed=1
	else
		echo "ok    $name"
	fi
}

run "kinematics" "res://tests/test_kinematics.gd"
for file in tests/scenarios/*.gd; do
	run "$(basename "$file" .gd)" "res://$file"
done
exit $failed
