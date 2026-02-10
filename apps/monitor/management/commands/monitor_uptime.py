import socket
import ssl
import subprocess
import time
from datetime import datetime, timezone
from urllib.request import Request, urlopen
from urllib.error import URLError

from django.core.management.base import BaseCommand


RESOLVERS = ["8.8.8.8", "1.1.1.1", "9.9.9.9"]


class Command(BaseCommand):
    help = "Continuously monitors NewsBlur production uptime with DNS, HTTP, TCP, and TLS checks"

    def add_arguments(self, parser):
        parser.add_argument(
            "-i",
            "--interval",
            dest="interval",
            type=int,
            default=10,
            help="Seconds between checks (default: 10)",
        )
        parser.add_argument(
            "-d",
            "--domain",
            dest="domain",
            default="www.newsblur.com",
            help="Domain to monitor (default: www.newsblur.com)",
        )
        parser.add_argument(
            "-p",
            "--path",
            dest="path",
            default="/health-check",
            help="Health check path (default: /health-check)",
        )
        parser.add_argument(
            "-q",
            "--quiet",
            dest="quiet",
            action="store_true",
            help="Only print anomalies (suppress OK lines)",
        )

    def handle(self, *args, **options):
        domain = options["domain"]
        interval = options["interval"]
        path = options["path"]
        quiet = options["quiet"]

        self.stdout.write(f"=== NewsBlur Uptime Monitor ===")
        self.stdout.write(f"Domain:   {domain}")
        self.stdout.write(f"Path:     {path}")
        self.stdout.write(f"Interval: {interval}s")
        self.stdout.write(f"Started:  {self.now()}")
        self.stdout.write("---")

        check_count = 0
        anomaly_count = 0

        try:
            while True:
                check_count += 1
                ts = self.now()
                issues = []

                dns_summary = self.check_dns(domain, issues)
                http_summary = self.check_http(domain, path, issues)
                tcp_summary = self.check_tcp(domain, issues)
                tls_summary = self.check_tls(domain, issues)

                line = f"[{ts}] #{check_count} | {dns_summary} | {http_summary} | {tcp_summary} | {tls_summary}"

                if issues:
                    anomaly_count += 1
                    issue_str = " ".join(issues)
                    self.stdout.write(f"{line} | *** ANOMALY: {issue_str} ***")
                    self.run_extra_diagnostics(domain)
                elif not quiet:
                    if check_count % 6 == 0:
                        self.stdout.write(
                            f"{line} [ok, {anomaly_count} anomalies in {check_count} checks]"
                        )
                    else:
                        self.stdout.write(line)

                time.sleep(interval)

        except KeyboardInterrupt:
            self.stdout.write(f"\n--- Monitor stopped: {self.now()} ---")
            self.stdout.write(f"Total checks: {check_count}, Anomalies: {anomaly_count}")

    def now(self):
        return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

    def check_dns(self, domain, issues):
        """Resolve domain via system DNS and measure time."""
        start = time.monotonic()
        try:
            results = socket.getaddrinfo(domain, 443, socket.AF_INET, socket.SOCK_STREAM)
            elapsed_ms = int((time.monotonic() - start) * 1000)
            ips = sorted(set(r[4][0] for r in results))
            ip_count = len(ips)

            if elapsed_ms > 2000:
                issues.append(f"[DNS SLOW: {elapsed_ms}ms]")

            return f"DNS:{elapsed_ms}ms({ip_count}IP:{','.join(ips)})"
        except socket.gaierror as e:
            elapsed_ms = int((time.monotonic() - start) * 1000)
            issues.append(f"[DNS FAIL: {e}]")
            return f"DNS:FAIL({elapsed_ms}ms)"

    def check_http(self, domain, path, issues):
        """HTTPS GET request to the health check endpoint."""
        url = f"https://{domain}{path}"
        start = time.monotonic()
        try:
            ctx = ssl.create_default_context()
            req = Request(url, headers={"User-Agent": "NewsBlur-Monitor/1.0"})
            resp = urlopen(req, timeout=15, context=ctx)
            status = resp.status
            resp.read()
            elapsed_ms = int((time.monotonic() - start) * 1000)

            if status >= 400:
                issues.append(f"[HTTP {status}]")
            elif elapsed_ms > 10000:
                issues.append(f"[HTTP SLOW: {elapsed_ms}ms]")

            return f"HTTP:{status}/{elapsed_ms}ms"
        except URLError as e:
            elapsed_ms = int((time.monotonic() - start) * 1000)
            reason = str(e.reason) if hasattr(e, "reason") else str(e)
            issues.append(f"[HTTP FAIL: {reason}]")
            return f"HTTP:FAIL/{elapsed_ms}ms"
        except Exception as e:
            elapsed_ms = int((time.monotonic() - start) * 1000)
            issues.append(f"[HTTP ERR: {e}]")
            return f"HTTP:ERR/{elapsed_ms}ms"

    def check_tcp(self, domain, issues):
        """Raw TCP connect to port 443."""
        start = time.monotonic()
        try:
            sock = socket.create_connection((domain, 443), timeout=5)
            elapsed_ms = int((time.monotonic() - start) * 1000)
            sock.close()
            return f"TCP:{elapsed_ms}ms"
        except (socket.timeout, socket.error, OSError) as e:
            elapsed_ms = int((time.monotonic() - start) * 1000)
            issues.append(f"[TCP FAIL: {e}]")
            return f"TCP:FAIL/{elapsed_ms}ms"

    def check_tls(self, domain, issues):
        """TLS handshake and certificate validity check."""
        start = time.monotonic()
        try:
            ctx = ssl.create_default_context()
            with socket.create_connection((domain, 443), timeout=5) as sock:
                with ctx.wrap_socket(sock, server_hostname=domain) as ssock:
                    elapsed_ms = int((time.monotonic() - start) * 1000)
                    cert = ssock.getpeercert()
                    not_after = cert.get("notAfter", "unknown")
                    protocol = ssock.version()

                    return f"TLS:{protocol}/{elapsed_ms}ms(exp:{not_after})"
        except ssl.SSLError as e:
            elapsed_ms = int((time.monotonic() - start) * 1000)
            issues.append(f"[TLS FAIL: {e}]")
            return f"TLS:FAIL/{elapsed_ms}ms"
        except Exception as e:
            elapsed_ms = int((time.monotonic() - start) * 1000)
            issues.append(f"[TLS ERR: {e}]")
            return f"TLS:ERR/{elapsed_ms}ms"

    def run_extra_diagnostics(self, domain):
        """On anomaly, run DNS from multiple public resolvers for comparison."""
        self.stdout.write("  >> Multi-resolver DNS check:")
        for resolver in RESOLVERS:
            try:
                result = subprocess.run(
                    ["dig", "+short", f"@{resolver}", domain, "A"],
                    capture_output=True,
                    text=True,
                    timeout=5,
                )
                ips = result.stdout.strip() or "(empty)"
                self.stdout.write(f"     {resolver}: {ips}")
            except Exception as e:
                self.stdout.write(f"     {resolver}: error ({e})")
