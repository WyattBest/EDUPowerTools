import requests
import common

base_url = common.base_url
organizationId = common.org_id
applicationFormId = common.app_form_id
headers = common.cas_authorize()

replayId = input("Enter replay ID: ")
url = f"{base_url}/applicationForms/{applicationFormId}/organizations/{organizationId}/replays/{replayId}"

response = requests.get(url, headers=headers)
response.raise_for_status()
print(response.json())
