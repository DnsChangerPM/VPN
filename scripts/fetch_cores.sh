#!/usr/bin/env bash
# Download pinned Aether, HEV, tun2socks and Wintun binaries.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-${TARGET:-all}}"
TARGET="$(echo "$TARGET" | tr '[:upper:]' '[:lower:]')"
AETHER_TAG="${AETHER_TAG:-v2.0.0}"
HEV_TAG="${HEV_TAG:-2.17.1}"
TUN2SOCKS_TAG="${TUN2SOCKS_TAG:-v2.6.0}"
WINTUN_URL="${WINTUN_URL:-https://www.wintun.net/builds/wintun-0.14.1.zip}"

if command -v python3 >/dev/null 2>&1; then
  PYTHON="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON="python"
else
  echo "Error: Neither python3 nor python found" >&2
  exit 1
fi

mkdir -p "$ROOT/third_party/windows" "$ROOT/android/app/src/main/jniLibs"

sha_ok() {
  local file="$1" expected="$2"
  if [[ -z "$expected" ]]; then return 0; fi
  local got
  got="$(sha256sum "$file" | awk '{print $1}')"
  [[ "$got" == "$expected" ]]
}

download() {
  local url="$1" dest="$2"
  echo ">> $url"
  curl -fsSL --retry 5 -o "$dest" "$url"
}

stage_aether_android() {
  local abi="$1" asset="$2" jni="$3"
  local tmp="$ROOT/third_party/aether-$abi"
  mkdir -p "$tmp" "$ROOT/android/app/src/main/jniLibs/$jni"
  download "https://github.com/CluvexStudio/Aether/releases/download/${AETHER_TAG}/${asset}" "$tmp/$asset"
  download "https://github.com/CluvexStudio/Aether/releases/download/${AETHER_TAG}/${asset}.sha256" "$tmp/$asset.sha256"
  # A failed or skipped checksum used to pass silently and shipped a corrupt
  # (or truncated) core — the app then "connected" to nothing. Hard fail.
  (cd "$tmp" && sha256sum -c "$asset.sha256")
  tar -xzf "$tmp/$asset" -C "$tmp"
  local bin
  bin="$(find "$tmp" -type f -name 'aether' | head -n1)"
  if [[ -z "$bin" || ! -f "$bin" ]]; then
    echo "Error: no 'aether' executable inside $asset" >&2
    tar -tzf "$tmp/$asset" >&2 || true
    exit 1
  fi
  cp "$bin" "$ROOT/android/app/src/main/jniLibs/$jni/libaether.so"
  chmod 755 "$ROOT/android/app/src/main/jniLibs/$jni/libaether.so"
  # Sanity: the staged payload must really be an ELF executable, otherwise
  # ProcessBuilder fails at runtime on the device.
  if ! head -c 4 "$ROOT/android/app/src/main/jniLibs/$jni/libaether.so" | grep -q $'\x7fELF'; then
    echo "Error: $asset did not contain an ELF binary" >&2
    exit 1
  fi
  echo "staged $jni/libaether.so ($(du -h "$ROOT/android/app/src/main/jniLibs/$jni/libaether.so" | cut -f1))"
}

stage_aether_windows() {
  local tmp="$ROOT/third_party/aether-win"
  mkdir -p "$tmp"
  download "https://github.com/CluvexStudio/Aether/releases/download/${AETHER_TAG}/aether-windows-x86_64.zip" "$tmp/aether-windows-x86_64.zip"
  download "https://github.com/CluvexStudio/Aether/releases/download/${AETHER_TAG}/aether-windows-x86_64.zip.sha256" "$tmp/aether-windows-x86_64.zip.sha256"
  (cd "$tmp" && sha256sum -c aether-windows-x86_64.zip.sha256)
  "$PYTHON" - "$tmp" <<'PY'
import zipfile, sys
from pathlib import Path
z = Path(sys.argv[1]) / "aether-windows-x86_64.zip"
with zipfile.ZipFile(z) as f:
    f.extractall(z.parent)
PY
  find "$tmp" -name 'aether.exe' -exec cp {} "$ROOT/third_party/windows/aether.exe" \;
  if [[ ! -s "$ROOT/third_party/windows/aether.exe" ]]; then
    echo "Error: aether.exe missing after extraction" >&2
    exit 1
  fi
}

stage_tun2socks() {
  local tmp="$ROOT/third_party/tun2socks"
  mkdir -p "$tmp" "$ROOT/third_party/windows"
  export TUN2SOCKS_TAG
  "$PYTHON" - "$tmp" "$ROOT/third_party/windows" <<'PY'
import json, os, shutil, sys, urllib.request, zipfile
from pathlib import Path
src, dest = Path(sys.argv[1]), Path(sys.argv[2])
headers = {"User-Agent": "NimbusVPN", "Accept": "application/vnd.github+json"}
token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
if token:
    headers["Authorization"] = f"Bearer {token}"

url = None
try:
    req = urllib.request.Request(
        "https://api.github.com/repos/xjasonlyu/tun2socks/releases/latest",
        headers=headers,
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        rel = json.load(r)
    for a in rel.get("assets", []):
        name = a["name"].lower()
        if "windows" in name and ("amd64" in name or "x64" in name or "x86_64" in name):
            url = a["browser_download_url"]
            break
except Exception as e:
    print(f"Warning: Failed to fetch latest tun2socks release info from API: {e}")
    url = None

if not url:
    tag = os.environ.get("TUN2SOCKS_TAG", "v2.6.0")
    url = f"https://github.com/xjasonlyu/tun2socks/releases/download/{tag}/tun2socks-windows-amd64.zip"
    print(f"Falling back to pinned release: {url}")

print(">>", url)
out = src / Path(url).name
with urllib.request.urlopen(url, timeout=120) as r:
    out.write_bytes(r.read())
if out.suffix == ".zip":
    with zipfile.ZipFile(out) as z:
        z.extractall(src)
    exe = next(src.rglob("*.exe"))
    shutil.copy2(exe, dest / "tun2socks.exe")
else:
    shutil.copy2(out, dest / "tun2socks.exe")
PY
}

stage_wintun() {
  local tmp="$ROOT/third_party/wintun"
  mkdir -p "$tmp" "$ROOT/third_party/windows"
  download "$WINTUN_URL" "$tmp/wintun.zip"
  "$PYTHON" - "$tmp" "$ROOT/third_party/windows" <<'PY'
import zipfile, shutil, sys
from pathlib import Path
src, dest = Path(sys.argv[1]), Path(sys.argv[2])
with zipfile.ZipFile(src / "wintun.zip") as z:
    z.extractall(src)
dll = next((p for p in src.rglob("wintun.dll") if "amd64" in str(p).lower() or "x64" in str(p).lower()), None)
if not dll:
    dll = next(src.rglob("wintun.dll"))
shutil.copy2(dll, dest / "wintun.dll")
PY
}

echo "Fetching Aether ${AETHER_TAG} ($TARGET)"
if [[ "$TARGET" == "all" || "$TARGET" == "android" ]]; then
  stage_aether_android arm64 aether-android-arm64.tar.gz arm64-v8a
  stage_aether_android armv7 aether-android-armv7.tar.gz armeabi-v7a
  stage_aether_android x64 aether-android-x86_64.tar.gz x86_64
fi
if [[ "$TARGET" == "all" || "$TARGET" == "windows" ]]; then
  stage_aether_windows
  stage_tun2socks
  stage_wintun
fi
echo "cores staged"
