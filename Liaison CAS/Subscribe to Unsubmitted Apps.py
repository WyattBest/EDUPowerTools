import requests
import common
import getpass

base_url = common.base_url
organizationId = common.org_id
applicationFormId = common.app_form_id
headers = common.cas_authorize()

sftpUser = input("Enter SFTP User: ")
sftpPassword = getpass.getpass("Enter SFTP Password: ")
notificationEmailAddress = input("Enter Notification Email Address: ")

# Configure subscription for submitted applications
url = f"{base_url}/applicationForms/{applicationFormId}/organizations/{organizationId}/subscriptions"
payload = {
    "notificationEmailAddress": f"{notificationEmailAddress}",
    "subscriptionDetails": [
        {
            "destinationType": "SFTP",
            "event": "application.program.selected",
            "responseLevel": "program",
            "responseType": "fullResponse",
            "responseOptions": "expand=all,includeNulls=true,contentType=text/csv,columnSeparator=COMMA,csvHeaderTruncationSize=4,csvShortName=question",
            "apiVersion": "v2",
            "sftpDestination": {
                "sftpHost": "ft.technolutions.net",
                "sftpPort": 22,
                "sftpUser": f"{sftpUser}",
                "sftpPassword": f"{sftpPassword}",
                "sftpBaseDirectory": "/incoming/liaison/",
                "sftpPathTemplate": "DICAS_<instanceId>_<organizationId>_<programId>_<applicationId>_<casApplicantId>.csv",
            },
        }
    ],
}
response = requests.post(url, json=payload, headers=headers)
print(response.json())
