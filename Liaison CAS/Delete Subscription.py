import requests
import common

base_url = common.base_url
organizationId = common.org_id
applicationFormId = common.app_form_id
headers = common.cas_authorize()

subscription_id = input("Enter Subscription ID: ")

# Make the DELETE request
url = f"{base_url}/applicationForms/{applicationFormId}/organizations/{organizationId}/subscriptions/{subscription_id}"
response = requests.delete(url, headers=headers)

# Print the response
print(response.status_code)
