#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
update docker_utils.sh
"""

from __future__ import print_function
import argparse
import sys
import os
import re
from datetime import datetime
import shutil


RELATIVE_SEARCH_PATH = '..'
SEARCH_FILE_NAME = 'docker_utils.sh'


script_path = os.path.realpath(sys.argv[0])
if os.path.isfile(script_path ):
    script_path  = os.path.dirname(script_path )


class ScriptException(Exception):
    """Derived exception to throw simple error messages"""


def get_args():
    parser = argparse.ArgumentParser(description = __doc__, formatter_class = argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('-u', '--update', action = 'store_true', help = 'copy latest over outdated files')
    args = parser.parse_args()

    return args


def find_scripts(path):
    file_list = []
    for name in os.listdir(path):
        dir_name = os.path.join(path, name)
        if os.path.isdir(dir_name):
            file_name = os.path.join(dir_name, SEARCH_FILE_NAME)
            if os.path.isfile(file_name):
                file_list.append(file_name)

    return file_list


def get_file_version(file_name):
    with open(file_name, 'r') as file_object:
        for line in file_object:
            match = re.search('^# (?P<year>\d{4})-(?P<month>\d{2})-(?P<day>\d{2}) (?P<hour>\d{2}):(?P<minute>\d{2})', line)
            if match:
                match_info = match.groupdict()
                return datetime(
                    int(match_info['year']),
                    int(match_info['month']),
                    int(match_info['day']),
                    int(match_info['hour']),
                    int(match_info['minute']),
                )

    return None


def get_latest_file(file_list):
    latest_file = None
    latest_version = None

    matched_list = []
    for file_name in file_list:
        file_version = get_file_version(file_name)
        if not latest_version or (file_version and file_version > latest_version):
            latest_file = file_name
            latest_version = file_version

        elif latest_version and latest_version == file_version:
            matched_list.append(file_name)

    for file_name in matched_list:
        file_list.remove(file_name)

    return latest_file


def do_docker_utils_update():
    args = get_args()

    base_path = os.path.abspath(os.path.join(script_path, RELATIVE_SEARCH_PATH))
    file_list = find_scripts(base_path)
    file_name = get_latest_file(file_list)
    if not file_name:
        raise ScriptException('unable to determine latest file')

    print('latest: {}'.format(file_name))

    file_list.remove(file_name)
    if file_list:
        if args.update:
            print('updating:-')
            for outdated_name in file_list:
                shutil.copyfile(file_name, outdated_name)
                print('  {}'.format(outdated_name))

        else:
            print('outdated:-')
            for outdated_name in file_list:
                print('  {}'.format(outdated_name))


if __name__ == "__main__":
    try:
        do_docker_utils_update()

    except Exception as e:
        print('Error:{}: {}'.format(e.__class__.__name__, e), file = sys.stderr)
        sys.exit(1)

    except KeyboardInterrupt:
        pass
