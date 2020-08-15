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

def get_password(user):
    """
get_password(user[str]) -> hash[str]

    Query for a password and return the corresponding hash.
"""
    while True:
        p1 = getpass.getpass(prompt=f'Password for {user}: ')
        p2 = getpass.getpass(prompt='Confirm password: ')
        if p1 == p2:
            return sha512_crypt.hash(p1)
        else:
            print('Passwords do not match, please try again.')

### --- ###

def get_email():
    """
get_password(user[str]) -> hash[str]

    Query for an email address.
"""
    while True:
        E1 = input("User's email address: ")
        E2 = input('Confirm email: ')
        if E1 == E2:
            return E1
        else:
            print('Emails do not match, please try again.')

### --- ###

def add_account():
    """
add_account()

    Add an account. Note that although case is preserved in user names
    it is ignored by "koi.py". Thus "aika" and "AIKA" user names are
    stored as such, but internally they are both "aika" (and hence they
    cannot co-exist). The logic behind this is for potential self-registration,
    particular if using email addresses, since users pay little attention
    to case. Note that groups are also internally lowercase.

"""
    print('\nAdding account')
    import re
    valid = re.compile(config.user_re)
    user = input('\nUser name: ')
    uid = hashlib.md5(user.lower().encode()).hexdigest()
    if uid in profiles:
        print('\nThat account already exists.\n')
        return
    if not valid.match(user):
        print('\nThat is not a valid user name.\n')
        return
    print (f'uid will be: {uid}')
    profile = {'user': user, 'uid': uid, 'token': '', \
               'nonce': '', 'xCSRF': '', 'data': {}, \
               'groups': [], 'roles': [], 'locked': False, \
               'login': None, 'logout': None, 'ip': None, \
               'koi_version': __version__, 'created': time.time()}
    name = ''
    hash = ''
    if platform.system() == 'Linux':
        if user in [i[0] for i in pwd.getpwall()]:
            print(f'\nUser "{user}" found on the system.')
            reuse = 'n'
            if getpass.getuser() == 'root':
                reuse = input("\nWould you like to import the user's \
shadow password and GECOS field [y/N]? ")
            else:
                print('Note that you can use the shadow password via \
copy/paste or by running this program as root.\n')
            if reuse.lower() == 'y':
                hash = spwd.getspnam(user).sp_pwdp
                name = pwd.getpwnam(user).pw_gecos
    if not name:
        name = input("User's real name: ")
    profile['name'] = name
    if not hash:
        hash = get_password(user)
    profile['hash'] = hash
    twoF = input('\nWould you like to register an email for 2-factor \
authenticaction [y/N]? ')
    if twoF.lower() == 'y':
        profile['2f_email'] = get_email()
    else:
        profile['2f_email'] = ''
    account_file_fp = os.path.join(config.dir_accounts_fp, uid+'.json')
    print(f'\nSaving "{user}" in {account_file_fp}')
    with open(account_file_fp, 'w', encoding='utf-8') as fd:
        json.dump(profile, fd, ensure_ascii=False)
    os.chmod(account_file_fp, 0o600)
    print('(make sure your web server can read this file)\n')
    return

### --- ###

def del_account():
    """
del_account()

    Delete an account.

"""
    print('\nDeleting account')
    user = input('\nUser name: ')
    uid = hashlib.md5(user.lower().encode()).hexdigest()
    if uid not in profiles:
        print('That account does not exist.\n')
        return
    account_file_fp = os.path.join(config.dir_accounts_fp, uid+'.json')
    go = input('\nAre you sure you want to delete the "{0}" account [y/N]? '.\
               format(user))
    if go.lower() == 'y':
        print(f'\nDeleting {account_file_fp}\n')
        bak_file = '{0}.{1}-{2}'.format(account_file_fp, 'removed', \
                                        int(time.time()))
        os.rename(account_file_fp, bak_file)
    else:
        print('\nOK, nothing was done.\n')
    return

### --- ###

def list_users():
    """
list_users()

    List koi users.

"""
    print(f'\nUser list from: {config.dir_accounts_fp}\n')
    if not profiles:
        print('\nNo users found.\n')
        return
    for uid, profile in profiles.items():
        print(f'{profile["user"]}: uid={uid}')
    while True:
        user = input('\nEnter a username for details (<enter> to quit): ')
        if not user:
            print('')
            break
        uid = hashlib.md5(user.lower().encode()).hexdigest()
        if profiles.get(uid, ''):
            print('')
            pprint.pprint(profiles[uid])
        else:
            print(f'User "{user}" does not exist.')
    return

### --- ###

def mod_account():
    """
mod_account()

    Modify an account.

"""
    print('\nModifying account')
    user = input('\nUser name: ')
    uid = hashlib.md5(user.lower().encode()).hexdigest()
    if uid not in profiles:
        print('That account does not exist.\n')
        return
    print(f'\nFull name: {profiles[uid]["name"]}')
    under = "="*len(profiles[uid]["name"])
    print(f'           {under}')
    while True:
        print('1) Full name')
        print('2) Groups')
        print('3) Lock account')
        print('4) Unlock account')
        print('5) Password')
        print('6) 2f email')
        print('7) Return')
        field = input('\nSelect field to change: ')
        if field in ['1', '2', '3', '4', '5', '6', '7']:
            break
        else:
            print("\nSorry, I don't understand.\n")
    if field == '1':
        name = input('\nFull name: ')
        profiles[uid]['name'] = name
    elif field == '2':
        print('\nNote that groups are case-insenstive, so "AV" and "av" are equivalent')
        print(f'Current groups: {" ".join(profiles[uid]["groups"])}')
        groups = input('Space-separated list of groups (<enter> for none): ')
        profiles[uid]['groups'] = [i.strip() for i in groups.split()]
    elif field == '3':
        profiles[uid]['locked'] = True
        kill = input('\nTerminate current session (if any) [y/N]? ')
        if kill.lower() == 'y':
            profiles[uid]['token'] = ''
            profiles[uid]['nonce'] = ''
            profiles[uid]['xCSRF'] = ''
    elif field == '4':
        profiles[uid]['locked'] = False
    elif field == '5':
        hash = get_password(user)
        profiles[uid]['hash'] = hash
    elif field == '6':
        email = get_email()
        profiles[uid]['2f_email'] = email
    else:
        return
    account_file_fp = os.path.join(config.dir_accounts_fp, uid+'.json')
    print(f'\nSaving {account_file_fp}\n')
    with open(account_file_fp, 'w', encoding='utf-8') as fd:
        json.dump(profiles[uid], fd, ensure_ascii=False)
    os.chmod(account_file_fp, 0o600)
    return

### --- ###

def batch_import():
    """
batch_import()

    Import accounts from /etc/passwd & /etc/shadow.

"""
    print('\nBatch import')
    if getpass.getuser() != 'root':
        print('You need to be root to access /etc/shadow\n')
        return
    uid_lim = input("Starting UID to import: ")
    print('If you have a "user email" two-column list for 2-factor please enter it below.')
    twoF_fp = input("2-factor email list path (<enter> for none): ")
    twoF_users = {}
    if twoF_fp:
        try:
            with open(twoF_fp, 'r') as fd:
                for line in fd:
                    (user, email) = line.strip().split()
                    twoF_users[user] = email
        except Exception as e:
            print(f'Unable to read email list, error is: {e}')
            return
    count = 0
    for entry in pwd.getpwall():
        uid = entry[2]
        if uid < int(uid_lim):
            continue
        user = entry[0]
        kuid = hashlib.md5(user.lower().encode()).hexdigest()
        if kuid in profiles:
            print(f'{user} account already exists, skipping.')
            continue
        email = ''
        if user in twoF_users:
            email = twoF_users[user]
        name = entry[4]
        hash = spwd.getspnam(user).sp_pwdp
        try:
            sha512_crypt.verify('', hash)
            locked = False
        except:
            print(f'{user} account does not use sha512_crypt, locking.')
            hash = sha512_crypt.hash(secrets.token_hex())
            locked = True
        profiles[kuid] = {'user': user, 'uid': kuid, 'token': '', \
                          'nonce': '', 'xCSRF': '', 'data': {}, \
                          'groups': [], 'roles': [], 'locked': locked, \
                          'login': None, 'logout': None, 'ip': None, \
                          'koi_version': __version__, 'created': time.time(), \
                          'hash': hash, '2f_email': email}
        account_file_fp = os.path.join(config.dir_accounts_fp, kuid+'.json')
        print(f'\nSaving "{user}" in {account_file_fp}\n')
        with open(account_file_fp, 'w', encoding='utf-8') as fd:
            json.dump(profiles[kuid], fd, ensure_ascii=False)
            os.chmod(account_file_fp, 0o600)
            count+=1
    print(f'Accounts created: {count}\n')
    return

### --- ###

def exit():
    raise SystemExit

### --- ###

if __name__ == '__main__':

    import config
    import glob
    import os
    import json
    import hashlib
    import pwd
    import spwd
    import pwd
    import getpass
    import platform
    import pprint
    import time
    import secrets
    from passlib.hash import sha512_crypt
    from koi import __version__

    options = {'1': ('Add account',        'add_account()' ),
               '2': ('Delete account',     'del_account()' ),
               '3': ('Modify account',     'mod_account()' ),
               '4': ('List users/account', 'list_users()'  ),
               '5': ('Batch import',       'batch_import()'),
               '6': ('Exit',               'exit()'        )}

    print('\nkoi account manager')
    print('===================\n')
    profiles = get_profiles()
    while True:
        for key, value in options.items():
            print(f'{key}) {value[0]}')
        n = input('\nSelection: ')
        try:
            eval(options[n][1])
            profiles = get_profiles()
        except KeyError:
            print("\nSorry, I don't understand.\n")
        except SystemExit:
            print('\nGoodbye')
            break
