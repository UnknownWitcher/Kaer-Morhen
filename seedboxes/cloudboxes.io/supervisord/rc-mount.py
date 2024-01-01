#!/usr/bin/env python3
import os
import sys
import yaml
import signal
import time
import argparse
import subprocess

from pathlib import Path

DEFAULT_CONF = Path(__file__).resolve().parent / 'rc-mount.yml'

parser = argparse.ArgumentParser(formatter_class=argparse.RawDescriptionHelpFormatter,
                                    description='Dropbox rclone mount script by unknown witcher',
                                    epilog=r'''
profile:
    films:
        source: "db-films:/media" (required)
        target: "/path/films"     (required)
        allow-other: True
        dir-cache-time: 9999h
        log-file: "/mnt/shared/logs/rclone/mount-films.log"
        log-level: "INFO"
        umask: "002"
        cache-dir: "/path/cache"
        vfs-cache-mode: "full"
        vfs-cache-max-size: "1000G"
        vfs-fast-fingerprint: True
        vfs-write-back: "24h"     (recommend)
        vfs-cache-max-age: "9999h"
        dropbox-batch-mode: "sync"
        dropbox-batch-size: 100
        dropbox-chunk-size: "128M"
        tpslimit: 12              (recommend)
        tpslimit-burst: 0         (recommend)
        config: "/config/rclone.conf"
        rc: True                  (required)
        rc-addr: "127.0.0.1:5574" (required)
        rc-user: "admin"          (required)
        rc-pass: "rclone"         (required)
''')

parser.add_argument('-c', '--conf', action='store',
                    nargs='?', type=argparse.FileType('r'),
                    default=DEFAULT_CONF, metavar='options.yaml',
                    help="File to parse mounting options from")
parser.add_argument('-p', '--profile', action='store', type=str,
                    help="Name of profile you want to mount/unmount",required=True)
parser.add_argument('-u', '--unmount', action='store_true',
                    help='Unmount only')
def Flock(profile):
    this_pid = int(os.getpid())
    last_pid = None
    path = Path(__file__).resolve().parent / f"{Path(__file__).stem}-{profile}.pid"
    try:
        for x in range(2):
            if path.exists():
                with open(path, 'r') as f:
                    last_pid=int(f.readline())
                    if this_pid != last_pid:
                        try:
                            os.kill(last_pid, 0)
                        except OSError:
                            pass # does not exist
                        else:
                            sys.exit(2)
                    else:
                        return
            with open(path, 'w', encoding='utf-8') as f:
                f.write(str(this_pid))
    except Exception as e:
        print(e)
        sys.exit(1)

def mount(data):
    if 'source' not in data or 'target' not in data:
        print("Source and Target are required in config.")
        sys.exit(2)
    if 'rc' not in data or 'rc-addr' not in data \
            or 'rc-user' not in data or 'rc-pass' not in data:
        print("rc, rc-addr, rc-user and rc-pass are required.")
        sys.exit(2)
    command = ["rclone", "mount", data['source'], data['target']]
    for d in data:
        if d == 'source' or d == 'target':
            continue
        dash = '-'
        if len(str(d)) > 1:
            dash = '--'
        if d == 'rc-addr' or d == 'rc-user' or  d == 'rc-pass':
            argument = f"{dash}{d}={data[d]}"
        else:
            argument = f"{dash}{d}" if isinstance(data[d],bool) else [f'{dash}{d}', f"{data[d]}"]

        if isinstance(argument,str):
            command.append(argument)
        else:
            command.extend(argument)

    subprocess.call(command)

    unmount(data['target'])
    
    sys.exit(1)

def unmount(target):
    try:
        if not Path(target).is_mount():
            return True
    except OSError as e:
        pass
        
    command = ('fusermount',  '-uz', target)
    umount = subprocess.Popen(command, stderr=subprocess.PIPE, stdout=subprocess.PIPE)
    umount.wait(30)
    err = umount.stderr.read()
    if 'not found in' in err.decode('utf-8'):
        return False
    if err.decode('utf-8') == '': # if no errors assume it was a success
        return True

if __name__ == '__main__':
    ARGS = parser.parse_args()
    if not Path(ARGS.conf).is_file:
        print(f"Failed to find config file '{ARGS.conf}'")
        sys.exit(1)
        
    Flock(ARGS.profile)

    with open(ARGS.conf,'r') as f:
        CONFIG_DATA = yaml.safe_load(f)
    PROFILE = CONFIG_DATA['profile'][ARGS.profile]

    def handle_exit(signum, frame):
        command = [
            'rclone',  'rc', 'core/quit'
            f"--rc-addr={PROFILE['rc-addr']}",
            f"--rc-user={PROFILE['rc-user']}",
            f"--rc-pass={PROFILE['rc-pass']}"
        ]
        try:
            proc = subprocess.call(command, stderr=subprocess.PIPE, stdout=subprocess.PIPE)
        except subprocess.CalledProcessError as error:
            pass
        else:
            unmount(PROFILE['target'])
        sys.exit(0)

    signal.signal(signal.SIGTERM, handle_exit)
    signal.signal(signal.SIGINT, handle_exit)
    
    unmount(PROFILE['target'])
    if not ARGS.unmount:
        mount(PROFILE)
