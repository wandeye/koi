#!/usr/bin/python3

### --- ###

def get_profiles():
    """
get_profiles() -> profiles[dict]

    Read all JSON profiles into a dictionary. Each dictionary
    key corresponds to a user's name.
"""
    profiles = {}
    for i in glob.glob(os.path.join(config.dir_accounts_fp, '*.json')):
        with open(i, 'r', encoding='utf-8') as fd:
            data = json.load(fd)
        if not data.get('koi_version', ''): continue
        profiles[data['uid']] = data
    return profiles

### --- ###

def get_acl(users, plain):
    """
get_acl(users[str], plain[bool]) -> acl_users[list]

    An ACL of valid users. If "plain" is "True" no wilcards or
blocked users are allowed.
"""
    acl_users = []
    if users == '**':
        if plain:
            print(f'Wildcards not allowed, skipping.')
        else:
            acl_users = '*'
    else:
        acl_users = []
        users = [i.strip().lower() for i in users.split()]
        for i in users:
            if i == '*':
                if plain:
                    print(f'Wildcards not allowed, skipping.')
                else:
                    acl_users.append(i)
                continue
            if i[0] == '!':
                if plain:
                    print(f'Blocks not allowed, skipping.')
                    continue
                else:
                    uid = hashlib.md5(i[1:].encode()).hexdigest()
            else:
                uid = hashlib.md5(i.encode()).hexdigest()
            if uid not in profiles:
                print(f'User "{i}" does not exist, skipping.')
            else:
                acl_users.append(i)
    return acl_users

### --- ###

if __name__ == '__main__':

    import config
    import time
    import json
    import hashlib
    import datetime
    import pprint
    import glob
    import os
    import socket

    print('\nPage ACL editor')
    print('===============\n')

    koi_file = input('koi file: ')
    with open(koi_file, 'r', encoding='utf-8') as fd:
        koi_data = json.load(fd)

    print('\nPress <enter> to leave an entry unmodified, or Ctrl-C to quit.')
    print('Lists are space-separated, user names are case insensitive.\n')

    top = os.path.basename(koi_file)
    if 'acl' not  in koi_data:
        print('No ACL found, creating from scratch')
        koi_data['acl'] = {}
        koi_data['acl'][top] = {'users': [], 'groups': [], 'ips': [], 'time': 0}
    else:
        pprint.pprint(koi_data['acl'])
    while True:
        item = input(f'\nACL to manipulate (<enter> for "{top}"): ')
        if not item:
            item = top
            break
        elif item not in koi_data['acl']:
            print("Sorry, that ACL is not there")
        else:
            break
    ACL = koi_data['acl'][item]

    print(f'\nCurrent ACL for "{item}":\n')
    pprint.pprint(ACL)
    editable = False
    if item == top and koi_data.get('editors', ''):
        editable = True
        print(f'\nEditors: {koi_data["editors"]}')

    profiles = get_profiles()

    print('\nUse "**" for anyone, "*" for logged-in users.')
    if ACL['users'] == '*':
        print(f'User access list: **')
    else:
        print(f'User access list: {" ".join(ACL["users"])}')
    users = input('New access list: ')
    if not users:
        print('Will not change')
        acl_users = ACL['users']
    else:
        acl_users = get_acl(users, plain=False)
    ACL['users'] = acl_users

    print(f'\nGroups access list: {" ".join(ACL["groups"])}')
    groups = input('New access list: ')
    if not groups:
        print('Will not change')
        acl_groups = ACL['groups']
    else:
        acl_groups = [i.strip() for i in groups.split()]
    ACL['groups'] = acl_groups

    print('\nUse "**" for anywhere')
    if ACL['ips'] == '*':
        print(f'\nIP access list: **')
    else:
        print(f'\nIP access list: {" ".join(ACL["ips"])}')
    ips = input('New access list: ')
    if not ips:
        print('Will not change')
        acl_ips = ACL['ips']
    elif ips == '**':
        acl_ips = '*'
    else:
        acl_ips = []
        ips = [i.strip() for i in ips.split()]
        for i in ips:
            try:
                if i[0] == '!':
                    socket.inet_aton(i[1:])
                else:
                    socket.inet_aton(i)
                acl_ips.append(i)
            except:
                print(f'IP/subnet "{i}" is invalid, skipping.')
    ACL['ips'] = acl_ips

    clock_format = '%Y-%m-%dT%H:%M'
    if ACL['time']:
        release = datetime.datetime.\
            fromtimestamp(ACL['time']).strftime(clock_format)
    else:
        release = 0
        acl_time = 0
    print(f'\nRelease date-time: {release}')
    release = input('New release time (use "0" for any time, else yyyy-mm-ddThh:mm): ')
    if not release:
        print('Will not change')
        acl_time = ACL['time']
    elif release == '0':
        acl_time = 0
    else:
        try:
            acl_time = int(time.mktime(time.strptime(release, clock_format)))
        except:
            print(f'Date-time "{release}" is invalid, skipping.')
    ACL['time'] = acl_time

    if editable:
        print(f'\nEditor list: {" ".join(koi_data["editors"])}')
        editors = input('New editor list: ')
        if not editors:
            print('Will not change')
            acl_editors = koi_data["editors"]
        else:
            acl_editors = get_acl(editors, plain=True)
        koi_data['editors'] = acl_editors

       # if 'editor_groups' in koi_data:
       #     print('\nNote: editor groups are not supported by the article editor')
       #     print(f'Editor groups list: {" ".join(koi_data["editor_groups"])}')
       #     editor_groups = input('New editor groups list: ')
       #     if not editor_groups:
       #         acl_editor_groups = koi_data["editor_groups"]
       #     else:
       #         acl_editor_groups = [i.strip() for i in editor_groups.split()]
       #     koi_data['editor_groups'] = acl_editor_groups

    if 'trusted' in koi_data:
        print(f'\nTrust (arbitrary HTML allowed) is: {koi_data["trusted"]}')
        trusted = input('Trusted [y/N]? ')
        if not trusted:
            print('Will not change')
            pass
        elif trusted.lower() == 'y':
            koi_data['trusted'] = True
        else:
            koi_data['trusted'] = False

    if 'timestamp' in koi_data:
        koi_data['timestamp'] = time.time()

    koi_data['acl'][item] = ACL

    with open(koi_file, 'w', encoding='utf-8') as fd:
        json.dump(koi_data, fd, ensure_ascii=False)
    os.chmod(koi_file, 0o600)

    print(f'\nThe "{item}" ACL of "{koi_file}" has been updated and is now:\n')
    pprint.pprint(ACL)
    if editable:
        print(f'Editors: {koi_data["editors"]}')
        # print(f'Editor groups: {koi_data.get("editor_groups", "")}\n')
    if 'trusted' in koi_data:
        print(f'Trusted: {koi_data["trusted"]}\n')
