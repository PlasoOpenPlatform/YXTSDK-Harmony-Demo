#!/usr/bin/env bash
# Pack a clean yxt-hos-sdkdemo source zip for external users.
# Excludes build artifacts, .git, oh_modules, *.bat/*.sh/*.ps1 and scripts/, etc.
# Sanitize: strip app.signingConfigs materials/secrets (set to []);
# keep products[*].signingConfig binding.
# Uses surgical text replace (no json re-serialize) to preserve json5 layout.
# Output: <repo>/dist/yxt-hos-sdkdemo-<yxtsdk-version or YYYYMMDD>.zip
# Usage:
#   bash scripts/pack_release.sh
#   bash scripts/pack_release.sh 1.0.25
# On Git Bash for Windows, prefer non-login shell (avoid bash -l if profile hangs):
#   bash --noprofile --norc scripts/pack_release.sh
# Run from anywhere; repo root is resolved from this script location.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSION="${1:-}"
DIST="${ROOT}/dist"
STAMP="$(date +%Y%m%d)"

read_yxtsdk_version() {
  local pkg="${ROOT}/entry/oh-package.json5"
  [[ -f "$pkg" ]] || return 0
  sed -n 's/.*"yxtsdk"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$pkg" | head -n1
}

if [[ -z "$VERSION" ]]; then
  VERSION="$(read_yxtsdk_version || true)"
fi
if [[ -z "$VERSION" ]]; then
  VERSION="release-${STAMP}"
fi

ZIP_NAME="yxt-hos-sdkdemo-${VERSION}.zip"
ZIP_PATH="${DIST}/${ZIP_NAME}"
STAGE_PARENT="${DIST}/_pack_stage_$$"
STAGE="${STAGE_PARENT}/yxt-hos-sdkdemo"

mkdir -p "$STAGE"

copied=0
while IFS= read -r -d '' rel; do
  rel="${rel#./}"
  base="$(basename "$rel")"
  case "$base" in
    local.properties|.DS_Store|Thumbs.db) continue ;;
    *.hap|*.app|*.har|*.hsp|*.iml|*.bat|*.sh|*.ps1) continue ;;
    yxt-hos-sdkdemo-*.zip) continue ;;
  esac
  dest="${STAGE}/${rel}"
  mkdir -p "$(dirname "$dest")"
  cp -p "${ROOT}/${rel}" "$dest"
  copied=$((copied + 1))
done < <(
  cd "$ROOT" && find . \
    \( -name .git -o -name oh_modules -o -name node_modules -o -name build \
       -o -name .hvigor -o -name .idea -o -name .cxx -o -name dist -o -name out \
       -o -name log -o -name .preview -o -name .clangd -o -name scripts \
       -o -name '_pack_stage_*' \) \
    -prune -o -type f -print0
)

echo "Copied ${copied} files into staging"

# Surgical clear of signingConfigs array via brace match (preserves layout/comments/EOL).
# Prefer a real Python (skip Microsoft Store WindowsApps stub — it hangs).
sanitize_build_profile() {
  local bp="$1"
  [[ -f "$bp" ]] || return 0

  local py="" c p
  local py_skip_reason=""
  for c in python3 python; do
    if command -v "$c" >/dev/null 2>&1; then
      p="$(command -v "$c")"
      case "$p" in
        *WindowsApps*)
          py_skip_reason="skipped Microsoft Store stub: $p"
          continue
          ;;
      esac
      if "$c" -c "pass" >/dev/null 2>&1; then
        py="$c"
        break
      else
        py_skip_reason="found $p but '$c -c pass' failed"
      fi
    fi
  done

  if [[ -n "$py" ]]; then
    "$py" - "$bp" <<'PY'
import re, sys
path = sys.argv[1]
with open(path, "rb") as f:
    raw = f.read()
had_bom = raw.startswith(b"\xef\xbb\xbf")
if had_bom:
    raw = raw[3:]
text = raw.decode("utf-8")
m = re.search(r'"signingConfigs"\s*:\s*\[', text)
if not m:
    print("WARN: signingConfigs array not found; leaving build-profile.json5 unchanged", file=sys.stderr)
    sys.exit(0)
start = m.end() - 1  # index of '['
depth = 0
in_string = False
escape = False
end = -1
for i in range(start, len(text)):
    ch = text[i]
    if in_string:
        if escape:
            escape = False
            continue
        if ch == "\\":
            escape = True
            continue
        if ch == '"':
            in_string = False
        continue
    if ch == '"':
        in_string = True
        continue
    if ch == "[":
        depth += 1
    elif ch == "]":
        depth -= 1
        if depth == 0:
            end = i
            break
if end < 0:
    raise SystemExit("Unbalanced signingConfigs array in build-profile.json5")
# Strip signing materials/secrets only; do NOT delete products[*].signingConfig
out = text[:start] + "[]" + text[end + 1 :]
with open(path, "wb") as f:
    f.write(out.encode("utf-8"))  # UTF-8 without BOM
print("Sanitized build-profile.json5 (cleared signingConfigs; kept product signingConfig)")
PY
    return 0
  fi

  # Fallback: PowerShell surgical replace via temp .ps1 (Windows -File requires .ps1)
  if [[ -n "$py_skip_reason" ]]; then
    echo "INFO: python sanitizer unavailable ($py_skip_reason); trying PowerShell fallback" >&2
  else
    echo "INFO: no python3/python on PATH; trying PowerShell fallback" >&2
  fi
  if command -v powershell.exe >/dev/null 2>&1 || command -v powershell >/dev/null 2>&1; then
    local ps="powershell.exe"
    command -v powershell.exe >/dev/null 2>&1 || ps="powershell"
    local win_bp="$bp"
    if command -v cygpath >/dev/null 2>&1; then
      win_bp="$(cygpath -w "$bp")"
    fi
    # mktemp MUST keep .ps1 suffix - powershell -File rejects other extensions
    local tmp_ps
    tmp_ps="$(mktemp "${TMPDIR:-/tmp}/pack_sanitize.XXXXXX.ps1" 2>/dev/null || echo "${TMPDIR:-/tmp}/pack_sanitize_$$.ps1")"
    # Ensure suffix even if mktemp ignored the template (some builds)
    case "$tmp_ps" in
      *.ps1) ;;
      *) tmp_ps="${tmp_ps}.ps1"; : >"$tmp_ps" ;;
    esac
    local win_tmp="$tmp_ps"
    if command -v cygpath >/dev/null 2>&1; then
      win_tmp="$(cygpath -w "$tmp_ps")"
    fi
    cat >"$tmp_ps" <<'PSEOF'
$ErrorActionPreference = 'Stop'
$bp = $env:PACK_BP
$bytes = [IO.File]::ReadAllBytes($bp)
$enc = New-Object System.Text.UTF8Encoding $false
$off = 0
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $off = 3 }
$text = $enc.GetString($bytes, $off, $bytes.Length - $off)
$m = [regex]::Match($text, '"signingConfigs"\s*:\s*\[')
if (-not $m.Success) { Write-Warning 'signingConfigs not found'; exit 0 }
$start = $m.Index + $m.Length - 1
$depth = 0; $inStr = $false; $esc = $false; $end = -1
for ($i = $start; $i -lt $text.Length; $i++) {
  $c = $text[$i]
  if ($inStr) {
    if ($esc) { $esc = $false; continue }
    if ($c -eq [char]92) { $esc = $true; continue }
    if ($c -eq [char]34) { $inStr = $false }
    continue
  }
  if ($c -eq [char]34) { $inStr = $true; continue }
  if ($c -eq [char]91) { $depth++ }
  elseif ($c -eq [char]93) {
    $depth--
    if ($depth -eq 0) { $end = $i; break }
  }
}
if ($end -lt 0) { throw 'Unbalanced signingConfigs' }
$text = $text.Substring(0, $start) + '[]' + $text.Substring($end + 1)
[IO.File]::WriteAllText($bp, $text, $enc)
Write-Host 'Sanitized build-profile.json5 (cleared signingConfigs; kept product signingConfig)'
PSEOF
    PACK_BP="$win_bp" "$ps" -NoProfile -ExecutionPolicy Bypass -File "$win_tmp"
    rm -f "$tmp_ps"
    return 0
  fi

  echo "WARN: no usable python/powershell ($py_skip_reason); leaving build-profile.json5 as-is (may contain local signing paths)" >&2
}

sanitize_build_profile "${STAGE}/build-profile.json5"

mkdir -p "$DIST"
rm -f "$ZIP_PATH"

# Prefer zip(1); on Windows/Git Bash use PowerShell Compress-Archive (more compatible
# than Git tar -a zip). Fall back to tar -a last.
if command -v zip >/dev/null 2>&1; then
  ( cd "$STAGE_PARENT" && zip -rq "$ZIP_PATH" "yxt-hos-sdkdemo" )
elif command -v powershell.exe >/dev/null 2>&1 || command -v powershell >/dev/null 2>&1; then
  ps="powershell.exe"
  command -v powershell.exe >/dev/null 2>&1 || ps="powershell"
  win_stage="$STAGE_PARENT"
  win_zip="$ZIP_PATH"
  if command -v cygpath >/dev/null 2>&1; then
    win_stage="$(cygpath -w "$STAGE_PARENT")"
    win_zip="$(cygpath -w "$ZIP_PATH")"
  fi
  tmp_zip_ps=""
  tmp_zip_ps="$(mktemp "${TMPDIR:-/tmp}/pack_zip.XXXXXX.ps1" 2>/dev/null || echo "${TMPDIR:-/tmp}/pack_zip_$$.ps1")"
  case "$tmp_zip_ps" in
    *.ps1) ;;
    *) tmp_zip_ps="${tmp_zip_ps}.ps1"; : >"$tmp_zip_ps" ;;
  esac
  win_zip_ps="$tmp_zip_ps"
  if command -v cygpath >/dev/null 2>&1; then
    win_zip_ps="$(cygpath -w "$tmp_zip_ps")"
  fi
  cat >"$tmp_zip_ps" <<'ZIPEOF'
$ErrorActionPreference = 'Stop'
$stage = $env:PACK_STAGE
$zip = $env:PACK_ZIP
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -Force
ZIPEOF
  PACK_STAGE="$win_stage" PACK_ZIP="$win_zip" "$ps" -NoProfile -ExecutionPolicy Bypass -File "$win_zip_ps"
  rm -f "$tmp_zip_ps"

else
  ( cd "$STAGE_PARENT" && tar -a -c -f "$ZIP_PATH" "yxt-hos-sdkdemo" )
fi

rm -rf "$STAGE_PARENT"

size_b="$(wc -c < "$ZIP_PATH" | tr -d ' ')"
size_kb="$((size_b / 1024))"
echo ""
echo "Release zip: ${ZIP_PATH}"
echo "Size: ${size_kb} KB"
echo "Users should: ohpm install (oh_modules not bundled)"