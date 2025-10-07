import requests
from django.conf import settings
from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = "Delete old TXT records for Let's Encrypt from DNSimple"

    def handle(self, *args, **kwargs):
        API_TOKEN = settings.DNSIMPLE_API_TOKEN
        ACCOUNT_ID = settings.DNSIMPLE_ACCOUNT_ID
        DOMAIN = "newsblur.com"
        LETSECRYPT_PREFIX = "_acme-challenge"

        headers = {
            "Authorization": f"Bearer {API_TOKEN}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        }

        def get_txt_records():
            records = []
            page = 1
            while True:
                url = f"https://api.dnsimple.com/v2/{ACCOUNT_ID}/zones/{DOMAIN}/records?page={page}"
                response = requests.get(url, headers=headers)
                if response.status_code == 200:
                    data = response.json().get("data", [])
                    records.extend(data)
                    if "pagination" in response.json():
                        pagination = response.json()["pagination"]
                        if pagination["current_page"] < pagination["total_pages"]:
                            page += 1
                        else:
                            break
                    else:
                        break
                else:
                    self.stderr.write(f"Failed to fetch records: {response.status_code} {response.text}")
                    break
            return records

        def delete_record(record_id):
            url = f"https://api.dnsimple.com/v2/{ACCOUNT_ID}/zones/{DOMAIN}/records/{record_id}"
            response = requests.delete(url, headers=headers)
            if response.status_code == 204:
                self.stdout.write(f"Deleted record {record_id}")
            else:
                self.stderr.write(
                    f"Failed to delete record {record_id}: {response.status_code} {response.text}"
                )

        records = get_txt_records()
        self.stdout.write(f"Found {len(records)} records")
        for record in records:
            # self.stdout.write(f"Record: {record}")
            if record["type"] == "TXT" and record["name"].startswith(LETSECRYPT_PREFIX):
                self.stdout.write(f"Deleting record {record['id']} {record['name']} {record['content']}")
                delete_record(record["id"])
