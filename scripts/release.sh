#!/bin/bash
# warteliste_pro — Full-auto release script
# Erstellt vom Hasi Agent Army (2026-04-23)
#
# Usage:  bash scripts/release.sh
#         bash scripts/release.sh --dry-run    (nur bauen, kein Upload)
#         bash scripts/release.sh --android    (nur Android)
#         bash scripts/release.sh --ios        (nur iOS)

set -e

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
LOG_DIR="$ROOT/_release-logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/release-$(date +%Y%m%d-%H%M%S).log"

# Alles was folgt wird sowohl auf die Konsole als auch in die Logdatei geschrieben
exec > >(tee -a "$LOG") 2>&1

# ====== Flags ======
DRY_RUN=0
ONLY_ANDROID=0
ONLY_IOS=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --android) ONLY_ANDROID=1 ;;
    --ios)     ONLY_IOS=1 ;;
  esac
done

# ====== Farb-Helpers ======
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
step() { echo -e "\n${BLUE}━━━ $1 ━━━${NC}"; }
ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
err()  { echo -e "${RED}✗${NC} $1"; exit 1; }

# ====== Pre-flight checks ======
step "0/7 Pre-flight checks"

command -v flutter >/dev/null || err "flutter nicht im PATH"
command -v python3 >/dev/null || err "python3 nicht im PATH"
[ -f "pubspec.yaml" ] || err "Nicht im warteliste_pro root"

VERSION=$(grep -E "^version: " pubspec.yaml | awk '{print $2}' | tr -d '"')
ok "Version: $VERSION"

# Keys check
APPLE_KEY="$HOME/.config/appstoreconnect-api/AuthKey_X3J36XDY86.p8"
PLAY_KEY="$HOME/.config/play-publisher/warteliste-pro-key.json"
[ -f "$APPLE_KEY" ] || warn "Apple key fehlt: $APPLE_KEY (iOS-Upload wird scheitern)"
[ -f "$PLAY_KEY" ]  || warn "Play key fehlt: $PLAY_KEY (Android-Upload wird scheitern)"

# ====== Git commit (falls Änderungen) ======
step "1/7 Git commit pending changes"

if [ -n "$(git status -s)" ]; then
  git add .gitignore CLAUDE.md ios/Runner/Info.plist store/release_notes_v1.5.1.md scripts/release.sh 2>/dev/null || true
  if [ -n "$(git diff --cached --stat)" ]; then
    git commit -m "chore: release v$VERSION — iOS compliance + automation

- Remove unused camera/microphone permissions (App Store review safe)
- Update CLAUDE.md to v$VERSION
- Add release notes for Play/App Store/TestFlight
- Add release.sh automation script

Refs: Hasi agent army QA audit 2026-04-23"
    ok "Commit erstellt"
  else
    ok "Keine relevanten Änderungen zum Committen"
  fi
else
  ok "Git working tree clean"
fi

# Git tag
if git rev-parse "v$VERSION" >/dev/null 2>&1; then
  warn "Tag v$VERSION existiert bereits — überspringe"
else
  git tag -a "v$VERSION" -m "Release v$VERSION"
  ok "Tag v$VERSION erstellt"
fi

# ====== Flutter clean + deps ======
step "2/7 Flutter clean + pub get"
flutter clean
flutter pub get
ok "Flutter bereit"

# ====== ANDROID ======
if [ "$ONLY_IOS" = "0" ]; then
  step "3/7 Android — AAB build"
  flutter build appbundle --release
  AAB="build/app/outputs/bundle/release/app-release.aab"
  [ -f "$AAB" ] || err "AAB nicht gefunden: $AAB"
  SIZE=$(du -h "$AAB" | cut -f1)
  ok "AAB erstellt: $AAB ($SIZE)"

  step "4/7 Android — Google Play Upload (internal, draft)"
  if [ "$DRY_RUN" = "1" ]; then
    warn "DRY-RUN: Upload übersprungen"
  elif [ ! -f "$PLAY_KEY" ]; then
    warn "Play key fehlt — Upload übersprungen"
  else
    python3 scripts/upload_to_play.py "$AAB" --track internal --status draft
    ok "Play Console Upload fertig"
  fi
fi

# ====== iOS ======
if [ "$ONLY_ANDROID" = "0" ]; then
  step "5/7 iOS — IPA build"
  flutter build ipa --release
  IPA=$(find build/ios/ipa -name "*.ipa" -type f 2>/dev/null | head -1)
  [ -f "$IPA" ] || err "IPA nicht gefunden in build/ios/ipa/"
  SIZE=$(du -h "$IPA" | cut -f1)
  ok "IPA erstellt: $IPA ($SIZE)"

  step "6/7 iOS — App Store Connect Upload (TestFlight)"
  if [ "$DRY_RUN" = "1" ]; then
    warn "DRY-RUN: Upload übersprungen"
  elif [ ! -f "$APPLE_KEY" ]; then
    warn "Apple key fehlt — Upload übersprungen"
  else
    xcrun altool --upload-app --type ios \
      --file "$IPA" \
      --apiKey X3J36XDY86 \
      --apiIssuer f450133a-5308-4a08-9234-a7052b5190e9
    ok "App Store Connect Upload fertig"

    # Automatisch zur hasi internal TestFlight group zuweisen
    step "7/7 TestFlight — Assign to hasi internal group"
    sleep 30  # Warten bis Build in ASC sichtbar
    python3 scripts/check_testflight.py || warn "check_testflight.py fehlgeschlagen (manuell in ASC zuweisen)"
  fi
fi

# ====== Zusammenfassung ======
step "FERTIG — v$VERSION"
echo ""
echo -e "${GREEN}✓${NC} Log: $LOG"
echo ""
echo "Nächste Schritte (manuell):"
echo "  1. Play Console → Internal testing → Release erstellen + Release Notes einfügen"
echo "     https://play.google.com/console"
echo "  2. App Store Connect → TestFlight → Processing abwarten (~15 Min)"
echo "     https://appstoreconnect.apple.com"
echo "  3. Release Notes kopieren aus: store/release_notes_v${VERSION%+*}.md"
echo ""
echo -e "${BLUE}Falls Fehler: Log anschauen — $LOG${NC}"
