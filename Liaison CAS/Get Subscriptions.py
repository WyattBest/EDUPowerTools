import requests
import common
import json

base_url = common.base_url
organizationId = common.org_id
applicationFormId = common.app_form_id
headers = common.cas_authorize()

url = f"{base_url}/applicationForms/{applicationFormId}/organizations/{organizationId}/subscriptions"
response = requests.get(url, headers=headers)
response.raise_for_status()
subscriptions = response.json()
print(json.dumps(subscriptions, indent=2))

for subscription in subscriptions:
    url = f"{base_url}/applicationForms/{applicationFormId}/organizations/{organizationId}/subscriptions/{subscription['subscriptionId']}"
    response = requests.get(url, headers=headers)
    response.raise_for_status()
    subscription = response.json()
    with open("subscriptions.json", "w") as file:
        file.write(json.dumps(subscription, indent=2))
