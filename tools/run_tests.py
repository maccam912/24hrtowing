"""Import resources and exercise gameplay on a clean machine without network access.

The import runs first. The boot check and every tests/*_test.gd script then run
in parallel, one engine per check, and every failure is reported at the end.
Pass part of a test name to run only matching scripts.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
ENGINE_FAILURE = re.compile(r"^(?:SCRIPT ERROR|ERROR|SHADER ERROR|FATAL):")
TIMEOUT = 240


def check(engine, label, args, log):
    """Run one engine session and return (label, passed, seconds, output)."""
    started = time.monotonic()
    process = subprocess.Popen(engine + ["--log-file", str(log)] + args, cwd=ROOT, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True, errors="replace")
    stopped = []

    def stop(reason):
        if process.poll() is None:
            stopped.append(reason)
            process.kill()

    deadline = threading.Timer(TIMEOUT, stop, [f"Timed out after {TIMEOUT} s"])
    deadline.start()
    lines = []
    failed = False
    try:
        for line in process.stdout:
            lines.append(line)
            # A script error leaves the engine running until the timeout. Keep
            # the backtrace that follows it, then stop the session.
            if not failed and ENGINE_FAILURE.match(line):
                failed = True
                threading.Timer(2.0, stop, ["Stopped after an engine error"]).start()
        process.wait()
    finally:
        deadline.cancel()
    output = "".join(lines)
    if stopped:
        output = stopped[0] + "\n" + output
    passed = process.returncode == 0 and not failed and not stopped
    if "--script" in args and "CHECKS PASSED" not in output:
        passed = False
    return label, passed, time.monotonic() - started, output


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--jobs", type=int, default=os.cpu_count() or 1,
                        help="engine sessions to run at once (default: one per CPU)")
    parser.add_argument("only", nargs="*", help="run only test scripts whose names contain one of these")
    options = parser.parse_args()
    tests = sorted((ROOT/"tests").glob("*_test.gd"))
    if options.only:
        tests = [test for test in tests if any(part in test.name for part in options.only)]
        if not tests:
            print("No test scripts match " + ", ".join(options.only), file=sys.stderr)
            return 1
    with tempfile.TemporaryDirectory(prefix="towing-tests-") as temp:
        logs = Path(temp)
        engine = [options.godot, "--headless", "--path", str(ROOT)]
        # Every later session reads the imported resources, so a failed import stops here.
        label, passed, seconds, output = check(engine, "import", ["--editor", "--import"], logs/"import.log")
        if not passed:
            print(output, file=sys.stderr)
            print("FAILED import", file=sys.stderr)
            return 1
        print(f"Passed import ({seconds:.1f} s)", flush=True)
        runs = [("boot", ["--quit-after", "10", "--", "--test-mode"])]
        runs += [("tests/" + test.name, ["--fixed-fps", "60", "--script", "res://tests/" + test.name, "--", "--test-mode"])
                 for test in tests]
        failures = []
        with ThreadPoolExecutor(max_workers=max(1, options.jobs)) as pool:
            pending = [pool.submit(check, engine, label, args, logs/f"{index:03d}.log")
                       for index, (label, args) in enumerate(runs)]
            for done in as_completed(pending):
                label, passed, seconds, output = done.result()
                print(f"{'Passed' if passed else 'FAILED'} {label} ({seconds:.1f} s)", flush=True)
                if not passed:
                    failures.append((label, output))
    for label, output in sorted(failures):
        print(f"\n===== {label} =====\n{output}", file=sys.stderr)
    if failures:
        print(f"\n{len(failures)} of {len(runs)} checks failed: " + ", ".join(sorted(label for label, _ in failures)), file=sys.stderr)
        return 1
    print(f"All {len(runs)} checks passed", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
