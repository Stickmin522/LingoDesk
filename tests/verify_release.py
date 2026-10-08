"""Check release SDK, architecture, signature, native page sizes and test isolation."""
import hashlib
import argparse
import json
import os
import re
import struct
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSION, CODE = re.search(r"^version:\s*([^+\s]+)\+(\d+)", (ROOT / "app/pubspec.yaml").read_text(encoding="utf-8"), re.M).groups()
APK = ROOT / f"outputs/lingodesk-{VERSION}-arm64.apk"
options = argparse.ArgumentParser()
options.add_argument("--certificate-sha256", default="51bf5e9d34a840c7734b4e428046786113368e1f7460db335f174a8fa8e555ac", help="Expected signing certificate; forks must pass their own certificate fingerprint.")
options.add_argument("--application-id", default="com.lecsync.desk")
options.add_argument("--report", type=Path, help="Optionally save the check results as JSON.")
args = options.parse_args()
sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
if not sdk:
    sdk = str(Path(os.environ["LOCALAPPDATA"]) / "Android/Sdk") if os.name == "nt" else str(Path.home() / "Android/Sdk")
SDK = Path(sdk)
BUILD_TOOLS = SDK / "build-tools/37.0.0"

def tool(name, *args):
    command = [str(BUILD_TOOLS / name), *map(str, args)]
    if name.endswith(".bat"):
        command = ["cmd.exe", "/d", "/c", *command]
    return subprocess.check_output(command, encoding="utf-8", errors="replace")

badging = tool("aapt2.exe", "dump", "badging", APK)
package = re.search(r"package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", badging).groups()
minimum = int(re.search(r"(?:minSdkVersion|sdkVersion):'(\d+)'", badging)[1])
target = int(re.search(r"targetSdkVersion:'(\d+)'", badging)[1])
compiled = int(re.search(r"compileSdkVersion='(\d+)'", badging)[1])
assert package == (args.application_id, CODE, VERSION) and (minimum, target, compiled) == (29, 37, 37)
assert "application-debuggable" not in badging
signatures = tool("apksigner.bat", "verify", "--print-certs", APK)
certificate = re.search(r"certificate SHA-256 digest: ([0-9a-f]+)", signatures)[1]
assert certificate == args.certificate_sha256.lower(), "Unexpected certificate; forks should use --certificate-sha256."
tool("zipalign.exe", "-c", "-P", "16", "4", APK)
libraries = []
with zipfile.ZipFile(APK) as archive:
    names = [name for name in archive.namelist() if name.startswith("lib/") and name.endswith(".so")]
    assert {name.split("/")[1] for name in names} == {"arm64-v8a"}
    for name in names:
        data = archive.read(name)
        assert data[:6] == b"\x7fELF\x02\x01"
        offset = struct.unpack_from("<Q", data, 32)[0]
        size, count = struct.unpack_from("<HH", data, 54)
        alignments = []
        for index in range(count):
            header = offset + size * index
            if struct.unpack_from("<I", data, header)[0] == 1:
                alignment = struct.unpack_from("<Q", data, header + 48)[0]
                file_offset, address = struct.unpack_from("<QQ", data, header + 8)
                assert alignment >= 16384 and file_offset % 16384 == address % 16384, name
                alignments.append(alignment)
        if name.endswith("liblecsync_core.so"):
            assert b"LOCAL_TEST_ONLY" not in data and b"127.0.0.1:8787" not in data
        libraries.append({"name": name, "loadAlignments": alignments})
report = {
    "file": APK.name, "bytes": APK.stat().st_size,
    "sha256": hashlib.sha256(APK.read_bytes()).hexdigest(),
    "applicationId": package[0], "versionCode": int(package[1]), "versionName": package[2],
    "minSdk": minimum, "targetSdk": target, "compileSdk": compiled, "abi": "arm64-v8a", "debuggable": False,
    "signatureVerified": True, "certificateSha256": certificate,
    "zipAligned16KB": True, "productionTestAddressAbsent": True, "libraries": libraries,
}
if args.report:
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report, indent=2))
