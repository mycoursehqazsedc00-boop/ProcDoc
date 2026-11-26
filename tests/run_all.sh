#!/bin/bash
# Runs the ProcDoc test kit against the addon in the parent folder.
# Needs a Lua 5.3+ interpreter (texlua, lua5.3, lua5.4). Override with  LUA=lua5.4 ./run_all.sh
# Optional: SEEDS=100 STEPS=300 to size the random-session fuzz.
HERE=$(cd "$(dirname "$0")" && pwd); ADDON=$(dirname "$HERE")
LUA=${LUA:-$(command -v texlua || command -v lua5.4 || command -v lua5.3 || command -v lua)}
SEEDS=${SEEDS:-80}; STEPS=${STEPS:-300}
echo "== scenarios"; fail=0; total=0
for s in $(cat "$HERE/scenarios.txt"); do
  total=$((total+1)); out=$("$LUA" "$HERE/pdrun.lua" "$ADDON" "$s" 2>&1 | grep -E "^RESULT" | head -1)
  case "$out" in *"|PASS|"*) ;; *) fail=$((fail+1)); echo "FAIL $s: ${out:0:300}";; esac
done
echo "scenarios: $total run, $fail failed"
echo "== random sessions ($SEEDS seeds x $STEPS steps): tooltip reader vs ClassicAPI aura reader must behave identically"
bad=0; errs=0
for s in $(seq 1 "$SEEDS"); do
  a=$("$LUA" "$HERE/pdfuzz.lua" "$ADDON" "$s" "$STEPS" 2>&1 | grep "^SEED")
  b=$(AURA=1 "$LUA" "$HERE/pdfuzz.lua" "$ADDON" "$s" "$STEPS" 2>&1 | grep "^SEED")
  ha=$(echo "$a" | sed -n 's/.*sounds=\([0-9]*\).*hash=\([0-9]*\).*/\1:\2/p'); hb=$(echo "$b" | sed -n 's/.*sounds=\([0-9]*\).*hash=\([0-9]*\).*/\1:\2/p')
  ea=$(echo "$a" | sed -n 's/.*errs=\([0-9]*\).*/\1/p'); eb=$(echo "$b" | sed -n 's/.*errs=\([0-9]*\).*/\1/p')
  [ "${ea:-1}" != "0" ] || [ "${eb:-1}" != "0" ] && { errs=$((errs+1)); echo "seed $s: errors"; }
  [ "$ha" != "$hb" ] && { bad=$((bad+1)); echo "seed $s: tooltip and aura readers differ ($ha vs $hb)"; }
done
echo "sessions with errors: $errs | reader mismatches: $bad (of $SEEDS)"
[ $fail -eq 0 ] && [ $errs -eq 0 ] && [ $bad -eq 0 ] && echo "ALL GOOD" || { echo "PROBLEMS FOUND"; exit 1; }
