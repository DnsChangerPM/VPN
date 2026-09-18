#!/usr/bin/env python3
"""Copy Nimbus platform overlays onto a flutter create scaffold and patch SDK floors."""
from __future__ import annotations

import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OVERLAYS = ROOT / "overlays"


def copy_tree(src: Path, dst: Path) -> None:
    if not src.exists():
        return
    for path in src.rglob("*"):
        if path.is_dir():
            continue
        rel = path.relative_to(src)
        target = dst / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
        print("copied", rel)


def patch_android_gradle() -> None:
    gradle = ROOT / "android" / "app" / "build.gradle.kts"
    groovy = ROOT / "android" / "app" / "build.gradle"
    path = gradle if gradle.exists() else groovy
    if not path.exists():
        print("android gradle missing")
        return
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"minSdk\s*=\s*.+", "minSdk = 24", text)
    text = re.sub(r"minSdkVersion\s+.+", "minSdkVersion 24", text)
    text = re.sub(r"targetSdk\s*=\s*.+", "targetSdk = 35", text)
    text = re.sub(r"targetSdkVersion\s+.+", "targetSdkVersion 35", text)
    if "ndk" not in text:
        text = text.replace(
            "defaultConfig {",
            """defaultConfig {
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }""",
            1,
        ) if path.suffix == ".kts" else text.replace(
            "defaultConfig {",
            """defaultConfig {
        ndk { abiFilters "armeabi-v7a", "arm64-v8a", "x86_64" }""",
            1,
        )
    signing = '''
    val store = System.getenv("ANDROID_KEYSTORE_PATH")
    if (!store.isNullOrBlank()) {
        signingConfigs {
            create("release") {
                storeFile = file(store)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD") ?: ""
                keyAlias = System.getenv("ANDROID_KEY_ALIAS") ?: "nimbus"
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD") ?: ""
            }
        }
    }
'''
    if "ANDROID_KEYSTORE_PATH" not in text and path.suffix == ".kts":
        text = text.replace("buildTypes {", signing + "\n    buildTypes {", 1)
        text = text.replace(
            "isMinifyEnabled = false",
            """isMinifyEnabled = false
            signingConfig = if (signingConfigs.findByName("release") != null)
                signingConfigs.getByName("release") else signingConfigs.getByName("debug")""",
            1,
        )
    path.write_text(text, encoding="utf-8")
    print("patched", path.relative_to(ROOT))

    manifest = ROOT / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    if manifest.exists():
        # overlay already copied
        pass

    props = ROOT / "android" / "gradle.properties"
    if props.exists():
        p = props.read_text(encoding="utf-8")
        if "android.bundle.enableUncompressedNativeLibs" not in p:
            props.write_text(
                p + "\nandroid.bundle.enableUncompressedNativeLibs=false\n",
                encoding="utf-8",
            )


def patch_windows() -> None:
    main_cpp = ROOT / "windows" / "runner" / "main.cpp"
    if main_cpp.exists():
        t = main_cpp.read_text(encoding="utf-8")
        t = t.replace("Win32Window::Size size(1280, 720);", "Win32Window::Size size(420, 780);")
        t = t.replace("Win32Window::Size size(1280, 720)", "Win32Window::Size size(420, 780)")
        main_cpp.write_text(t, encoding="utf-8")
        print("patched window size")

    manifest = ROOT / "windows" / "runner" / "runner.exe.manifest"
    if manifest.exists():
        t = manifest.read_text(encoding="utf-8")
        if "1f676c76-80e1-4239-95bb-83d0f6d0da78" not in t:
            t = t.replace(
                "</application>",
                """  <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1">
    <application>
      <supportedOS Id="{1f676c76-80e1-4239-95bb-83d0f6d0da78}"/>
      <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/>
      <supportedOS Id="{35138b9a-5d96-4fbd-8e2d-a2440225f93a}"/>
    </application>
  </compatibility>
</application>""",
                1,
            )
        manifest.write_text(t, encoding="utf-8")

    cmake = ROOT / "windows" / "CMakeLists.txt"
    if cmake.exists():
        t = cmake.read_text(encoding="utf-8")
        if "WINVER=0x0603" not in t:
            t = t.replace(
                "cmake_minimum_required",
                "add_definitions(-DWINVER=0x0603 -D_WIN32_WINNT=0x0603)\ncmake_minimum_required",
                1,
            )
        extra = """
file(GLOB NIMBUS_SIDECARS "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/windows/*")
if(NIMBUS_SIDECARS)
  install(FILES ${NIMBUS_SIDECARS} DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime)
endif()
"""
        if "NIMBUS_SIDECARS" not in t:
            t += "\n" + extra
        cmake.write_text(t, encoding="utf-8")
        print("patched windows CMakeLists")

    ico_src = ROOT / "assets" / "branding" / "icon.ico"
    ico_dst = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    if ico_src.exists() and ico_dst.parent.exists():
        shutil.copy2(ico_src, ico_dst)
        print("copied app_icon.ico")


def main() -> None:
    copy_tree(OVERLAYS / "android", ROOT / "android")
    copy_tree(OVERLAYS / "windows", ROOT / "windows")
    patch_android_gradle()
    patch_windows()
    print("overlays applied")


if __name__ == "__main__":
    main()
