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
APP_CSPROJ = SRC_DIR / "Hangly.App" / "Hangly.App.csproj"
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


def clean_artifacts():
    """Cleans build and obj/bin directories."""
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
        "Hangly.exe",
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

    print(f"[builder] Payload verified successfully!")
    print(f"  - Main executable: {output_dir / 'Hangly.exe'}")
    print(f"  - Verified {len(svg_files)} SVG charm assets")
    print(f"  - Verified WinUI, Win2D, SkiaSharp, and PRI resource map")
    return True


def publish_target(dotnet_exe: Path, arch: str, config: str) -> bool:
    """Publishes a self-contained executable for the given architecture."""
    if arch not in TARGET_MAP:
        print(f"[builder] Error: Unsupported architecture '{arch}'. Supported: {list(TARGET_MAP.keys())}")
        return False

    target_info = TARGET_MAP[arch]
    rid = target_info["rid"]
    platform_name = target_info["platform"]
    output_dir = BUILD_DIR / rid

    print(f"\n[builder] Publishing target: {rid} ({platform_name}) [{config}] -> {output_dir}")
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
        str(output_dir),
    ]

    code = run_command(cmd, env)
    if code != 0:
        print(f"[builder] Publish for {rid} FAILED with exit code {code}")
        return False

    return verify_payload(output_dir)


def main():
    parser = argparse.ArgumentParser(description="Automated build and packaging tool for Hangly.")
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
        default="x64",
        help="Target architecture (default: x64)",
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

    # Determine default action if none specified
    if not (args.clean or args.test or args.publish or args.all):
        args.test = True
        args.publish = True

    if args.clean:
        clean_artifacts()

    dotnet_exe = find_dotnet_sdk()

    success = True
    if args.test:
        test_ok = run_tests(dotnet_exe, args.configuration)
        if not test_ok:
            sys.exit(1)

    if args.all:
        for arch in ["x64", "arm64"]:
            ok = publish_target(dotnet_exe, arch, args.configuration)
            if not ok:
                success = False
    elif args.publish:
        ok = publish_target(dotnet_exe, args.arch, args.configuration)
        if not ok:
            success = False

    if not success:
        print("\n[builder] One or more publish steps FAILED.")
        sys.exit(1)

    print("\n[builder] All tasks completed successfully.")
    sys.exit(0)


if __name__ == "__main__":
    main()
