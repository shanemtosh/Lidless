#!/bin/zsh
# Build a signed Release Lidless and install it to /Applications.
#
# Must be run from a GUI terminal session (Ghostty, Terminal.app), NOT over ssh
# or from a background agent. Code signing needs the private key out of the login
# keychain, and the first access shows a keychain prompt — click "Always Allow"
# and it won't ask again. Without a GUI session the prompt can't be displayed and
# codesign fails with errSecInternalComponent.

set -euo pipefail
cd "$(dirname "$0")/.."

APP=/Applications/Lidless.app
DERIVED=build

echo "==> Checking for a valid signing identity"
if ! security find-identity -v -p codesigning | grep -q "Apple Develop"; then
  echo "No valid codesigning identity found." >&2
  echo "Xcode → Settings → Accounts → Manage Certificates → + → Apple Development" >&2
  exit 1
fi
security find-identity -v -p codesigning | sed -n '1p'

echo "==> Generating Xcode project from project.yml"
if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
else
  # Not installed globally; mise fetches it into its own cache.
  mise exec aqua:yonaskolb/XcodeGen -- xcodegen generate
fi

echo "==> Building signed Release"
# Full output to a log; only the interesting lines to the terminal. On failure the
# whole log is dumped — a filtered view that hides the actual error is worse than
# no filter at all.
LOG="$DERIVED/build.log"
mkdir -p "$DERIVED"
if xcodebuild build \
  -scheme Lidless \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates > "$LOG" 2>&1
then
  grep -E "BUILD SUCCEEDED" "$LOG" || true
else
  echo "--- build failed; last 40 lines of $LOG ---" >&2
  tail -40 "$LOG" >&2
  if grep -q errSecInternalComponent "$LOG"; then
    cat >&2 <<'HINT'

errSecInternalComponent means codesign could not use the private key.
Populate the key's access control list, then re-run this script:

  security set-key-partition-list -S apple-tool:,apple:,codesign: \
    -s ~/Library/Keychains/login.keychain-db

It prompts for your login password (twice is normal).
HINT
  fi
  exit 1
fi

BUILT="$DERIVED/Build/Products/Release/Lidless.app"
if [[ ! -d "$BUILT" ]]; then
  echo "Build did not produce $BUILT" >&2
  exit 1
fi

echo "==> Verifying signature"
codesign -dv --verbose=2 "$BUILT" 2>&1 | grep -E "Authority=|TeamIdentifier=|Identifier="
codesign --verify --deep --strict "$BUILT" && echo "    signature OK"

echo "==> Verifying the helper is embedded"
ls "$BUILT/Contents/MacOS/LidlessHelper" >/dev/null && echo "    helper binary present"
ls "$BUILT/Contents/Library/LaunchDaemons/" | sed 's/^/    /'

# SMAppService wants the app at a stable path; /Applications is the conventional
# one and avoids the daemon pointing at a build directory that later disappears.
echo "==> Installing to $APP"
if pgrep -x Lidless >/dev/null; then
  echo "    quitting running instance"
  osascript -e 'tell application "Lidless" to quit' 2>/dev/null || pkill -x Lidless || true
  sleep 1
fi
rm -rf "$APP"
cp -R "$BUILT" "$APP"

echo "==> Launching"
open "$APP"

cat <<'EOF'

Next, in the app:
  1. Click the menu bar icon → enable the background helper. macOS will ask you
     to approve it in System Settings → General → Login Items & Extensions.
  2. Once the helper says it's running, toggle keep-awake.

Check what actually happened:
  pmset -g | grep SleepDisabled          # 1 = lid close is being ignored
  launchctl print system/com.shanemcintosh.lidless.helper | head -20
  log show --predicate 'sender == "LidlessHelper"' --last 10m

If the helper refuses connections, that's the client code-signing requirement
doing its job — check the log for "[LidlessHelper]" lines.
EOF
