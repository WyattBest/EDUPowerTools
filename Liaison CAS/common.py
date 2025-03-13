import requests
import getpass


def cas_authorize():
    """Get token and return headers."""
    url = f"{base_url}/auth/token"
    headers = {"x-api-key": api_key}
    response = requests.post(url, json=payload, headers=headers)
    response.raise_for_status()
    token = response.json()["Token"]
    headers = {"x-api-key": api_key, "Authorization": token}

    return headers


org_id = input("Enter Organization ID: ")
app_form_id = input("Enter Application Form ID: ")
prod_url = "https://api.liaisonedu.com/v1"
prelaunch_base_url = "https://api.prelaunch.liaisonedu.com/v1"
env_selection = input("Enter '1' for prelaunch or '2' for production: ")
if env_selection == 1:
    base_url = prelaunch_base_url
else:
    base_url = prod_url

api_key = getpass.getpass("Enter API Key: ")
username = input("Enter Username: ")
password = getpass.getpass("Enter Password: ")
payload = {"UserName": username, "Password": password}
