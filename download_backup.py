#!/usr/bin/env python
# -*- coding: utf-8 -*-

import argparse
import json
import os
import sys

import requests
import tqdm


def list_files(token, backup_dir):
    headers = {
      "Authorization": "Bearer {}".format(token),
      "Content-Type": "application/json"
    }
    payload = {'path': backup_dir}
    res = requests.post('https://api.dropboxapi.com/2/files/list_folder',
                        headers=headers, data=json.dumps(payload))
    if res.status_code != 200:
        sys.stderr.write("Error\n")
        sys.stderr.write("{}\n".format(res.text))
        exit(-1)

    return json.loads(res.text)


def download(token, path, chunk_size=(1024 ** 2)):
    headers = {
      "Authorization": "Bearer {}".format(token),
      "Dropbox-API-Arg": json.dumps({"path": path})
    }
    res = requests.post('https://content.dropboxapi.com/2/files/download',
                        headers=headers, stream=True)
    if res.status_code != 200:
        sys.stderr.write("Download error\n")
        sys.stderr.write("{}\n".format(res.text))
        exit(-1)

    pbar = None
    content_len = int(res.headers.get('Content-Length', 0))
    if content_len:
        pbar = tqdm.tqdm(total=content_len, ncols=100)

    for chunk in res.iter_content(chunk_size=chunk_size):
        sys.stdout.buffer.write(chunk)
        if pbar:
            pbar.update(chunk_size)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('backup_dir')
    args = parser.parse_args()

    res = list_files(os.environ['DROPBOX_TOKEN'], args.backup_dir)
    paths = [ent['path_display'] for ent in res['entries']]
    paths = [path for path in paths if '.tar.gz' in path]
    paths = sorted(paths)

    sys.stderr.write("Found {} files\n".format(len(paths)))
    for path in paths:
        sys.stderr.write("Downloading {}\n".format(path))
        download(os.environ['DROPBOX_TOKEN'], path)


if __name__ == "__main__":
    main()
