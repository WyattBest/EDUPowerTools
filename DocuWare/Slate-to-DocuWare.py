import configparser
import os
import sys
import paramiko
from zipfile import ZipFile
import shutil

# Download DIP file from Slate, unzip to appropriate folder, and delete from Slate.
# Intended to be called from Windows Task Scheduler.
# Usage: py .\Slate-to-DocuWare.py .\config_file.ini

# Load config
config = configparser.ConfigParser()
config.read(sys.argv[1])
cwd = os.getcwd() + "\\temp\\"
if not os.path.exists(cwd):
    os.makedirs(cwd)
if config["docuware"]["dir"][-1] != "\\":
    raise ValueError("DocuWare directory (dir) must end with a backslash.")

# Connect to the remote server
client = paramiko.SSHClient()
client.load_host_keys("server_key")
client.connect(
    hostname=config["slate"]["server"],
    username=config["slate"]["username"],
    key_filename=config["slate"]["private_key_file"],
    passphrase=config["slate"]["private_key_pass"],
)
sftp = client.open_sftp()
sftp.chdir(config["slate"]["remote_dir"])

# List files in the current directory
i = 0
for remote_file in sftp.listdir():
    if remote_file.endswith(".zip"):
        i += 1
        print(f"Found file: {remote_file}")
        # Download the file
        sftp.get(
            remotepath=remote_file,
            localpath=cwd + remote_file,
        )
        print(f"Downloaded file: {remote_file}")

        # Unzip the file
        print(f"Extracting file: {remote_file}")
        with ZipFile(cwd + remote_file, "r") as zip_ref:
            zip_ref.extractall(cwd)

        # Unzip the file and delete it
        with ZipFile(cwd + remote_file, "r") as zip_ref:
            zip_ref.extractall(cwd)
        os.remove(cwd + remote_file)

        # Move the extracted files to the target directory
        for file in os.listdir(cwd):
            shutil.move(cwd + file, config["docuware"]["dir"] + file)

        # Delete file from the remote server
        print(f"Deleting file from server: {remote_file}")
        sftp.remove(remote_file)

        # Clean up the temp directory
        print("Cleaning up temp directory")
        for file in os.listdir(cwd):
            os.remove(cwd + file)
    else:
        print(f"Skipping file: {remote_file}")

print(f"Processed {i} files.")
sftp.close()
