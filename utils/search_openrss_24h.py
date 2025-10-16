#!/usr/bin/env python

import argparse
import os
import re
import subprocess
import sys
from collections import defaultdict
from datetime import datetime, timedelta


# Function to strip ANSI color codes
def strip_ansi(text):
    ansi_escape = re.compile(r"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")
    return ansi_escape.sub("", text)


# Parse arguments
parser = argparse.ArgumentParser(description="Search NewsBlur servers for OpenRSS.org fetch entries")
parser.add_argument(
    "--role", default="task", choices=["task", "app"], help="Server role to search (default: task)"
)
parser.add_argument("--all-logs", action="store_true", help="Search all log files, not just current log")
args = parser.parse_args()

role = args.role

# Get logs from servers using zgrep with --no-follow
print(f"Searching {role} servers for 'openrss.org fetch' entries...")
cmd = [sys.executable, "utils/zgrep.py", role, "openrss.org fetch", "--no-follow"]
if not args.all_logs:
    cmd.append("--current-only")

result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

# Get current time and 24 hours ago
now = datetime.now()
yesterday = now - timedelta(hours=24)

# Parse log entries and filter by timestamp
entries = []
entries_by_second = defaultdict(list)
proceeding_by_second = defaultdict(list)
skipping_by_second = defaultdict(list)

for line in result.stdout.splitlines():
    # Skip command output lines and warnings
    if line.startswith(" ---") or line.startswith(" --->") or "Warning:" in line:
        continue

    # Strip ANSI codes
    clean_line = strip_ansi(line)

    # Extract timestamp from log line
    # NewsBlur log format: [Jul 29 14:07:33] or [2024-07-29 14:07:33]
    timestamp_match = re.search(r"\[(\w{3} \d{2} \d{2}:\d{2}:\d{2})\]", clean_line)
    if timestamp_match:
        try:
            # Parse the timestamp - assume current year
            timestamp_str = timestamp_match.group(1)
            timestamp = datetime.strptime(f"2025 {timestamp_str}", "%Y %b %d %H:%M:%S")

            # Check if within last 24 hours
            if timestamp >= yesterday:
                entries.append((timestamp, clean_line))
                # Group by second for analysis
                second_key = timestamp.strftime("%Y-%m-%d %H:%M:%S")
                entries_by_second[second_key].append(clean_line)

                # Categorize by type
                if "Proceeding with openrss.org fetch" in clean_line:
                    proceeding_by_second[second_key].append(clean_line)
                elif "Skipping openrss.org fetch" in clean_line:
                    skipping_by_second[second_key].append(clean_line)
        except ValueError:
            continue

# Sort entries by timestamp
entries.sort(key=lambda x: x[0])

# Write to log file
output_file = f"logs/openrss_fetch_last_24h_{role}.log"
os.makedirs("logs", exist_ok=True)

# Analyze concurrent fetches
concurrent_seconds = {k: v for k, v in entries_by_second.items() if len(v) > 1}
# Find seconds with multiple "Proceeding" messages (rate limit violations)
rate_limit_violations = {k: v for k, v in proceeding_by_second.items() if len(v) > 1}
# Find seconds with successful rate limiting (1 proceeding + N skipping)
successful_rate_limits = {}
for second, logs in concurrent_seconds.items():
    proceeding_count = len(proceeding_by_second.get(second, []))
    skipping_count = len(skipping_by_second.get(second, []))
    if proceeding_count == 1 and skipping_count >= 1:
        successful_rate_limits[second] = logs

with open(output_file, "w") as f:
    f.write(f"OpenRSS.org fetch logs from {role.upper()} servers\n")
    f.write(f"Period: {yesterday.strftime('%Y-%m-%d %H:%M:%S')} to {now.strftime('%Y-%m-%d %H:%M:%S')}\n")
    f.write(f"Total entries: {len(entries)}\n")
    f.write(f"Seconds with concurrent fetches: {len(concurrent_seconds)}\n")
    f.write(f"RATE LIMIT VIOLATIONS (multiple 'Proceeding' in same second): {len(rate_limit_violations)}\n")
    f.write(f"Successful rate limits (1 proceeding + N skips): {len(successful_rate_limits)}\n")
    f.write("=" * 80 + "\n\n")

    # Write rate limit violations first
    if rate_limit_violations:
        f.write("RATE LIMIT VIOLATIONS (multiple 'Proceeding' messages in same second):\n")
        f.write("-" * 80 + "\n")
        for second, logs in sorted(rate_limit_violations.items()):
            f.write(f"\n{second} - {len(logs)} PROCEEDING fetches (VIOLATION!):\n")
            for log in entries_by_second[second]:
                f.write(f"  {log}\n")
        f.write("\n" + "=" * 80 + "\n\n")

    # Write successful rate limits
    if successful_rate_limits:
        f.write("SUCCESSFUL RATE LIMITS (1 proceeding + skips):\n")
        f.write("-" * 80 + "\n")
        total_skips = 0
        for second, logs in sorted(successful_rate_limits.items()):
            skip_count = len(skipping_by_second.get(second, []))
            total_skips += skip_count
            f.write(f"\n{second} - 1 proceeding + {skip_count} skips:\n")
            for log in logs:
                f.write(f"  {log}\n")
        f.write(f"\nTotal successful skips: {total_skips}\n")
        f.write("\n" + "=" * 80 + "\n\n")

    # Write all entries
    f.write("ALL ENTRIES:\n")
    f.write("-" * 80 + "\n")
    for timestamp, line in entries:
        f.write(line + "\n")

print(f"Found {len(entries)} entries in the last 24 hours")
print(f"Found {len(concurrent_seconds)} seconds with concurrent fetches")
print(f"RATE LIMIT VIOLATIONS: {len(rate_limit_violations)} seconds with multiple 'Proceeding' messages")
print(f"Successful rate limits: {len(successful_rate_limits)} seconds")
print(f"Results saved to: {output_file}")
