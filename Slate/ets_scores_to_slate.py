from zeep import Client
import datetime
import requests

# ETS settings
ets_user = "a user"
ets_password = "a password"
date_begin = datetime.date.today() - datetime.timedelta(days=7)
date_end = datetime.date.today()

# Slate settings
slate_user = "a user"
slate_password = "a password"

score_formats = {
    "GRE": {
        "source": "https://datamanager.ets.org/GREWebService/GREEdm.wsdl",
        "destination": "slate source format URL",
    },
    "TOEFL": {
        "source": "https://datamanager.ets.org/TOEFLWebService/TOEFLEdm.wsdl",
        "destination": "slate source format URL",
    },
}

for k, v in score_formats.items():

    # GET scores from ETS
    print(f"Getting {k} data from ETS for {date_begin} to {date_end}...")
    client = Client(v["source"])
    ets_result = client.service.getScorelinkDataByReportDate(
        creds[0], creds[1], date_begin, date_end
    )

    if ets_result:
        # POST the scores to Slate
        print(f"Uploading {k} scores to Slate...")
        creds = (slate_user, slate_password)
        r = requests.post(format["destination"], auth=creds, data=ets_result)
        r.raise_for_status()
    else:
        print(f"No {k} data found.")
