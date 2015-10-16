#!/usr/bin/env python
# -- coding: utf-8 --

# This module was uploaded from
# https://github.com/ivanovmi/google-cli-tools/

import mimetypes
import googleapiclient
from googleapiclient.discovery import build
from oauth2client import tools
from oauth2client import client
from oauth2client import file
import os
import argparse
import oauth2client
import httplib2
import io
from apiclient import errors
from googleapiclient.http import MediaIoBaseDownload

APPLICATION_NAME = 'mcv_build_verifier'
CLIENT_SECRET_FILE = 'etc/client_secrets.json'
CREDENTIALS_PATH = 'etc/drive-api.json'
SCOPES = 'https://www.googleapis.com/auth/drive'


def authentication():
    flags = argparse.ArgumentParser(
        parents=[oauth2client.tools.argparser]).parse_args()
    home_dir = os.path.abspath('../../mcv_build_verifier')

    credential_dir = os.path.join(home_dir, 'etc/.credentials')

    if not os.path.exists(credential_dir):
        os.makedirs(credential_dir)

    store = oauth2client.file.Storage(CREDENTIALS_PATH)
    credentials = store.get()
    if not credentials or credentials.invalid:
        flow = oauth2client.client.flow_from_clientsecrets(
            CLIENT_SECRET_FILE, SCOPES)
        flow.user_agent = APPLICATION_NAME
        if flags:
            credentials = oauth2client.tools.run_flow(flow, store, flags)
        else:
            credentials = oauth2client.tools.run(flow, store)
        print 'Storing credentials to %s' % CREDENTIALS_PATH
    return credentials


def download_file(service, file_id, filename):
    """Download a Drive file's content to the local filesystem.
    Args:
        service: Drive API Service instance.
        file_id: ID of the Drive file that will downloaded.
        local_fd: io.Base or file object, the stream that the Drive file's
            contents will be written to.
    """
    local_fd = io.FileIO(unicode(filename), mode='a')
    request = service.files().get_media(fileId=file_id)
    media_request = MediaIoBaseDownload(local_fd, request)

    while True:
        try:
            download_progress, done = media_request.next_chunk()
        except errors.HttpError, error:
            print 'An error occurred: %s' % error
            return
        if download_progress:
            print 'Download Progress: %d%%' % int(download_progress.progress() * 100)
        if done:
            print 'Download Complete'
            return


def main(file_name):
    file_id = raw_input("Please enter image id: ")
    credentials = authentication()
    http = httplib2.Http()
    credentials.authorize(http)
    drive_service = googleapiclient.discovery.build('drive', 'v2', http=http)
    download_file(drive_service, unicode(file_id), unicode(file_name))
