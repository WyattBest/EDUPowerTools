import requests
import json

# Encoura settings
org_id = 'guid'
api_user = 'username'
api_password = 'password'
api_key = 'random string'
api_url = 'https://api.datalab.nrccua.org/v1'

# Slate settings
slate_sf_url = 'https://apply.myschool.edu/manage/service/import?cmd=load&format=<guid>'
slate_user = 'username'
slate_password = 'password'

session = requests.Session()

# Get a JSON web token
headers = {'x-api-key': api_key}
body = {
    'userName': api_user,
    'password': api_password,
    'acceptedTerms': True
}
r = session.post(f'{api_url}/login', headers=headers,
                 json=body)
r_json = r.json()
token = r_json['sessionToken']
org_id = r_json['user']['organizations'][0]['uid']

# Set up headers to use for the rest of the session
headers = {
    'x-api-key': api_key,
    'Authorization': 'JWT ' + token,
    'Organization': org_id
}

# GET the list of score reports
params = {'status': 'NotDelivered', 'productKey': 'score-reporter'}
r = session.get(f'{api_url}/datacenter/exports',
                params=params, headers=headers)
r.raise_for_status()
if r.status_code == 200:
    r_json = r.json()
    score_reports = [k['uid'] for k in r_json if 'uid' in k]
    print(f'Found {len(score_reports)} score reports.')

    # Fetch each individual score report file
    for report in score_reports:
        print(f'Downloading report with uid {report}')
        # GET the AWS S3 URL for the score report
        params= {'filetype': 'csv'}
        r = session.get(f'{api_url}/datacenter/exports/{report}/download',
                        headers=headers)
        r.raise_for_status()
        r_json = r.json()
        download_url = r_json['downloadUrl']

        # GET the actual file from AWS
        r = session.get(download_url)
        r.raise_for_status()
        report_data = r.content

        # POST the score report to Slate
        print(f'Uploading report with uid {report}')
        creds = (slate_user, slate_password)
        r = requests.post(slate_sf_url, auth=creds, data=report_data)
        r.raise_for_status()
else:
    print('No new score reports found.')