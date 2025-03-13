import requests
import common

base_url = common.base_url
organizationId = common.org_id
applicationFormId = common.app_form_id
headers = common.cas_authorize()
subscriptionId = input("Enter Subscription ID: ")
url = f"{base_url}/applicationForms/{applicationFormId}/organizations/{organizationId}/replays"

again = True
while again:
    fromDate = input("Enter From Date (YYYY-MM-DD): ")
    toDate = input("Enter To Date (YYYY-MM-DD): ")

    payload = {
        "fromDate": fromDate,
        "toDate": toDate,
        "id": 0,
        # You can specify details of the subscription to replay if you don't want everything
        # "subscription": {"subscriptionDetails": [{"id": 24584}], "subscriptionId": 3389},
        "subscription": {"subscriptionId": subscriptionId},
    }
    response = requests.post(url, json=payload, headers=headers)
    response.raise_for_status()

    print(response.json())
    again = input("Replay another date range? (y/n): ").lower() == "y"
