import requests
import common
import json
import getpass


base_url = common.base_url
organizationId = common.org_id
applicationFormId = common.app_form_id
headers = common.cas_authorize()

sftpUser = input("Enter SFTP User: ")
sftpPassword = getpass.getpass("Enter SFTP Password: ")
notificationEmailAddress = input("Enter Notification Email Address: ")

# Configure subscription for documents
url = f"{base_url}/applicationForms/{applicationFormId}/organizations/{organizationId}/subscriptions"
payload = {
    "notificationEmailAddress": f"{notificationEmailAddress}",
    "subscriptionDetails": [
        {
            "destinationType": "SFTP",
            "event": "application.program.received",
            "responseLevel": "program",
            "responseType": "fullResponse",
            # pdfType=reviewer masks SSN and race
            "responseOptions": "contentType=application/pdf,pdfType=reviewer",
            "apiVersion": "v1",
            "sftpDestination": {
                "sftpHost": "ft.technolutions.net",
                "sftpPort": 22,
                "sftpUser": f"{sftpUser}",
                "sftpPassword": f"{sftpPassword}",
                "sftpBaseDirectory": "/incoming/liaison/",
                "sftpPathTemplate": "DICAS_app_<casApplicantId>_<programId>_fullAppPDF__<applicationId>!<deliveredDate>.pdf",
            },
        },
        {
            "destinationType": "SFTP",
            "event": "file.attachment.updated",
            "responseLevel": "organization",
            "responseType": "fullResponse",
            "dataHold": "InProgress",
            "sftpDestination": {
                "sftpHost": "ft.technolutions.net",
                "sftpPort": 22,
                "sftpUser": f"{sftpUser}",
                "sftpPassword": f"{sftpPassword}",
                "sftpBaseDirectory": "/incoming/liaison/",
                "sftpPathTemplate": "DICAS_pers_<casApplicantId>__<documentSubType>__<fileId>!<deliveredDate>.pdf",
            },
        },
        {
            "destinationType": "SFTP",
            "event": "file.supplementalAttachment.updated",
            "responseLevel": "program",
            "responseType": "fullResponse",
            "dataHold": "InProgress",
            "sftpDestination": {
                "sftpHost": "ft.technolutions.net",
                "sftpPort": 22,
                "sftpUser": f"{sftpUser}",
                "sftpPassword": f"{sftpPassword}",
                "sftpBaseDirectory": "/incoming/liaison/",
                "sftpPathTemplate": "DICAS_app_<casApplicantId>_<programId>_<documentSubType>__<fileId>!<deliveredDate>.pdf",
            },
        },
        {
            "destinationType": "SFTP",
            "event": "file.evaluation.updated",
            "responseLevel": "program",
            "responseType": "fullResponse",
            "dataHold": "InProgress",
            "sftpDestination": {
                "sftpHost": "ft.technolutions.net",
                "sftpPort": 22,
                "sftpUser": f"{sftpUser}",
                "sftpPassword": f"{sftpPassword}",
                "sftpBaseDirectory": "/incoming/liaison/",
                "sftpPathTemplate": "DICAS_app_<casApplicantId>_<programId>_<docType>__<fileId>!<deliveredDate>.pdf",
            },
        },
        {
            "destinationType": "SFTP",
            "event": "file.transcript.updated",
            "responseLevel": "organization",
            "responseType": "fullResponse",
            "dataHold": "InProgress",
            "sftpDestination": {
                "sftpHost": "ft.technolutions.net",
                "sftpPort": 22,
                "sftpUser": f"{sftpUser}",
                "sftpPassword": f"{sftpPassword}",
                "sftpBaseDirectory": "/incoming/liaison/",
                "sftpPathTemplate": "DICAS_pers_<casApplicantId>__<docType><transcriptType>_<collegeAttendedId>_<fileId>!<deliveredDate>.pdf",
            },
        },
        {
            "destinationType": "SFTP",
            "event": "file.vendorTranscriptEval.updated",
            "responseLevel": "organization",
            "responseType": "fullResponse",
            "dataHold": "InProgress",
            "sftpDestination": {
                "sftpHost": "ft.technolutions.net",
                "sftpPort": 22,
                "sftpUser": f"{sftpUser}",
                "sftpPassword": f"{sftpPassword}",
                "sftpBaseDirectory": "/incoming/liaison/",
                "sftpPathTemplate": "DICAS_pers_<casApplicantId>__<docType>_<collegeAttendedId>_<fileId>!<deliveredDate>.pdf",
            },
        },
    ],
}
response = requests.post(url, json=payload, headers=headers)
print(json.dumps(response.json(), indent=2))
