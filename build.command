#!/bin/bash
# Build Desetiprstka (Debug) a volitelně spuštění. Log: build.log
cd "$(dirname "$0")"
mkdir .buildlock 2>/dev/null || exit 0
trap 'rmdir .buildlock' EXIT
LOG="build.log"
echo "START $(date)" > "$LOG"
# Stabilní Xcode má přednost před betou.
XCODE_APP=$(mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" | grep -vi beta | head -1)
for d in "$XCODE_APP" /Applications/Xcode-beta.app /Applications/Xcode.app; do
  if [ -n "$d" ] && [ -d "$d/Contents/Developer" ]; then export DEVELOPER_DIR="$d/Contents/Developer"; break; fi
done
echo "DEVELOPER_DIR=$DEVELOPER_DIR" >> "$LOG"
# Běžící instanci ukončíme – přepis binárky za běhu by ji shodil.
pkill -x Desetiprstka 2>/dev/null; sleep 1
if [ -f .clean ]; then rm -rf .build .clean; echo "CLEAN" >> "$LOG"; fi
xcodebuild -project Desetiprstka.xcodeproj -target Desetiprstka -configuration Debug \
  SYMROOT="$PWD/.build" build >> "$LOG" 2>&1
STATUS=$?
echo "EXIT $STATUS" >> "$LOG"
if [ $STATUS -eq 0 ] && [ -f .run-after-build ]; then
  open "$PWD/.build/Debug/Desetiprstka.app"
  echo "LAUNCHED" >> "$LOG"
fi
echo "DONE" >> "$LOG"
exit 0
