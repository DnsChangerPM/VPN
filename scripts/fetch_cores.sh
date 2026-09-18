#!/usr/bin/env bash
# Download pinned Aether, HEV, tun2socks and Wintun binaries.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AETHER_TAG="${AETHER_TAG:-v2.0.0}"
HEV_TAG="${HEV_TAG:-2.17.1}"
TUN2SOCKS_TAG="${TUN2SOCKS_TAG:-v2.6.0}"
WINTUN_URL="${WINTUN_URL:-https://www.wintun.net/builds/wintun-0.14.1.zip}"

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
  download "https://github.com/CluvexStudio/Aether/releases/download/${AETHER_TAG}/${asset}.sha256" "$tmp/$asset.sha256" || true
  if [[ -f "$tmp/$asset.sha256" ]]; then
    (cd "$tmp" && sha256sum -c "$asset.sha256")
  fi
  tar -xzf "$tmp/$asset" -C "$tmp"
  local bin
  bin="$(find "$tmp" -type f -name 'aether' | head -n1)"
  cp "$bin" "$ROOT/android/app/src/main/jniLibs/$jni/libaether.so"
  chmod 755 "$ROOT/android/app/src/main/jniLibs/$jni/libaether.so"
}

stage_aether_windows() {
  local tmp="$ROOT/third_party/aether-win"
  mkdir -p "$tmp"
  download "https://github.com/CluvexStudio/Aether/releases/download/${AETHER_TAG}/aether-windows-x86_64.zip" "$tmp/aether-windows-x86_64.zip"
  download "https://github.com/CluvexStudio/Aether/releases/download/${AETHER_TAG}/aether-windows-x86_64.zip.sha256" "$tmp/aether-windows-x86_64.zip.sha256" || true
  if [[ -f "$tmp/aether-windows-x86_64.zip.sha256" ]]; then
    (cd "$tmp" && sha256sum -c aether-windows-x86_64.zip.sha256 || true)
  fi
  python3 - "$tmp" <<'PY'
import zipfile, sys
from pathlib import Path
z = Path(sys.argv[1]) / "aether-windows-x86_64.zip"
with zipfile.ZipFile(z) as f:
    f.extractall(z.parent)
PY
  find "$tmp" -name 'aether.exe' -exec cp {} "$ROOT/third_party/windows/aether.exe" \;
}

stage_tun2socks() {
  local tmp="$ROOT/third_party/tun2socks"
  mkdir -p "$tmp" "$ROOT/third_party/windows"
  python3 - "$tmp" "$ROOT/third_party/windows" <<'PY'
import json, shutil, sys, urllib.request, zipfile
from pathlib import Path
src, dest = Path(sys.argv[1]), Path(sys.argv[2])
req = urllib.request.Request(
    "https://api.github.com/repos/xjasonlyu/tun2socks/releases/latest",
    headers={"User-Agent": "NimbusVPN", "Accept": "application/vnd.github+json"},
)
with urllib.request.urlopen(req, timeout=60) as r:
    rel = json.load(r)
url = None
for a in rel.get("assets", []):
    name = a["name"].lower()
    if "windows" in name and ("amd64" in name or "x64" in name or "x86_64" in name):
        url = a["browser_download_url"]
        break
if not url:
    raise SystemExit("no tun2socks windows asset")
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
  mkdir -p "$tmp"
  download "$WINTUN_URL" "$tmp/wintun.zip"
  python3 - "$tmp" "$ROOT/third_party/windows" <<'PY'
import zipfile, shutil, sys
from pathlib import Path
src, dest = Path(sys.argv[1]), Path(sys.argv[2])
with zipfile.ZipFile(src / "wintun.zip") as z:
    z.extractall(src)
dll = next(p for p in src.rglob("wintun.dll") if "amd64" in str(p).lower() or "x64" in str(p).lower() or "bin" in str(p).lower())
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
