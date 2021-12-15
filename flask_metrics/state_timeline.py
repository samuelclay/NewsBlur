from flask import render_template
import requests
from requests.auth import HTTPBasicAuth


STATUS_MAPPING = {
    "UNK": 0,      # unknown
    "INI": 1,      # initializing
    "SOCKERR": 2,  # socket error
    "L4OK": 3,     # check passed on layer 4, no upper layers testing enabled
    "L4TOUT": 4,   # layer 1-4 timeout
    "L4CON": 5,    # layer 1-4 connection problem, for example "Connection refused" (tcp rst) or "No route to host" (icmp)
    "L6OK": 6,     # check passed on layer 6
    "L6TOUT": 7,   # layer 6 (SSL) timeout
    "L6RSP": 8,    # layer 6 invalid response - protocol error
    "L7OK": 9,     # check passed on layer 7
    "L7OKC": 10,   # check conditionally passed on layer 7, for example 404 with disable-on-404
    "L7TOUT": 11,  # layer 7 (HTTP/SMTP) timeout
    "L7RSP": 12,   # layer 7 invalid response - protocol error
    "L7STS": 13,   # layer 7 response error, for example HTTP 5xx
}

def format_state_data(label, data):
    formatted_data = {}
    for k, v in data.items():
        if v:
            formatted_data[k] = f'{label}{{servername="{k}"}} {STATUS_MAPPING[v.strip()]}'
    return formatted_data

def get_state(backend_name):
    res = requests.get('https://newsblur.com:1936/;csv', auth=HTTPBasicAuth('gimmiestats', 'StatsGiver'))
    lines = res.content.decode('utf-8').split('\n')
    backends = [line.split(",") for line in lines if backend_name in line]

    check_status_index = lines[0].split(",").index('check_status')
    servername_index = lines[0].split(",").index('svname')

    data = {}

    for backend_data in backends:
        data[backend_data[servername_index]] = backend_data[check_status_index].replace("*", "")
    return data
