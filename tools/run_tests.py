"""Import resources and exercise gameplay on a clean machine without network access."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    options = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="towing-tests-") as temp:
        engine = [options.godot, "--headless", "--path", str(ROOT), "--log-file", str(Path(temp)/"engine.log")]
        runs = [["--editor", "--import"], ["--quit-after", "10", "--", "--test-mode"]]
        for test in sorted((ROOT/"tests").glob("*_test.gd")):
            runs.append(["--fixed-fps","60","--script","res://tests/"+test.name,"--","--test-mode"])
        for args in runs:
            result = subprocess.run(engine + args, cwd=ROOT, capture_output=True, text=True, errors="replace", timeout=240)
            log = result.stdout + result.stderr
            if result.returncode or re.search(r"^(?:SCRIPT ERROR|ERROR|SHADER ERROR|FATAL):", log, re.M):
                print(log, file=sys.stderr)
                return 1
            if "--script" in args and "CHECKS PASSED" not in log:
                print(log, file=sys.stderr)
                return 1
            print("Passed", " ".join(args), flush=True)
    return 0

if __name__ == "__main__":
    sys.exit(main())
