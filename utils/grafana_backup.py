import json
import requests

with open('/srv/secrets-newsblur/keys/grafana_api_key', 'r') as file:
    GRAFANA_API_KEY = file.read()[:-1]

settings = {
    'GRAFANA_URL': 'https://metrics.newsblur.com',
    'VERIFY_SSL': True,
    'GRAFANA_API_KEY': GRAFANA_API_KEY,
}

if not settings['GRAFANA_API_KEY']:
    print("API Key Required. \n Please add a Grafana API Key to `/srv/secrets-newsblur/keys/grafana_api_key`")

headers = {
    "Authorization": f"Bearer {settings['GRAFANA_API_KEY']}"
}

def list_dashboards():
    url = f"{settings['GRAFANA_URL']}/api/search?query=%"
    res = requests.get(url, headers=headers, verify=True)

    return res.json()

def get_dashboard(uid):
    url = f"{settings['GRAFANA_URL']}/api/dashboards/uid/{uid}"
    res = requests.get(url, headers=headers, verify=True) 
    return res.json()


dashboards = [dash for dash in list_dashboards() if dash['type'] == 'dash-db']
dashboard_uids = [dash['uid'] for dash in dashboards]

for uid in dashboard_uids:
    dashboard_data = get_dashboard(uid)
    dashboard_name = dashboard_data['meta']['slug'] + "_dashboard.json"
    with open(f'./docker/grafana/dashboards/{dashboard_name}', 'w') as f:
        json.dump(dashboard_data['dashboard'], f, indent=4)
