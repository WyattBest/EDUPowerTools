from stat import S_ISREG
import pysftp

# This is intended to be called from Windows Task Scheduler.
# Download EOD file from server, place in appropriate folder, and delete from server.

# remote_dir = 'qa'
remote_dir = "prod"
dir_local = "\\\\<servername>\\c$\\NBSEODFiles\\"

# On Windows, server's public key must be in C:\Users\%username%\.ssh\known_hosts
with pysftp.Connection(
    "transfer.nbspayments.com",
    username="<FTP username>",
    private_key="<private key filename>",
    private_key_pass="<private key passphrase>",
) as sftp:
    sftp.chdir(remote_dir)

    # listdir. For each file, download file and remove server copy.
    for attr in sftp.listdir_attr():
        # Is this a file? (vs directory, named pipe, block device, or other weird object)
        if S_ISREG(attr.st_mode):
            sftp.get(
                remotepath=attr.filename,
                localpath=dir_local + attr.filename,
                preserve_mtime=True,
            )
            sftp.remove(attr.filename)
