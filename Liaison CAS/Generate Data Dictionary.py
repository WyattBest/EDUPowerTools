import requests
import common

base_url = common.base_url
organizationId = common.org_id
applicationFormId = common.app_form_id
headers = common.cas_authorize()

# Get dictionary
url = f"{base_url}/applicationForms/{applicationFormId}/organizations/{organizationId}/applications/dataDictionary?modelVersion=v2"
response = requests.get(url, headers=headers)
response.raise_for_status()

# Write to binary file
with open("data_dictionary.xlsx", "wb") as f:
    f.write(response.content)
