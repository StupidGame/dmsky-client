"""Retry transient dependency downloads without hiding build failures."""

from collections import deque
import re
import subprocess
import sys
import time


def is_transient_download_failure(output):
    # Require an actual download diagnostic: a compiler message containing an
    # HTTP status number alone must never cause the entire build to be retried.
    download = re.search(
        r"could not (?:get|head|resolve|download)|could not access|"
        r"failed to (?:download|fetch)|error downloading|"
        r"unable to (?:download|fetch)",
        output,
        re.IGNORECASE,
    )
    transient = re.search(
        r"(?:status code|http(?:/\d(?:\.\d)?)?)\s*[:=]?\s*"
        r"(?:429|5\d\d)\b|too many requests|"
        r"(?:connect|connection|read) (?:timed? out|timeout|reset)|"
        r"remote host terminated the handshake|temporary failure in name resolution",
        output,
        re.IGNORECASE,
    )
    return bool(download and transient)


def run_once(command):
    tail = deque(maxlen=2000)
    with subprocess.Popen(
        command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, errors="replace", bufsize=1,
    ) as process:
        for line in process.stdout:
            print(line, end="", flush=True)
            tail.append(line)
        return process.wait(), "".join(tail)


def run_with_retry(command, *, runner=run_once, sleep=time.sleep):
    delays = (30, 60, 120)
    for attempt in range(len(delays) + 1):
        code, output = runner(command)
        if code == 0 or not is_transient_download_failure(output):
            return code
        if attempt == len(delays):
            return code
        delay = delays[attempt]
        print(
            f"Dependency download failed temporarily; retrying in {delay}s "
            f"(attempt {attempt + 2}/{len(delays) + 1}).",
            flush=True,
        )
        sleep(delay)
    raise AssertionError("unreachable")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("Usage: run_with_download_retry.py COMMAND [ARG ...]")
    try:
        sys.exit(run_with_retry(sys.argv[1:]))
    except KeyboardInterrupt:
        sys.exit(130)
