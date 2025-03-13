import requests
import json
import common

base_url = common.base_url
organizationId = common.org_id
applicationFormId = common.app_form_id
headers = common.cas_authorize()

url = f"{base_url}/applicationForms/{applicationFormId}/organizations/{organizationId}/replays"

response = requests.get(url, headers=headers)
response.raise_for_status()
print(json.dumps(response.json(), indent=2))
