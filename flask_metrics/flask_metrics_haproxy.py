import requests
import sentry_sdk
from flask import Flask, Response, render_template
from requests.auth import HTTPBasicAuth
from sentry_sdk.integrations.flask import FlaskIntegration

from newsblur_web import settings

if settings.FLASK_SENTRY_DSN is not None:
    sentry_sdk.init(
        dsn=settings.FLASK_SENTRY_DSN,
        integrations=[FlaskIntegration()],
        traces_sample_rate=1.0,
    )

app = Flask(__name__)

if settings.DOCKERBUILD:
    pass


STATUS_MAPPING = {
    "UNK": 0,  # unknown
    "INI": 1,  # initializing
    "SOCKERR": 2,  # socket error
    "L4OK": 3,  # check passed on layer 4, no upper layers testing enabled
    "L4TOUT": 4,  # layer 1-4 timeout
    "L4CON": 5,  # layer 1-4 connection problem, for example "Connection refused" (tcp rst) or "No route to host" (icmp)
    "L6OK": 6,  # check passed on layer 6
    "L6TOUT": 7,  # layer 6 (SSL) timeout
    "L6RSP": 8,  # layer 6 invalid response - protocol error
    "L7OK": 9,  # check passed on layer 7
    "L7OKC": 10,  # check conditionally passed on layer 7, for example 404 with disable-on-404
    "L7TOUT": 11,  # layer 7 (HTTP/SMTP) timeout
    "L7RSP": 12,  # layer 7 invalid response - protocol error
    "L7STS": 13,  # layer 7 response error, for example HTTP 5xx
}


def format_state_data(label, data):
    formatted_data = {}
    for k, v in data.items():
        if v:
            formatted_data[k] = f'{label}{{servername="{k}"}} {STATUS_MAPPING[v.strip()]}'
    return formatted_data


def fetch_states():
    res = requests.get("https://newsblur.com:1936/;csv", auth=HTTPBasicAuth("gimmiestats", "StatsGiver"))

    lines = res.content.decode("utf-8").split("\n")
    header_line = lines[0].split(",")
    check_status_index = header_line.index("check_status")
    servername_index = header_line.index("svname")

    data = {}
    backends = [line.split(",") for line in lines[1:]]
    for backend_data in backends:
        if len(backend_data) <= check_status_index:
            continue
        if len(backend_data) <= servername_index:
            continue
        if backend_data[servername_index] in ["FRONTEND", "BACKEND"]:
            continue
        backend_status = backend_data[check_status_index].replace("*", "")
        data[backend_data[servername_index]] = backend_status

    return data


def fetch_consul_service_health():
    """Fetch health status for all services from Consul."""
    consul_url = "http://consul.service.consul:8500"

    # Consul health check status mapping to numeric values for Grafana state-timeline
    consul_status_mapping = {
        "passing": 9,  # Use L7OK value to match haproxy healthy state
        "warning": 8,  # Use L6RSP value for warning state
        "critical": 2,  # Use SOCKERR value for critical state
        "unknown": 0,  # Use UNK value for unknown state
    }

    try:
        # Get list of all services
        services_response = requests.get(f"{consul_url}/v1/catalog/services", timeout=5)
        services_response.raise_for_status()
        services = services_response.json()

        service_health = {}

        # For each service, get its health status
        for service_name in services.keys():
            try:
                health_response = requests.get(f"{consul_url}/v1/health/service/{service_name}", timeout=5)
                health_response.raise_for_status()
                health_data = health_response.json()

                # Determine overall service health
                if not health_data:
                    service_health[service_name] = consul_status_mapping["unknown"]
                    continue

                has_critical = False
                has_warning = False
                has_passing = False
                has_checks = False

                for instance in health_data:
                    checks = instance.get("Checks", [])
                    if not checks:
                        continue

                    has_checks = True
                    for check in checks:
                        status = check.get("Status", "unknown")
                        if status == "critical":
                            has_critical = True
                        elif status == "warning":
                            has_warning = True
                        elif status == "passing":
                            has_passing = True

                # Determine overall status and map to numeric value
                if has_critical:
                    service_health[service_name] = consul_status_mapping["critical"]
                elif has_warning:
                    service_health[service_name] = consul_status_mapping["warning"]
                elif has_passing:
                    service_health[service_name] = consul_status_mapping["passing"]
                else:
                    service_health[service_name] = consul_status_mapping["unknown"]

            except Exception as e:
                service_health[service_name] = consul_status_mapping["unknown"]
                if settings.DEBUG:
                    print(f"Error fetching health for service {service_name}: {e}")

        return service_health

    except Exception as e:
        if settings.DEBUG:
            print(f"Error fetching services from Consul: {e}")
        return {}


@app.route("/state/")
def haproxy_state():
    backends = fetch_states()

    formatted_data = format_state_data("haproxy_state", backends)
    context = {"chart_name": "haproxy_state", "chart_type": "gauge", "data": formatted_data}
    html_body = render_template("prometheus_data.html", **context)
    return Response(html_body, content_type="text/plain")


@app.route("/consul/")
def consul_services():
    """Endpoint to expose Consul service health states for Prometheus."""
    services = fetch_consul_service_health()

    formatted_data = {}
    for service_name, status_value in services.items():
        formatted_data[service_name] = f'consul_service_state{{service="{service_name}"}} {status_value}'

    context = {"chart_name": "consul_service_state", "chart_type": "gauge", "data": formatted_data}
    html_body = render_template("prometheus_data.html", **context)
    return Response(html_body, content_type="text/plain")


if __name__ == "__main__":
    print(" ---> Starting NewsBlur Flask Metrics server for HAProxy...")
    app.run(host="0.0.0.0", port=5569, debug=settings.DEBUG)
