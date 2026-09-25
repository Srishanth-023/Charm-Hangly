#!/usr/bin/env python3
"""
builder.py - Automated build, test, and release packaging tool for Hangly.

Features:
  - Auto-detects .NET 9 SDK (checks %LOCALAPPDATA%\\Microsoft\\dotnet and system PATH)
  - Supports unit testing (Hangly.Core.Tests)
  - Supports self-contained publishing for win-x64 and win-arm64
  - Verifies payload integrity (WinUI, Win2D, Skia, PRI, SVG charm assets)
  - Supports cleaning build and output directories
"""

import argparse
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

# Paths
REPO_ROOT = Path(__file__).resolve().parent
SRC_DIR = REPO_ROOT / "src"
TESTS_DIR = REPO_ROOT / "tests"
BUILD_DIR = REPO_ROOT / "build"
MOBILE_DIR = SRC_DIR / "mobile"
MOBILE_BUILD_DIR = BUILD_DIR / "mobile"
APP_CSPROJ = SRC_DIR / "desktop" / "Hangly.App" / "Hangly.App.csproj"
TEST_CSPROJ = TESTS_DIR / "Hangly.Core.Tests" / "Hangly.Core.Tests.csproj"

TARGET_MAP = {
    "x64": {"rid": "win-x64", "platform": "x64"},
    "arm64": {"rid": "win-arm64", "platform": "ARM64"},
}


def find_dotnet_sdk():
    """
    Locates a dotnet executable backed by a .NET 9 SDK.
    Checks user local appdata first, then system path and standard locations.
    """
    candidates = []

    # 1. Local AppData user installation
    local_appdata = os.environ.get("LOCALAPPDATA")
    if local_appdata:
        candidates.append(Path(local_appdata) / "Microsoft" / "dotnet" / "dotnet.exe")

    # 2. DOTNET_ROOT if set
    dotnet_root = os.environ.get("DOTNET_ROOT")
    if dotnet_root:
        candidates.append(Path(dotnet_root) / "dotnet.exe")

    # 3. PATH
    path_dotnet = shutil.which("dotnet")
    if path_dotnet:
        candidates.append(Path(path_dotnet))

    # 4. Standard Program Files
    prog_files = os.environ.get("ProgramFiles")
    if prog_files:
        candidates.append(Path(prog_files) / "dotnet" / "dotnet.exe")

    for candidate in candidates:
        if candidate.is_file():
            # Check if this dotnet host has .NET 9 SDK
            try:
                result = subprocess.run(
                    [str(candidate), "--list-sdks"],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                if result.returncode == 0:
                    for line in result.stdout.splitlines():
                        if line.strip().startswith("9."):
                            valid_dotnet = candidate.resolve()
                            print(f"[builder] Found .NET 9 SDK at: {valid_dotnet} ({line.strip()})")
                            return valid_dotnet
            except Exception:
                continue

    # Fallback to any available dotnet
    for candidate in candidates:
        if candidate.is_file():
            print(f"[builder] Warning: .NET 9 SDK not confirmed, falling back to: {candidate}")
            return candidate.resolve()

    raise RuntimeError(
        "Could not find dotnet executable. Please install .NET 9 SDK or set DOTNET_ROOT."
    )


def get_build_env(dotnet_exe: Path) -> dict:
    """Configures environment so dotnet finds the .NET 9 SDK runtime and tools."""
    env = os.environ.copy()
    dotnet_dir = str(dotnet_exe.parent)

    # Prepend dotnet directory to PATH
    current_path = env.get("PATH", "")
    env["PATH"] = f"{dotnet_dir};{current_path}"
    env["DOTNET_ROOT"] = dotnet_dir
    return env


def run_command(cmd: list[str], env: dict, cwd: Path = REPO_ROOT) -> int:
    """Runs a subprocess command with real-time output streaming."""
    cmd_str = " ".join(cmd)
    print(f"\n[builder] Executing: {cmd_str}")
    proc = subprocess.run(cmd, cwd=str(cwd), env=env)
    return proc.returncode


def kill_running_instances():
    """Kills any running instances of Hangly to avoid DLL file locks during compilation or publishing."""
    if platform.system() == "Windows":
        try:
            subprocess.run(
                ["taskkill", "/F", "/IM", "Charm Hangly.exe"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
        except Exception:
            pass


def clean_artifacts():
    """Cleans build and obj/bin directories."""
    kill_running_instances()
    print("[builder] Cleaning artifacts...")
    dirs_to_remove = [BUILD_DIR]
    for pattern in ["**/bin", "**/obj"]:
        for p in SRC_DIR.glob(pattern):
            dirs_to_remove.append(p)
        for p in TESTS_DIR.glob(pattern):
            dirs_to_remove.append(p)

    for d in dirs_to_remove:
        if d.is_dir():
            print(f"[builder] Removing: {d}")
            shutil.rmtree(d, ignore_errors=True)
    print("[builder] Clean complete.")


def run_tests(dotnet_exe: Path, config: str) -> bool:
    """Runs the test suite."""
    print(f"\n[builder] Running tests with configuration '{config}'...")
    if not TEST_CSPROJ.is_file():
        print(f"[builder] Error: Test project not found at {TEST_CSPROJ}")
        return False

    env = get_build_env(dotnet_exe)
    cmd = [
        str(dotnet_exe),
        "test",
        str(TEST_CSPROJ),
        "-c",
        config,
        "--logger",
        "console;verbosity=normal",
    ]
    code = run_command(cmd, env)
    if code != 0:
        print(f"[builder] Tests FAILED with exit code {code}")
        return False
    print("[builder] Tests PASSED successfully.")
    return True


def verify_payload(output_dir: Path) -> bool:
    """Verifies that all required assemblies, PRIs, and assets are present."""
    print(f"\n[builder] Verifying published payload in: {output_dir}")
    if not output_dir.is_dir():
        print(f"[builder] Error: Output directory does not exist: {output_dir}")
        return False

    required_files = [
        "Charm Hangly.exe",
        "Hangly.Core.dll",
        "Microsoft.ui.xaml.dll",
        "Microsoft.WindowsAppRuntime.Bootstrap.dll",
    ]

    missing = []
    for req in required_files:
        matches = list(output_dir.rglob(req))
        if not matches:
            missing.append(req)

    # Skia native DLL
    skia_matches = list(output_dir.rglob("*SkiaSharp*.dll"))
    if not skia_matches:
        missing.append("libSkiaSharp (native DLL)")

    # Win2D Canvas DLL
    win2d_matches = list(output_dir.rglob("Microsoft.Graphics.Canvas*"))
    if not win2d_matches:
        missing.append("Win2D (Microsoft.Graphics.Canvas)")

    # Check for app PRI file
    pri_matches = [
        p.name for p in output_dir.rglob("*.pri")
        if p.name.startswith("resources") or p.name.startswith("Hangly")
    ]
    if not pri_matches:
        missing.append("Application PRI file (compiled XAML resources)")

    # Check for SVG charm assets (expected >= 71)
    svg_files = list(output_dir.rglob("*.svg"))
    if len(svg_files) < 71:
        missing.append(f"Charm SVG artwork (expected >= 71, found {len(svg_files)})")

    if missing:
        print("[builder] FAILED payload verification! Missing components:")
        for m in missing:
            print(f"  - {m}")
        return False

    main_exe = output_dir / "Portable" / "Charm Hangly.exe"
    if not main_exe.is_file():
        main_exe = output_dir / "Charm Hangly.exe"

    print(f"[builder] Payload verified successfully!")
    setup_candidates = list(output_dir.glob("*Setup*.exe"))
    if setup_candidates:
        print(f"  - Desktop Installer: {setup_candidates[0]}")
    zip_candidates = list(output_dir.glob("*Portable*.zip"))
    if zip_candidates:
        print(f"  - Portable Archive: {zip_candidates[0]}")
    print(f"  - Verified {len(svg_files)} SVG charm assets")
    print(f"  - Verified WinUI, Win2D, SkiaSharp, and PRI resource map")
    return True


def find_vpk_tool() -> Path | None:
    """Finds the Velopack (vpk) packaging CLI."""
    user_tools = Path(os.environ.get("USERPROFILE", "")) / ".dotnet" / "tools" / "vpk.exe"
    if user_tools.is_file():
        return user_tools
    p = shutil.which("vpk")
    if p:
        return Path(p)
    return None


def publish_target(dotnet_exe: Path, arch: str, config: str, version: str) -> bool:
    """Publishes a self-contained executable and installer for the given architecture."""
    if arch not in TARGET_MAP:
        print(f"[builder] Error: Unsupported architecture '{arch}'. Supported: {list(TARGET_MAP.keys())}")
        return False

    target_info = TARGET_MAP[arch]
    rid = target_info["rid"]
    platform_name = target_info["platform"]
    output_dir = BUILD_DIR / rid

    kill_running_instances()

    # Clean existing target output
    if output_dir.is_dir():
        shutil.rmtree(output_dir, ignore_errors=True)

    portable_dir = output_dir / "Portable"
    packages_dir = output_dir / "Packages"
    portable_dir.mkdir(parents=True, exist_ok=True)
    packages_dir.mkdir(parents=True, exist_ok=True)

    print(f"\n[builder] Publishing target: {rid} ({platform_name}) [{config}] -> {portable_dir}")
    env = get_build_env(dotnet_exe)

    cmd = [
        str(dotnet_exe),
        "publish",
        str(APP_CSPROJ),
        "-c",
        config,
        "-r",
        rid,
        f"-p:Platform={platform_name}",
        "-o",
        str(portable_dir),
    ]

    code = run_command(cmd, env)
    if code != 0:
        print(f"[builder] Publish for {rid} FAILED with exit code {code}")
        return False

    # Remove any leftover .pdb files from the portable release folder
    for pdb in portable_dir.rglob("*.pdb"):
        try:
            pdb.unlink()
        except OSError:
            pass

    # Ensure resources.pri exists (WinUI 3 unpackaged apps expect resources.pri)
    hangly_pri = portable_dir / "Charm Hangly.pri"
    resources_pri = portable_dir / "resources.pri"
    if hangly_pri.is_file() and not resources_pri.is_file():
        shutil.copy2(hangly_pri, resources_pri)
        print(f"[builder] Created resources.pri from Charm Hangly.pri")

    # Build Velopack Desktop Application Installer
    vpk_tool = find_vpk_tool()
    if vpk_tool:
        print(f"\n[builder] Creating Desktop Application Installer using Velopack...")
        vpk_cmd = [
            str(vpk_tool),
            "pack",
            "-u", "CharmHangly",
            "-v", version,
            "--packTitle", "Charm Hangly",
            "--packAuthors", "sharancreatedthis",
            "-p", str(portable_dir),
            "-o", str(packages_dir),
            "-c", rid,
            "-r", rid,
            "-e", "Charm Hangly.exe",
            "--shortcuts", "Desktop,StartMenuRoot",
        ]
        icon_path = SRC_DIR / "Hangly.App" / "Assets" / "hangly.ico"
        if icon_path.is_file():
            vpk_cmd.extend(["-i", str(icon_path)])

        vpk_code = run_command(vpk_cmd, env)
        if vpk_code == 0:
            setup_candidates = list(packages_dir.glob("*Setup.exe"))
            if setup_candidates:
                installer_exe = setup_candidates[0]
                dest_installer = output_dir / f"CharmHangly-Setup-{arch}-v{version}.exe"
                shutil.copy2(installer_exe, dest_installer)
                print(f"[builder] Desktop Application Installer ready: {dest_installer}")
            portable_zip_candidates = list(packages_dir.glob("*Portable.zip"))
            if portable_zip_candidates:
                portable_zip = portable_zip_candidates[0]
                dest_portable_zip = output_dir / f"CharmHangly-Portable-{arch}-v{version}.zip"
                shutil.copy2(portable_zip, dest_portable_zip)
                print(f"[builder] Portable package ready: {dest_portable_zip}")
        else:
            print(f"[builder] Warning: Velopack installer creation returned code {vpk_code}")
    else:
        print("[builder] Warning: vpk tool not found. Installer was not generated.")

    return verify_payload(output_dir)


def collect_github_releases():
    """
    Consolidates all architecture-differentiated release assets into build/github-release/
    with guaranteed unique filenames, ready for direct upload into a GitHub Release.
    """
    dist_dir = BUILD_DIR / "github-release"
    if dist_dir.is_dir():
        shutil.rmtree(dist_dir, ignore_errors=True)
    dist_dir.mkdir(parents=True, exist_ok=True)

    print(f"\n[builder] Consolidating GitHub Release assets -> {dist_dir}")
    count = 0
    for arch in ["x64", "arm64"]:
        target_info = TARGET_MAP[arch]
        rid = target_info["rid"]
        output_dir = BUILD_DIR / rid
        if not output_dir.is_dir():
            continue

        # 1. Desktop Application Installer
        for setup_exe in output_dir.glob(f"CharmHangly-Setup-{arch}-*.exe"):
            shutil.copy2(setup_exe, dist_dir / setup_exe.name)
            count += 1

        # 2. Standalone Portable Zip
        for portable_zip in output_dir.glob(f"CharmHangly-Portable-{arch}-*.zip"):
            shutil.copy2(portable_zip, dist_dir / portable_zip.name)
            count += 1

        # 3. Velopack packages (nupkg, RELEASES, releases.json)
        packages_dir = output_dir / "Packages"
        if packages_dir.is_dir():
            for p in packages_dir.iterdir():
                if p.is_file() and not p.name.endswith(".exe") and not p.name.endswith(".zip"):
                    shutil.copy2(p, dist_dir / p.name)
                    count += 1

    # 4. Mobile APKs & AppBundles
    mobile_dir = BUILD_DIR / "mobile"
    if mobile_dir.is_dir():
        for ext in ["*.apk", "*.aab"]:
            for f in mobile_dir.rglob(ext):
                shutil.copy2(f, dist_dir / f.name)
                count += 1

    print(f"[builder] Collected {count} GitHub Release assets with unique filenames in: {dist_dir}")


def update_desktop_version(version: str):
    """Updates the version number in csproj."""
    import re
    print(f"\n[builder] Updating Windows project files to version {version}...")
    if APP_CSPROJ.is_file():
        content = APP_CSPROJ.read_text(encoding="utf-8")
        content = re.sub(r"<Version>.*?</Version>", f"<Version>{version}</Version>", content)
        content = re.sub(r"<FileVersion>.*?</FileVersion>", f"<FileVersion>{version}</FileVersion>", content)
        content = re.sub(r"<AssemblyVersion>.*?</AssemblyVersion>", f"<AssemblyVersion>{version}</AssemblyVersion>", content)
        APP_CSPROJ.write_text(content, encoding="utf-8")
        print(f"[builder] Updated {APP_CSPROJ.name}")

def update_mobile_version(version: str):
    """Updates the version number in pubspec.yaml."""
    import re
    print(f"\n[builder] Updating Mobile project files to version {version}...")
    pubspec = MOBILE_DIR / "pubspec.yaml"
    if pubspec.is_file():
        content = pubspec.read_text(encoding="utf-8")
        content = re.sub(r"^version:\s*.*", f"version: {version}+1", content, flags=re.MULTILINE)
        pubspec.write_text(content, encoding="utf-8")
        print(f"[builder] Updated pubspec.yaml")


def archive_historical_release(desktop_version: str = None, mobile_version: str = None):
    """Archives the generated build/github-release to a persistent releases/ folder."""
    import datetime
    
    github_release_dir = BUILD_DIR / "github-release"
    if not github_release_dir.is_dir():
        return
        
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    if desktop_version and mobile_version:
        folder_name = f"desktop-v{desktop_version}_mobile-v{mobile_version}_{timestamp}"
    elif desktop_version:
        folder_name = f"desktop-v{desktop_version}_{timestamp}"
    elif mobile_version:
        folder_name = f"mobile-v{mobile_version}_{timestamp}"
    else:
        folder_name = f"build_{timestamp}"
        
    archive_dir = REPO_ROOT / "releases" / folder_name
    
    print(f"\n[builder] Archiving current release to a permanent folder: {archive_dir}")
    shutil.copytree(github_release_dir, archive_dir)


def check_mobile_prerequisites() -> Path:
    """Verifies that Flutter and Dart are installed and available."""
    flutter_bin = shutil.which("flutter")
    if not flutter_bin:
        raise RuntimeError("Flutter SDK not found in PATH. Please install Flutter.")
    dart_bin = shutil.which("dart")
    if not dart_bin:
        raise RuntimeError("Dart SDK not found in PATH.")

    # Check flutter version
    try:
        res = subprocess.run([flutter_bin, "--version"], capture_output=True, text=True, check=False)
        if res.returncode == 0:
            first_line = res.stdout.strip().splitlines()[0] if res.stdout else "Flutter"
            print(f"[builder] Found Flutter SDK: {first_line}")
    except Exception:
        pass

    return Path(flutter_bin)


def run_mobile_tests(flutter_bin: Path) -> bool:
    """Runs the Flutter test suite in mobile/."""
    print("\n[builder] Running Flutter tests in mobile/...")
    if not MOBILE_DIR.is_dir():
        print(f"[builder] Error: Mobile directory not found at {MOBILE_DIR}")
        return False

    proc = subprocess.run([str(flutter_bin), "test"], cwd=str(MOBILE_DIR))
    if proc.returncode == 0:
        print("[builder] Flutter tests passed successfully.")
        return True
    else:
        print("[builder] Error: Flutter tests failed.")
        return False


def build_mobile(flutter_bin: Path, config: str = "Release", version: str = "1.0.0") -> bool:
    """Builds the Flutter Android APK and AppBundle and copies artifacts to build/mobile/."""
    print(f"\n[builder] Building Mobile Flutter Android Application ({config})...")
    if not MOBILE_DIR.is_dir():
        print(f"[builder] Error: Mobile directory not found at {MOBILE_DIR}")
        return False

    apk_out = MOBILE_BUILD_DIR / "apk"
    bundle_out = MOBILE_BUILD_DIR / "bundle"
    apk_out.mkdir(parents=True, exist_ok=True)
    bundle_out.mkdir(parents=True, exist_ok=True)

    is_release = config.lower() == "release"
    mode_flag = "--release" if is_release else "--debug"

    # 1. Build APK
    print(f"[builder] Building Android APK ({mode_flag})...")
    apk_cmd = [str(flutter_bin), "build", "apk", mode_flag]
    apk_proc = subprocess.run(apk_cmd, cwd=str(MOBILE_DIR))
    if apk_proc.returncode != 0:
        print("[builder] Error: Flutter APK build failed.")
        return False

    # Copy generated APK(s) to build/mobile/apk/
    built_apk_dir = MOBILE_DIR / "build" / "app" / "outputs" / "flutter-apk"
    apk_copied = 0
    if built_apk_dir.is_dir():
        for apk_file in built_apk_dir.glob("*.apk"):
            dest_name = apk_file.name.replace(".apk", f"-v{version}.apk")
            if "app" in dest_name:
                dest_name = dest_name.replace("app", "CharmHangly-Mobile")
            dest = apk_out / dest_name
            shutil.copy2(apk_file, dest)
            size_mb = dest.stat().st_size / (1024 * 1024)
            print(f"[builder] Produced APK artifact: {dest} ({size_mb:.2f} MB)")
            apk_copied += 1

    if apk_copied == 0:
        print("[builder] Warning: No APK output file found to copy.")

    # 2. Build AppBundle (for Play Store release) if Release
    if is_release:
        print("\n[builder] Building Android AppBundle (--release)...")
        aab_cmd = [str(flutter_bin), "build", "appbundle", "--release"]
        aab_proc = subprocess.run(aab_cmd, cwd=str(MOBILE_DIR))
        if aab_proc.returncode == 0:
            built_bundle_dir = MOBILE_DIR / "build" / "app" / "outputs" / "bundle" / "release"
            if built_bundle_dir.is_dir():
                for aab_file in built_bundle_dir.glob("*.aab"):
                    dest_name = aab_file.name.replace(".aab", f"-v{version}.aab")
                    if "app" in dest_name:
                        dest_name = dest_name.replace("app", "CharmHangly-Mobile")
                    dest = bundle_out / dest_name
                    shutil.copy2(aab_file, dest)
                    size_mb = dest.stat().st_size / (1024 * 1024)
                    print(f"[builder] Produced AppBundle artifact: {dest} ({size_mb:.2f} MB)")
        else:
            print("[builder] Warning: AppBundle build failed or was skipped.")

    print(f"\n[builder] Mobile artifacts successfully staged in: {MOBILE_BUILD_DIR}")
    return apk_copied > 0


def prompt_target_interactive() -> str:
    """Interactively prompts the user to select what target to build."""
    print("=" * 60)
    print(" Hangly Build Target Selection")
    print("=" * 60)
    print(" Choose what to build:")
    print("   1) mobile - Build Android Flutter App (APK & App Bundle)")
    print("   2) x64    - Build Windows x64 Distribution & Tests")
    print("   3) arm64  - Build Windows ARM64 Distribution & Tests")
    print("   4) all    - Build ALL applications (Mobile, x64, arm64)")
    print("=" * 60)

    while True:
        try:
            choice = input("Select target [1/2/3/4 or mobile/x64/arm64/all, or 'q' to quit]: ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            print("\n[builder] Build cancelled by user.")
            sys.exit(0)

        if choice in ["1", "mobile"]:
            print("[builder] Selected target: mobile (Android Flutter)")
            return "mobile"
        elif choice in ["2", "x64"]:
            print("[builder] Selected target: x64 (Windows x64)")
            return "x64"
        elif choice in ["3", "arm64"]:
            print("[builder] Selected target: arm64 (Windows ARM64)")
            return "arm64"
        elif choice in ["4", "all"]:
            print("[builder] Selected target: all (Mobile + Windows x64 & arm64)")
            return "all"
        elif choice in ["q", "quit", "exit"]:
            print("[builder] Build cancelled by user.")
            sys.exit(0)
        else:
            print(f"[builder] Invalid choice '{choice}'. Please enter 1, 2, 3, 4, mobile, x64, arm64, all, or q.")


def main():
    parser = argparse.ArgumentParser(description="Automated build and packaging tool for Hangly.")
    parser.add_argument(
        "--target",
        "-t",
        choices=["mobile", "x64", "arm64", "all"],
        default=None,
        help="Target platform to build: mobile, x64, arm64, or all",
    )
    parser.add_argument(
        "--mobile",
        action="store_true",
        help="Build Flutter mobile Android application",
    )
    parser.add_argument(
        "--configuration",
        "-c",
        choices=["Debug", "Release"],
        default="Release",
        help="Build configuration (default: Release)",
    )
    parser.add_argument(
        "--arch",
        "-a",
        choices=["x64", "arm64"],
        default=None,
        help="Target architecture for Windows (default: x64)",
    )
    parser.add_argument("--clean", action="store_true", help="Clean build and bin/obj directories")
    parser.add_argument("--test", action="store_true", help="Run unit test suite")
    parser.add_argument("--publish", action="store_true", help="Publish self-contained distribution")
    parser.add_argument(
        "--all",
        action="store_true",
        help="Publish both x64 and arm64 self-contained distributions",
    )

    args = parser.parse_args()

    # Determine target: CLI flag vs interactive prompt
    selected_target = args.target
    if args.mobile:
        selected_target = "mobile"
    elif args.all:
        selected_target = "all"
    elif args.arch:
        selected_target = args.arch

    # If no target specified, prompt the user
    desktop_version = "1.0.0"
    mobile_version = "1.0.0"
    
    if selected_target is None and not (args.clean and not (args.test or args.publish)):
        selected_target = prompt_target_interactive()
        print("=" * 60)
        
        if selected_target in ["all", "x64", "arm64"]:
            v = input("Enter new DESKTOP version number (e.g. 1.2.0) or press Enter to skip: ").strip()
            if v:
                desktop_version = v
                update_desktop_version(desktop_version)
                
        if selected_target in ["all", "mobile"]:
            v = input("Enter new MOBILE version number (e.g. 1.2.0) or press Enter to skip: ").strip()
            if v:
                mobile_version = v
                update_mobile_version(mobile_version)
                
    elif selected_target is None:
        # Default fallback for automated non-interactive runs
        selected_target = "x64"

    # Determine default actions if none explicitly specified
    if not (args.clean or args.test or args.publish):
        args.test = True
        args.publish = True

    if args.clean:
        clean_artifacts()

    # Execute Mobile target
    if selected_target in ["mobile", "all"]:
        flutter_bin = check_mobile_prerequisites()
        if args.test:
            if not run_mobile_tests(flutter_bin):
                sys.exit(1)
        if args.publish:
            if not build_mobile(flutter_bin, args.configuration, mobile_version):
                sys.exit(1)
        print("\n[builder] Mobile target completed successfully.")
        if selected_target == "mobile":
            sys.exit(0)

    # Execute Windows targets
    dotnet_exe = find_dotnet_sdk()

    success = True
    if args.test:
        test_ok = run_tests(dotnet_exe, args.configuration)
        if not test_ok:
            sys.exit(1)

    if selected_target == "all":
        for arch in ["x64", "arm64"]:
            ok = publish_target(dotnet_exe, arch, args.configuration, desktop_version)
            if not ok:
                success = False
    elif args.publish:
        target_arch = selected_target if selected_target in ["x64", "arm64"] else "x64"
        ok = publish_target(dotnet_exe, target_arch, args.configuration, desktop_version)
        if not ok:
            success = False

    if not success:
        print("\n[builder] One or more publish steps FAILED.")
        sys.exit(1)

    if selected_target == "all" or args.publish:
        collect_github_releases()
        archive_historical_release(
            desktop_version if desktop_version != "1.0.0" else None,
            mobile_version if mobile_version != "1.0.0" else None
        )

    print("\n[builder] All tasks completed successfully.")
    sys.exit(0)


if __name__ == "__main__":
    main()
