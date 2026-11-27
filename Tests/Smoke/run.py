#!/usr/bin/env python3
"""Run application smoke tests in a staged Atlantis host and disposable profile."""

import argparse
import json
import plistlib
import re
import subprocess
import uuid
from pathlib import Path


EXCLUDED_TESTS = {
    "AtlantisProfileTests/testDefaultPathsAndPreferencesWithoutFlag": "requires the normal launch mode",
    "AtlantisNotificationsTests/testLiveWorldEventNotificationDeliveryAndClick": "uses macOS notification delivery",
    "AtlantisPreferenceControllerTests/testResizedWindowKeepsItsFrameAcrossPaneSwitchesAndReopening": "uses saved window frames",
    "RDAtlantisSpawnTests/testBackgroundSpawnActivityUpdatesApplicationDockBadge": "uses the macOS Dock",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("xctestrun", type=Path, help="Test configuration from build-for-testing")
    parser.add_argument("output", type=Path, help="New artifact directory outside the checkout")
    parser.add_argument("--build-log", required=True, type=Path, help="Log from build-for-testing")
    parser.add_argument("--revision", required=True, help="Git revision of the app sources under test")
    args = parser.parse_args()

    config = args.xctestrun.resolve()
    output = args.output.resolve()
    checkout = Path(__file__).resolve().parents[2]
    if output == checkout or checkout in output.parents:
        parser.error("output must be outside the checkout")
    settings = plistlib.loads(config.read_bytes())
    target = settings["AtlantisTests"]
    expected_host = "__TESTROOT__/Debug/Atlantis.app"
    if target["TestHostPath"] != expected_host:
        parser.error(f"expected the Debug test host at {expected_host}")
    build_log = args.build_log.read_text(errors="replace")
    xcode_version = subprocess.check_output(["xcodebuild", "-version"], text=True).strip()

    output.mkdir()
    subprocess.run(["ditto", config.parent / "Debug", output / "Debug"], check=True)
    host_info = output / "Debug/Atlantis.app/Contents/Info.plist"
    plist = plistlib.loads(host_info.read_bytes())
    executable = host_info.parent / "MacOS" / plist["CFBundleExecutable"]
    architectures = subprocess.check_output(["lipo", "-archs", executable], text=True).split()
    bundle_id = f"net.riverdark.Atlantis.smoke.{uuid.uuid4().hex}"
    plist["CFBundleIdentifier"] = bundle_id
    host_info.write_bytes(plistlib.dumps(plist))

    profile = output / "profile"
    target["TestHostBundleIdentifier"] = bundle_id
    target["CommandLineArguments"] = ["--profile-directory", str(profile)]
    target["TestingEnvironmentVariables"]["ATLANTIS_SMOKE_BUNDLE_ID"] = bundle_id
    target["TestingEnvironmentVariables"]["ATLANTIS_SMOKE_PROFILE"] = str(profile)
    staged_config = output / config.name
    staged_config.write_bytes(plistlib.dumps(settings))

    log = output / "test.log"
    result = output / "Smoke.xcresult"
    command = [
        "xcodebuild", "-xctestrun", str(staged_config), "-destination", "platform=macOS",
        "-parallel-testing-enabled", "NO", "-resultBundlePath", str(result),
        *[f"-skip-testing:AtlantisTests/{test}" for test in EXCLUDED_TESTS],
        "test-without-building",
    ]
    print(f"Running hosted Atlantis smoke tests. Log: {log}", flush=True)
    with log.open("w") as stream:
        completed = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT)
    contents = log.read_text(errors="replace")
    match = re.search(
        r"Atlantis profile: preferences suite (net\.riverdark\.Atlantis\.profile\.[0-9a-f]{64}),"
        r" storage directory ([^\n]+)", contents,
    )
    profile_suite = match.group(1) if match else None
    started_profile = profile.is_dir() and match and Path(match.group(2).strip()).resolve() == profile
    # Only touch the domains belonging to this run.
    for domain in filter(None, (bundle_id, profile_suite if started_profile else None)):
        subprocess.run(["defaults", "delete", domain], capture_output=True)

    summary = subprocess.run(
        ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(result)],
        capture_output=True, text=True,
    )
    report = {
        "revision": args.revision,
        "host_bundle_id": bundle_id,
        "app_version": plist.get("CFBundleShortVersionString"),
        "architectures": architectures,
        "xcode_version": xcode_version,
        "build_sdks": sorted(set(re.findall(r"MacOSX[\d.]+\.sdk", build_log))),
        "profile_directory": str(profile),
        "profile_suite": profile_suite,
        "excluded_tests": EXCLUDED_TESTS,
        "xcodebuild_exit_code": completed.returncode,
        "result_bundle": str(result),
    }
    if summary.returncode == 0:
        report["test_summary"] = json.loads(summary.stdout)
    (output / "capture.json").write_text(json.dumps(report, indent=2) + "\n")
    if not started_profile:
        print("The test host did not report starting with the disposable profile.", flush=True)
    return completed.returncode or (0 if started_profile else 1)


if __name__ == "__main__":
    raise SystemExit(main())
