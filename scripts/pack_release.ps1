# Pack a clean yxt-hos-sdkdemo source zip for external users.
# Excludes build artifacts, .git, oh_modules, *.bat/*.sh/*.ps1 and scripts/, etc.
# Sanitize: strip app.signingConfigs materials/secrets (set to []); keep products[*].signingConfig binding.
# Uses surgical text replace (no ConvertFrom-Json/ConvertTo-Json) to preserve json5 layout.
# Output: <repo>/dist/yxt-hos-sdkdemo-<yxtsdk-version or YYYYMMDD>.zip
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\pack_release.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\pack_release.ps1 -Version 1.0.25
# Prefer scripts\pack_release.bat wrapper on Windows.
param(
  [string]$Root = "",
  [string]$Version = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Root)) {
  $Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
} else {
  $Root = (Resolve-Path $Root).Path
}

$dist = Join-Path $Root "dist"
$stamp = Get-Date -Format "yyyyMMdd"

if ([string]::IsNullOrWhiteSpace($Version)) {
  $entryPkg = Join-Path $Root "entry\oh-package.json5"
  if (Test-Path -LiteralPath $entryPkg) {
    $txt = Get-Content -Raw -LiteralPath $entryPkg
    if ($txt -match '"yxtsdk"\s*:\s*"([^"]+)"') {
      $Version = $Matches[1]
    }
  }
}
if ([string]::IsNullOrWhiteSpace($Version)) {
  $Version = "release-$stamp"
}

$zipName = "yxt-hos-sdkdemo-$Version.zip"
$zipPath = Join-Path $dist $zipName
$stageParent = Join-Path $dist ("_pack_stage_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
$stage = Join-Path $stageParent "yxt-hos-sdkdemo"
New-Item -ItemType Directory -Force -Path $stage | Out-Null

$excludeDirNames = New-Object "System.Collections.Generic.HashSet[string]" ([StringComparer]::OrdinalIgnoreCase)
@(
  ".git", "oh_modules", "node_modules", "build", ".hvigor", ".idea", ".cxx",
  "dist", "out", "log", ".preview", ".clangd", "scripts"
) | ForEach-Object { [void]$excludeDirNames.Add($_) }

$excludeFileNames = New-Object "System.Collections.Generic.HashSet[string]" ([StringComparer]::OrdinalIgnoreCase)
@("local.properties", ".DS_Store", "Thumbs.db") | ForEach-Object { [void]$excludeFileNames.Add($_) }

$excludeExt = @(".hap", ".app", ".har", ".hsp", ".iml", ".bat", ".sh", ".ps1")

function Test-ShouldSkip {
  param([string]$FullPath, [string]$RootPath)
  $rel = $FullPath.Substring($RootPath.Length).TrimStart([char]92, [char]47)
  foreach ($p in ($rel -split "[\\/]")) {
    if ($excludeDirNames.Contains($p)) { return $true }
  }
  $name = Split-Path $FullPath -Leaf
  if ($excludeFileNames.Contains($name)) { return $true }
  $ext = [IO.Path]::GetExtension($name).ToLowerInvariant()
  if ($excludeExt -contains $ext) { return $true }
  if ($name -like "_pack_stage_*") { return $true }
  if ($name -like "yxt-hos-sdkdemo-*.zip") { return $true }
  return $false
}

# Clear app.signingConfigs array body to [] via brace matching.
# Does NOT touch products[*].signingConfig. Preserves comments, indent, key order, EOL, encoding.
function Clear-SigningConfigsArray {
  param([string]$Text)
  $m = [regex]::Match($Text, '"signingConfigs"\s*:\s*\[')
  if (-not $m.Success) {
    Write-Warning "signingConfigs array not found; leaving build-profile.json5 unchanged"
    return $Text
  }
  $startBracket = $m.Index + $m.Length - 1
  $depth = 0
  $inString = $false
  $escape = $false
  $end = -1
  for ($i = $startBracket; $i -lt $Text.Length; $i++) {
    $c = $Text[$i]
    if ($inString) {
      if ($escape) { $escape = $false; continue }
      if ($c -eq [char]92) { $escape = $true; continue } # backslash
      if ($c -eq [char]34) { $inString = $false } # quote
      continue
    }
    if ($c -eq [char]34) { $inString = $true; continue }
    if ($c -eq [char]91) { $depth++ } # [
    elseif ($c -eq [char]93) { # ]
      $depth--
      if ($depth -eq 0) { $end = $i; break }
    }
  }
  if ($end -lt 0) {
    throw "Unbalanced signingConfigs array in build-profile.json5"
  }
  return $Text.Substring(0, $startBracket) + "[]" + $Text.Substring($end + 1)
}

$files = Get-ChildItem -LiteralPath $Root -Recurse -Force -File |
  Where-Object { -not (Test-ShouldSkip -FullPath $_.FullName -RootPath $Root) }

$copied = 0
foreach ($f in $files) {
  $rel = $f.FullName.Substring($Root.Length).TrimStart([char]92, [char]47)
  $dest = Join-Path $stage $rel
  $destDir = Split-Path $dest -Parent
  if (-not (Test-Path -LiteralPath $destDir)) {
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
  }
  Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
  $copied++
}
Write-Host "Copied $copied files into staging"

$bp = Join-Path $stage "build-profile.json5"
if (Test-Path -LiteralPath $bp) {
  # Strip signing materials/secrets only; do NOT delete products[*].signingConfig
  # (product -> config name binding must remain, e.g. "signingConfig": "default").
  # Avoid ConvertFrom-Json/ConvertTo-Json: they destroy json5 layout and add UTF-8 BOM.
  $bytes = [System.IO.File]::ReadAllBytes($bp)
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  $hadBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
  $offset = if ($hadBom) { 3 } else { 0 }
  $text = $utf8NoBom.GetString($bytes, $offset, $bytes.Length - $offset)
  $text = Clear-SigningConfigsArray -Text $text
  [System.IO.File]::WriteAllText($bp, $text, $utf8NoBom)
  Write-Host "Sanitized build-profile.json5 (cleared signingConfigs; kept product signingConfig)"
}

New-Item -ItemType Directory -Force -Path $dist | Out-Null
if (Test-Path -LiteralPath $zipPath) {
  Remove-Item -LiteralPath $zipPath -Force
}
Compress-Archive -Path (Join-Path $stageParent "*") -DestinationPath $zipPath -Force
Remove-Item -LiteralPath $stageParent -Recurse -Force

$len = (Get-Item -LiteralPath $zipPath).Length
Write-Host ""
Write-Host "Release zip: $zipPath"
Write-Host ("Size: {0:N1} KB" -f ($len / 1KB))
Write-Host "Users should: ohpm install (oh_modules not bundled)"