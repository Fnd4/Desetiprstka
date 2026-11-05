#!/bin/bash
# Release build Desetiprstky → dist/Desetiprstka-<verze>.dmg. Log: release.log
cd "$(dirname "$0")"
exec > release.log 2>&1
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
echo "START $(date)"
echo "== Xcode =="
mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'"
DEV=""
while IFS= read -r x; do
  case "$x" in *[Bb]eta*) ;; *) [ -d "$x/Contents/Developer" ] && { DEV="$x/Contents/Developer"; break; } ;; esac
done < <(mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'")
[ -z "$DEV" ] && DEV=$(xcode-select -p)
export DEVELOPER_DIR="$DEV"; echo "DEVELOPER_DIR=$DEV"
xcodebuild -version
echo "== Identity =="
security find-identity -v -p codesigning
IDENT=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed -E 's/.*"(.*)"/\1/')
echo "DEVELOPER_ID=${IDENT:-none}"
rm -rf .build/release dist; mkdir -p dist
if [ -n "$IDENT" ]; then
  SIGN=(CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=$IDENT" "OTHER_CODE_SIGN_FLAGS=--timestamp" ENABLE_HARDENED_RUNTIME=YES)
else
  SIGN=(CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=-" DEVELOPMENT_TEAM= ENABLE_HARDENED_RUNTIME=YES)
fi
echo "== Build =="
xcodebuild -project Desetiprstka.xcodeproj -target Desetiprstka -configuration Release \
  SYMROOT="$PWD/.build/release" ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO "${SIGN[@]}" build | tail -30
APP=".build/release/Release/Desetiprstka.app"
[ -d "$APP" ] || { echo "EXIT 1 (app chybí)"; echo DONE; exit 0; }
VER=$(defaults read "$PWD/$APP/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo 1.0)
echo "VERSION=$VER"; lipo -archs "$APP/Contents/MacOS/Desetiprstka"
codesign -dv --verbose=2 "$APP" 2>&1 | grep -E "Authority|Signature|TeamIdentifier|Runtime|flags"
codesign --verify --deep --strict "$APP" && echo "VERIFY OK"
echo "== DMG =="
ROOT=dist/dmgroot; mkdir -p "$ROOT"; cp -R "$APP" "$ROOT/"; ln -s /Applications "$ROOT/Applications"
DMG="dist/Desetiprstka-$VER.dmg"
hdiutil create -volname "Desetiprstka" -srcfolder "$ROOT" -ov -format UDZO "$DMG"
rm -rf "$ROOT"
[ -n "$IDENT" ] && codesign --timestamp -s "$IDENT" "$DMG"
ls -la dist; shasum -a 256 "$DMG"
spctl -a -vv -t install "$DMG" 2>&1
echo "== Git =="
if [ -d .git ] && [ "$(git rev-list --count HEAD 2>/dev/null)" = "1" ] && git log -1 --format=%s | grep -q "Initial Commit"; then
  mv .git ".git-xcode-old-$(date +%s)"; echo "stará Xcode historie odložena"
fi
[ -d .git ] || git init -b main
if [ -z "$(git config user.name)" ]; then echo "NO_GIT_IDENTITY"; else
  git add -A && git commit -q -m "Desetiprstka $VER" && echo "COMMIT OK"; git log --oneline | head -3
fi
echo "== GitHub =="
if ! command -v gh >/dev/null; then echo "GH_MISSING"
elif ! gh auth status; then echo "GH_NOAUTH"
else
  git remote get-url origin >/dev/null 2>&1 || gh repo create Desetiprstka --public --source=. --remote=origin \
    --description "Česká macOS aplikace pro výuku psaní všemi deseti"
  git push -u origin main && echo "PUSH OK"
  gh release view "v$VER" >/dev/null 2>&1 || gh release create "v$VER" "$DMG" --title "Desetiprstka $VER" \
    --notes "První veřejná verze. Stáhni Desetiprstka-$VER.dmg, přetáhni aplikaci do složky Aplikace a při prvním spuštění povol ji v Nastavení systému → Soukromí a zabezpečení → Přesto otevřít."
  gh repo view --json url -q .url
fi
echo "EXIT 0"; echo "DONE"
