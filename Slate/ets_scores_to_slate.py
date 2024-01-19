from zeep import Client
import datetime
import requests

# This script is open-source and free for anyone to use and modify.

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
        "destination": "https://apply.myschool.edu/manage/service/import?cmd=load&format=<guid>",
    },
    "TOEFL": {
        "source": "https://datamanager.ets.org/TOEFLWebService/TOEFLEdm.wsdl",
        "destination": "https://apply.myschool.edu/manage/service/import?cmd=load&format=<guid>",
    },
}

for k, v in score_formats.items():

    # GET scores from ETS
    print(f"Getting {k} data from ETS for {date_begin} to {date_end}...")
    client = Client(v["source"])
    ets_result = client.service.getScorelinkDataByReportDate(
        ets_user, ets_password, date_begin, date_end
    )

    # Appears that ETS doesn't return proper HTTP status codes, so we have to search for error strings.
    if (
        b"is not authenticated" in ets_result
        or b"user name or password is incorrect" in ets_result
    ):
        print("ETS authentication failed.")

    elif ets_result:
        # POST the scores to Slate
        print(f"Uploading {k} scores to Slate...")
        creds = (slate_user, slate_password)
        r = requests.post(v["destination"], auth=creds, data=ets_result)
        r.raise_for_status()
    else:
        print(f"No {k} data found.")
