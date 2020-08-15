#!/usr/bin/python3
"""
Koi is a Python-based CMS.

Koi uses a flat-file database to organize content stored in "koi"
files (which contain the page data in JSON format). It was developed
using Python 3.8.2+ and support for earlier versions is unknown.

To install, download from https://reimeika.ca and uncompress koi.zip
(this creates a new directory koi/). From a terminal, change into the
new directory and run ./koi.py. You can then go to:

http://localhost:8080

to start using the CMS.

Marco De la Cruz-Heredia (marco@reimeika.ca)
License: 3-clause BSD (see below)

Copyright (c) 2020, Marco De la Cruz-Heredia.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the author nor the names of its contributors
      may be used to endorse or promote products derived from this software
      without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

"""

__author__ = 'Marco De la Cruz-Heredia'
__version__ = '0.1'
__license__ = '3-clause BSD'

### --- ###

import sys
import os
import logging
import glob
import json
import time
import tempfile
import secrets
import re
import hashlib
import random
import socket
import smtplib
from email.message import EmailMessage

try:
    import bottle
    import config
except Exception as e:
    print(f'CRITICAL: koi: : cannot import required module [{e}]')
    raise SystemExit

# std_out goes to error_log, see:
# http://code.google.com/p/modwsgi/wiki/ApplicationIssues
logging.basicConfig(format=config.logformat,
                    level=getattr(logging, config.loglevel))

# https://stackoverflow.com/questions/61517/python-dictionary-from-an-objects-fields
CONFIG = dict((key, value) for key, value in config.__dict__.items() \
              if not key.startswith('__'))
CONFIG['koi_version'] = __version__

pyver = sys.version_info
if pyver < (3, 8, 2):
    logging.error('unsupported python version, 3.8.2+ required')

if len(config.session_cookie_sig) < 32:
    logging.critical('invalid session_cookie_sig')
    raise SystemExit

try:
    # By using "sha512_crypt" we can use shadow hashes
    from passlib.hash import sha512_crypt
    auth = True
except Exception as e:
    msg = f'could not import passlib, sessions/authentication disabled [{e}]'
    logging.error(msg)
    auth = False

koipy_file_fp = os.path.realpath(os.path.dirname(__file__))

logging.info(f'python version {pyver}')
logging.info(f'bottle version {bottle.__version__}')
logging.info(f'koi version {__version__}')
logging.debug(f'config is "{CONFIG}"')
logging.debug(f'koi.py path is "{koipy_file_fp}"')
if auth:
    logging.debug('sessions/authentication enabled')

template_dir_fp = os.path.join(koipy_file_fp, config.dir_templates)
logging.debug(f'template path is "{template_dir_fp}"')
bottle.TEMPLATE_PATH.append(template_dir_fp)

if config.dir_tmp:
    logging.debug(f'setting temp dir to "{config.dir_tmp}"')
    tempfile.tempdir = config.dir_tmp

### --- ###

# https://en.wikipedia.org/wiki/List_of_HTTP_status_codes
@bottle.error(400)
def error400(error):
    """Bad Request"""
    logging.warning(f'[400 err] {error.body}')
    return bottle.template(config.tpl_error, \
                           CODE=400, \
                           DETAILS=error.body, \
                           CONFIG=CONFIG)

@bottle.error(403)
def error403(error):
    """Forbidden"""
    logging.debug(f'[403 err] {error.body}')
    return bottle.template(config.tpl_error, \
                           CODE=403, \
                           DETAILS=error.body, \
                           CONFIG=CONFIG)

@bottle.error(404)
def error404(error):
    """Not Found"""
    logging.debug(f'[404 err] {error.body}')
    return bottle.template(config.tpl_error, \
                           CODE=404, \
                           DETAILS=error.body, \
                           CONFIG=CONFIG)

@bottle.error(413)
def error413(error):
    """Payload Too Large"""
    logging.warning(f'[413 err] {error.body}')
    return bottle.template(config.tpl_error, \
                           CODE=413, \
                           DETAILS=error.body, \
                           CONFIG=CONFIG)

@bottle.error(500)
def error500(error):
    """Internal Server Error"""
    logging.critical(f'[500 err] {error.body}')
    return bottle.template(config.tpl_error, \
                           CODE=500, \
                           DETAILS=error.body, \
                           CONFIG=CONFIG)

### --- ###

def json_io(file, action, fatal, data=''):
    """
json_io(file[str], action[str], fatal[bool], data[str]='') -> data[str]
                                                           -> [HTTPResponse]

    Read or write data from/to a JSON file depending on whether "action" is
    "r" or "w". If "fatal" is True a 500 error will be raised. File data is
    returned on a read, an empty string if a write.

"""
    msg = f'executing "json_io({file}, {action}, {fatal}, <data>)"'
    logging.debug(msg)

    if action == "r":
        try:
            with open(file, "r", encoding='utf-8') as fd:
                data = json.load(fd)
        except Exception as e:
            msg = f'unable to load JSON file "{file}" [{e}]'
            logging.error(msg)
            if fatal:
                raise bottle.HTTPError(500, 'error opening file')
    elif action == "w":
        # We write the JSON file into a temp file:
        # https://security.openstack.org/guidelines/dg_using-temporary-files-securely.html
        # and then copy it to its final destination. Using "json.dump()" directly can
        # corrupt the file if the device runs out of space, hence the first dump and the
        # subsequent copy.
        try:
            logging.debug(f'will write JSON file "{file}"')
            # "dir" assures the file is created on the same file system
            # where "file" resides.
            (fd, tmpfile) = tempfile.mkstemp(dir=os.path.dirname(file))
            with os.fdopen(fd, 'w', encoding='utf8') as tmp:
                tmp.write(json.dumps(data, ensure_ascii=False))
            # The "replace" operation is atomic.
            logging.debug(f'moving "{tmpfile}" to "{file}"')
            os.replace(tmpfile, file)
            data = ''
        except Exception as e:
            msg = f'unable to write JSON file "{file}" [{e}]'
            logging.error(msg)
            if fatal:
                raise bottle.HTTPError(500, 'error writing file')
        finally:
            if os.path.isfile(tmpfile):
                os.remove(tmpfile)
    else:
        raise ValueError

    return data

### --- ###

def index_pages(pages_dir_fp):
    """
index_pages(pages_dir_fp[str]) -> (index[dict], tree[dict])

    Create an index of the site. Structure is:

    index[page1] = {'key1': 'value1', 'key2': 'value2'... }
    index[page2] = {'keyA': 'valueA', 'keyB': 'valueB'... }
    :

    where e.g. "key1" is "title" ("value1" is the actual title),
    "key2" is "date" ("value2" is the publication date), etc.
    "pageN" is the N-th directory under "config.dir_pages" in which
    a .koi file resides.

    In addition, create a site tree as so:

    tree[page1] = {'path': <path to page>,
                   'template': <koi template>,
                   'uri': <page URI>,
                   'files': <list of files under 'path'>}
    :

    Note that ACLs are ignored for indexing purposes.

"""
    logging.debug(f'executing "index_pages({pages_dir_fp})"')

    index = {}
    tree = {}
    # A koi_file is e.g.:
    #
    #                page
    #                ,--,
    # /www/koi/pages/main/article.koi
    # `------------------'`-----'
    #        path         template
    #
    # uri = /pages/main
    for koi_file in glob.glob(os.path.join(pages_dir_fp, '*/*.koi')):
        path = os.path.dirname(koi_file)
        files = [os.path.basename(i) for i in \
                 glob.glob(os.path.join(path, '*'))]
        template = os.path.splitext(os.path.basename(koi_file))[0]
        page = os.path.basename(path)
        uri = f'/{config.dir_pages}/{page}'
        index[page] = json_io(koi_file, action='r', fatal=False)
        tree[page] = {'path': path, 'template': template, \
                      'uri': uri, 'files': files}

    return (index, tree)

### --- ###

def index_users():
    """
index_users() -> users[dict]

    Create an index of all user profiles.

"""
    logging.debug('executing "index_users()"')

    users = {}
    for account_file in glob.glob(os.path.join(config.dir_accounts_fp, \
                                               '*.json')):
        user_data = json_io(account_file, action='r', fatal=False)
        # If the JSON file has no "koi_version" field it's not a koi user.
        if not user_data or not user_data.get('koi_version', ''):
            continue
        else:
            users[user_data['user']] = user_data

    return users

### --- ###

def check_os_access(pages_dir_fp, page, file):
    """
check_os_access(pages_dir_fp[str], page[str], file[str])
                   -> (request_page[str], request_file[str], koi_file[str])
                   -> [HTTPResponse]

    Check OS-level access to the page (e.g. read permissions) and
    other potential issues or configurations which forbid serving
    the request (raising the appropriate HTTP response). If the
    request is feasible return the full path to the requested
    page, the requested file (these two being the same if a page
    is requested), and the full path to the .koi file.

"""
    msg = f'executing "check_os_access({pages_dir_fp}, {page}, {file})"'
    logging.debug(msg)

    request_page_fp = os.path.realpath(os.path.join(pages_dir_fp, page))
    request_file_fp = os.path.realpath(os.path.join(request_page_fp, file))

    # If file = '' then request_page_fp and request_file_fp are the same
    logging.debug(f'requested "{request_file_fp}"')

    if not request_file_fp.startswith(pages_dir_fp):
        msg = 'will not serve request, possible path traversal'
        raise bottle.HTTPError(400, msg)

    if config.force_ssl and \
       bottle.request.environ.get('wsgi.url_scheme') != 'https':
        msg = 'force_ssl set, will not serve unencrypted'
        raise bottle.HTTPError(403, msg)

    if page.startswith(config.noserve_prefix) or \
       file.startswith(config.noserve_prefix):
        msg = 'will not serve due to noserve_prefix'
        raise bottle.HTTPError(403, msg)

    if page.endswith(config.noserve_suffix) or \
       file.endswith(config.noserve_suffix):
        msg = 'will not serve due to noserve_suffix'
        raise bottle.HTTPError(403, msg)

    if page and not os.path.isdir(request_page_fp):
        msg = 'page not found'
        raise bottle.HTTPError(404, msg)

    if file and not os.path.isfile(request_file_fp):
        msg = 'file not found'
        raise bottle.HTTPError(404, msg)

    if not os.access(request_file_fp, os.R_OK):
        msg = 'missing or no read access to page or file'
        raise bottle.HTTPError(403, msg)

    koi_file = glob.glob(os.path.join(request_page_fp, '*.koi'))

    if len(koi_file) == 0:
        msg = 'no .koi file found'
        raise bottle.HTTPError(403, msg)
    elif len(koi_file) > 1:
        msg = f'multiple .koi files found "{koi_file}"'
        logging.warning(msg)
        raise bottle.HTTPError(403, 'multiple .koi files found')
    else:
        koi_file = koi_file[0]
        logging.debug(f'found "{koi_file}"')

    if file == os.path.basename(koi_file):
        msg = 'will not serve the .koi file'
        raise bottle.HTTPError(403, msg)

    if not os.access(koi_file, os.R_OK):
        msg = '.koi file is unreadable'
        raise bottle.HTTPError(403, msg)

    return (request_page_fp, request_file_fp, koi_file)

### --- ###

def generate_token(uid):
    """
generate_token(uid[str]) -> token[str]

    Generate a token.

"""
    logging.debug(f'executing "generate_token({uid})"')

    token = ':'.join([uid, \
                      bottle.request.environ.get('REMOTE_ADDR'), \
                      f'{int(time.time())}', \
                      secrets.token_hex()])
    logging.debug(f'generated token "{token}"')

    return token

### --- ###

def validate_token(token):
    """
validate_token(token[str]) -> profile[dict]
                          -> [HTTPResponse]

    Return the user's profile, otherwise raises an HTTP error if the
    token is invalid (profile dictionary is empty if no token is found
    or expired).

    Expired tokens are expected so no error is raised, but invalid
    ones are suspect.

"""
    logging.debug(f'executing "validate_token({token})"')

    if token:
        try:
            (uid, ip, ts, sig) = token.split(':')
            if not uid.isalnum(): raise ValueError
            socket.inet_aton(ip)
            int(ts)
        except Exception as e:
            logging.warning(f'invalid token "{token}" [{e}]')
            raise bottle.HTTPError(400, 'invalid token')

        account_file_fp = os.path.join(config.dir_accounts_fp, uid+'.json')
        profile = json_io(account_file_fp, action='r', fatal=True)

        if not secrets.compare_digest(profile['token'], token):
            msg = f'invalid token "{token}" (expected "{profile["token"]}")'
            logging.warning(msg)
            profile['token'] = ''
            json_io(account_file_fp, action='w', fatal=True, data=profile)
            raise bottle.HTTPError(403, 'invalid token')

        req_ip = bottle.request.environ.get('REMOTE_ADDR')
        if req_ip != ip and not config.session_allow_roaming:
            logging.warning(f'invalid IP "{req_ip}" (expected "{ip}")')
            profile['token'] = ''
            json_io(account_file_fp, action='w', fatal=True, data=profile)
            raise bottle.HTTPError(403, 'invalid token')

        age = time.time()-int(ts)
        if age > config.session_timeout:
            msg = f'token expired {int(age-config.session_timeout)}s ago'
            logging.debug(msg)
            profile['token'] = ''
            json_io(account_file_fp, action='w', fatal=True, data=profile)
    else:
        profile = {}

    return profile

### --- ###

def check_acl_access(template, file, koi_data, token):
    """
check_acl_access(template[str], file[str], koi_data[dict], token[str])
                                                     -> profile[str]
                                                     -> [HTTPResponse]

    Returns a profile dictionary (in which case the page or file can
    be served), or an HTTPResponse if the token is not valid or the
    page/file will not be served due to an ACL. If no session is
    ongoing the profile is an empty dictionary.

    An ACL is an entry in the .koi file with the following structure:

      acl = {'item1': {
                       'users': ['u1', 'u2', 'u3'],
                       'groups': ['gA', 'gB']
                       'ips':   ['ip1', 'ip2'],
                       'time':  epoch},
             'item2': {...} ... }}

    where each item is a serve-able file within the page. If the file is
    the "<template>.koi" file (which never gets served) its ACL is
    effectively that of the entire page and its contents (which inherit
    these permissions unless they are explicity stated e.g. "item2").
    The ACL controls who can access based on a user list, and IP
    address list, or a timestamp (in unix time) before which the request
    will not be granted. "users" and "ips" allow for wildcards ("0" in
    the case of the timestamp). Prepending a "!" to a user, group, or
    IP/subnet blocks the request (these supercede "allow" pemissions
    and override subsets i.e. a user can be denied but the rest of their
    group allowed, but once the group is denied explicitly allowing
    a user from the group will not grant access permissions - same for
    networks, IPs within an allowed subnet can be restricted, but once
    a subnet is blocked individual IPs within cannot be allowed access).

    If "groups" is not empty and the visitor (if logged in) belongs
    to one of the groups they gain the same access rights as if they
    were in the "users" list. Wildcards are not used by "groups".

    If "users" is "*" the "ips" and "time" restrictions will apply to
    visitors who are not logged in. If "*" is present in the "users"
    list (say, as ['*']) then any logged-in user can access the item
    (but still subject to the other restrictions).

    Examples:

    Allow full access to anyone, from anywhere, at any time, to the
    page and the all files in the page directory (this is equivalent
    of having no ACL entry at all):

    acl = {'article.koi': {'users': '*', 'groups': [], 'ips': '*',
                           'time': 0}}

    Same as above but only logged-in users can access the page and
    files within:

    acl = {'article.koi': {'users': ['*'], 'groups': [], 'ips': '*',
                           'time': 0}}

    Note that ['*'] makes no sense for "ips". Also, the presence
    of "*" in the "users" list supercedes the presence of any other
    users i.e. ['*', 'joe', 'ana'] and ['*'] are equivalent.

    Suppose the page "/private" uses a template called "mine".
    Only give "nao" access to "/private" (and files therein) from
    192.168.2.1 at any time:

    acl = {'mine.koi': {'users': ['nao'], 'groups': [],
                        'ips': ['192.168.2.1'], 'time': 0}}

    As above, but only giving access to all those in group "av"
    except for aika:

    acl = {'mine.koi': {'users': ['!aika'], 'groups': ['av'],
                        'ips': ['192.168.2.1'], 'time': 0}}

    Give all users access to "/preview" from Tue, Jun 23, 2020 15:58:31DST,
    but only allow "ゆま" and "sora" to download "final.pdf" anytime from
    the "127.0" subnet:

    acl = {'preview.koi': {'users': '*', groups: [], 'ips': '*',
                           'time': 1592942311},
           'final.pdf': {'users': ['ゆま', 'sora'], groups: [],
                         'ips': ['127.0'], 'time': 0}}

    Other files under "/preview" inherit the "preview.koi" ACL i.e. full
    access starting from Jun 23, 2020 15:58:31DST in this case.

"""
    fn = f'check_acl_access({template}, {file}, <koi_data>, {token})'
    logging.debug(f'executing "{fn}"')

    profile = validate_token(token)

    if profile.get('nonce', ''):
        logging.warning(f'attempt to bypass 2-factor by "{profile["user"]}"')
        raise bottle.HTTPError(403, 'security violation detected')

    template = template+'.koi'
    if not (acl := koi_data.get('acl', {})):
        logging.debug('no ACL found')
        return profile
    elif template not in acl:
        msg = 'improperly formed ACL'
        logging.error(msg)
        raise bottle.HTTPError(403, msg)
    else:
        logging.debug('processing ACL')

    if not (item := file):
        item = template

    # Files not in the ACL inherit the global ACL.
    if file and file not in acl:
        acl[file] = acl[template]

    logging.debug(f'ACL restrictions for "{item}" are "{acl[item]}"')
    logging.debug(f'access requested by "{profile.get("user", "<NOLOGIN>")}"')
    serve = True
    # All checks below are processed since negating a serve is irreversible.
    blocked_users = [i[1:].lower() for i in acl[item]['users'] \
                     if i[0] == '!']
    blocked_groups = [i[1:].lower() for i in acl[item]['groups'] \
                      if i[0] == '!']
    if profile.get('token', ''):
        profile_groups = [i.lower() for i in profile['groups']]
        if profile['user'].lower() in blocked_users:
            msg = 'access denied to the user'
            serve = False
        if set(profile_groups).intersection(set(blocked_groups)):
            msg = 'access denied to the group'
            serve = False
    ip = bottle.request.environ.get('REMOTE_ADDR')
    blocked_ips = [i[1:] for i in acl[item]['ips'] if i[0] == '!']
    if ip in blocked_ips or any(ip.startswith(i) for i in blocked_ips):
        msg = 'access denied from your IP/subnet'
        serve = False
    if acl[item]['users'] != '*':
        allowed_users = [i.lower() for i in acl[item]['users'] if i[0] != '!']
    else:
        allowed_users = '*'
    allowed_groups = [i.lower() for i in acl[item]['groups'] if i[0] != '!']
    if acl[item]['ips'] != '*':
        allowed_ips = [i for i in acl[item]['ips'] if i[0] != '!']
    else:
        allowed_ips = '*'
    if profile.get('token', ''):
        # Having group access is equivalent to explicitly allowing the user.
        if allowed_groups and \
           set(profile_groups).intersection(set(allowed_groups)):
            allowed_users = [profile['user'].lower()]
    # We raise here so that subsequent checks can rely on an active session.
    if allowed_users != '*' and not profile.get('token', ''):
        msg = 'invalid token'
        raise bottle.HTTPError(403, msg)
    # Having '*' in the allowed user list is equivalent to having
    # explicitly allowed the user.
    if allowed_users != '*' and '*' in allowed_users:
        allowed_users = [profile['user'].lower()]
    # https://en.wikipedia.org/wiki/De_Morgan%27s_laws
    if not (allowed_users == '*' or \
            profile['user'].lower() in allowed_users):
        msg = 'user is not allowed to access item'
        serve = False
    if not (allowed_ips == '*' or \
            any(ip.startswith(i) for i in allowed_ips)):
        msg = 'cannot access item from your IP/subnet'
        serve = False
    if not (acl[item]['time'] == 0 or time.time() > acl[item]['time']):
        msg = 'item has not yet been released'
        serve = False
    if not serve:
        raise bottle.HTTPError(403, msg)

    return profile

### --- ###

def get_upload(up_request):
    """
get_upload(up_request[bottle.FileUpload]) -> upload[dict]

    Process a bottle.FileUpload instance and retrieve the
    upload. If the upload is successful returns an "upload"
    dictionary containing the keys "OK" (boolean), "status",
    "content_type", "raw_filename", "safe_name", and
    "file_data" (whose value is a binary string containing
    the uploaded file). If the upload is not successful due
    to exceeding the upload size (config.upload_max_size)
    then "OK" is "False" and "file_data" is truncated.

    See also:
    http://bottlepy.org/docs/0.12/api.html#bottle.FileUpload

"""
    logging.debug('executing "get_upload(<bottle.FileUpload>)"')

    punctuation = re.compile(r'[^a-zA-Z0-9][^a-zA-Z0-9_-]*')
    upload = {}
    data_blocks = []
    byte_count = 0
    msg = 'receiving "{0}" file "{1}"'.\
        format(up_request.content_type, up_request.raw_filename)
    logging.debug(msg)
    upload['OK'] = True
    upload['status'] = 'upload successful'
    # We load it manually to monitor file size.
    while buf := up_request.file.read(config.upload_chunk_size):
        byte_count += len(buf)
        if byte_count > config.upload_max_size:
            upload['OK'] = False
            msg = f'upload exceeds {config.upload_max_size} bytes'
            upload['status'] = msg
            break
        data_blocks.append(buf)
    upload['content_type'] = up_request.content_type
    upload['raw_filename'] = up_request.raw_filename
    raw = os.path.splitext(upload['raw_filename'])
    # Remove any non alphanumeric characters from the file name
    # (but keep the file extension, if any). Also limit the total
    # file name length.
    safe_name = [punctuation.sub('', raw[0][:200]), \
                 punctuation.sub('', raw[1][1:10])]
    if not safe_name[0]:
        safe_name[0] = f'null-{int(time.time())}'
    if not safe_name[1]:
        safe_name[1] = 'null'
    upload['safe_name'] = '.'.join(safe_name)
    logging.debug(f'"upload" ("file_data" not shown) is "{upload}"')
    upload['file_data'] = b''.join(data_blocks)
    logging.debug(f'uploaded {len(upload["file_data"])} bytes')

    return upload

### --- ###

def email_nonce(email):
    """
email_nonce(email[str]) -> nonce[int]

    Create a nonce and email it to the user for two-factor authentication.

"""
    logging.debug(f'executing "email_nonce({email})"')

    nonce = random.randint(1000000, 9999999)
    try:
        em = EmailMessage()
        em['Subject'] = config.twoF_subject
        em['From'] = config.twoF_from
        em['To'] = email
        em.set_content(config.twoF_msg.format(nonce=nonce))
        es = smtplib.SMTP(host=config.smtp_server, port=config.smtp_port)
        msg = 'sending 2-factor email to "{0}" via "{1}:{2}"'.\
            format(email, config.smtp_server, config.smtp_port)
        logging.debug(msg)
        if config.smtp_TLS:
            es.ehlo()
            es.starttls()
            es.ehlo()
        if config.smtp_login:
            logging.debug(f'SMTP auth as "{config.smtp_login}"')
            es.login(config.smtp_login, config.smtp_passwd)
        es.send_message(em)
        es.quit()
    except Exception as e:
        logging.debug(f'error sending 2-factor email [{e}]')
        raise bottle.HTTPError(500, 'cannot authenticate')

    return nonce

### --- ###

def session(query):
    """
session(query[dict]) -> (err[str], profile[dict])
                     -> [HTTPResponse]

    Session handling function for login, logout, 2F and CSRF. Returns
    the profile (if possible) and an error string (if any occur,
    otherwise the string is empty).

"""
    logging.debug('executing "session(<query>)"')

    if not auth:
        raise bottle.HTTPError(400, 'cannot authenticate for sessions')

    if bottle.request.environ.get('wsgi.url_scheme') != 'https' and \
       config.loglevel != 'DEBUG':
        msg = 'non-encrypted login not allowed unless in DEBUG mode'
        raise bottle.HTTPError(403, msg)

    err = ''
    profile = {}
    action = query.get('action', '')
    token = bottle.request.get_cookie("token", \
                                      secret=config.session_cookie_sig)

    if not action:
        # Just display the page on the initial visit and do nothing else.
        return (err, profile)
    elif action not in ['login', 'logout', 'chknonce']:
        logging.warning(f'unknown session action "{action}"')
        raise bottle.HTTPError(400, 'unknown action')

    logging.debug(f'processing session action "{action}"')

    if action == 'login':
        user = query.get('user', '')
        password = query.get('password', '')

        logging.debug(f'login attempt by user "{user}"')

        # All information submitted should be enforced by the form
        # client-side, so if anything is missing we end it here.
        if not user or not password:
            raise bottle.HTTPError(400, 'bad login request')

        # Internally all users names are lowercase
        uid = hashlib.md5(user.lower().encode()).hexdigest()
        account_file_fp = os.path.join(config.dir_accounts_fp, uid+'.json')
        logging.debug(f'seeking "{user}" profile at "{account_file_fp}"')
        if not os.path.isfile(account_file_fp):
            err = 'incorrect credentials'
            return (err, profile)

        profile = json_io(account_file_fp, action='r', fatal=True)

        if not sha512_crypt.verify(password, profile['hash']):
            err = 'incorrect credentials'
            return (err, profile)

        if profile['locked']:
            err = 'account is locked'
            return (err, profile)

        if profile['2f_email']:
            profile['nonce'] = email_nonce(profile['2f_email'])
        else:
            profile['ip'] = bottle.request.environ.get('REMOTE_ADDR')
            profile['login'] = int(time.time())

        profile['token'] = generate_token(uid)
        profile['xCSRF'] = secrets.token_hex()
        json_io(account_file_fp, action='w', fatal=True, data=profile)
        return(err, profile)

    if token:
        profile = validate_token(token)
        if profile:
            account_file_fp = os.path.join(config.dir_accounts_fp, \
                                           profile['uid']+'.json')

    if action == 'logout':
         # If no profile the user wasn't logged in to begin with
         # (a stale token might remain in their file until next
         # login). The "logout" timestamp does not account for
         # expired tokens.
        if profile:
            profile['logout'] = int(time.time())
            profile['token'] = ''
            profile['xCSRF'] = ''
            json_io(account_file_fp, action='w', fatal=True, data=profile)
            profile = {}
        return (err, profile)

    if action == 'chknonce':
        # In case the cookie/token expired before 2F was completed.
        if not profile:
            logging.debug('could not retrieve profile')
            raise bottle.HTTPError(400, 'cannot authenticate')
        try:
            nonce = int(query.get('nonce'))
        except:
            logging.debug('invalid nonce')
            raise bottle.HTTPError(400, 'cannot authenticate')
        if nonce == profile['nonce'] and \
           secrets.compare_digest(profile['token'], token):
            msg = '2-factor nonce was successfully verified for "{0}"'.\
                format(profile['user'])
            logging.debug(msg)
            profile['nonce'] = ''
            profile['login'] = int(time.time())
            profile['ip'] = bottle.request.environ.get('REMOTE_ADDR')
            json_io(account_file_fp, action='w', fatal=True, data=profile)
        else:
            msg = '2-factor nonce authentication failed for "{0}"'.\
                format(profile['user'])
            logging.debug(msg)
            profile['nonce'] = ''
            profile['token'] = ''
            profile['xCSRF'] = ''
            json_io(account_file_fp, action='w', fatal=True, data=profile)
            err = '2-factor authentication failed'
        return(err, profile)

### --- ###

@bottle.route('/', method=['GET', 'POST'])
@bottle.route(f'/{config.dir_pages}/<page:re:.*/?>', method=['GET', 'POST'])
@bottle.route(f'/{config.dir_pages}/<page>/<file>')
def process_page(page=config.page_home, file=''):
    """
process_page(page[str], file[str]) -> [HTTPResponse]

    Serve a web request for a page, file, or an upload.

"""
    logging.debug(f'executing "process_page({page}, {file})"')
    logging.debug(f'request method is "{bottle.request.method}"')

    pages_dir_fp = os.path.join(koipy_file_fp, config.dir_pages)
    (request_page_fp, request_file_fp, koi_file) = \
        check_os_access(pages_dir_fp, page, file)

    template = os.path.splitext(os.path.basename(koi_file))[0]
    me = {'page': page, 'path': request_page_fp, 'template': template, \
          'uri': f'/{config.dir_pages}/{page}', \
          'files': [os.path.basename(i) for i in \
                    glob.glob(os.path.join(request_page_fp, '*'))]}

    koi_data = json_io(koi_file, action='r', fatal=True)

    # http://bottlepy.org/docs/0.12/tutorial.html#request-data
    # http://bottlepy.org/docs/0.12/api.html#bottle.BaseRequest.params
    # http://bottlepy.org/docs/0.12/api.html#bottle.FormsDict
    # http://bottlepy.org/docs/0.12/tutorial.html#html-form-handling
    try:
        query = dict(bottle.request.params.decode())
    except Exception as e:
        query = {}
        logging.warning(f'cannot parse query input [{e}]')

    if page == config.page_login:
        logging.debug('session transaction, query dictionary not shown')
        (err, profile) = session(query)
        if err:
            logging.debug(f'error "{err}" negotiating session')
        bottle.response.set_cookie(name='token', \
                                   path='/', \
                                   value=profile.get('token', ''), \
                                   secure=config.force_ssl, \
                                   httponly=True, \
                                   max_age=config.session_timeout, \
                                   secret=config.session_cookie_sig)
        return bottle.template(config.tpl_session,  \
                               BOTTLE=bottle.request.environ, \
                               CONFIG=CONFIG,   \
                               ERR=err,         \
                               ME=me,           \
                               PAGE=koi_data,   \
                               PROFILE=profile, \
                               QUERY=query)
    else:
        logging.debug(f'GET/POST query dictionary is "{query}"')
        token = bottle.request.get_cookie("token", \
                                          secret=config.session_cookie_sig)
        profile = check_acl_access(template, file, koi_data, token)
        upload_requests = bottle.request.files.getall('file_upload')
        if upload_requests:
            num_up = len(upload_requests)
            logging.debug(f'<bottle.FileUpload> detected (x{num_up})')

    if profile and (query or upload_requests):
        xCSRF = query.get('xCSRF', '')
        if xCSRF:
            logging.debug(f'xCSRF token found "{xCSRF}"')
            if not secrets.compare_digest(xCSRF, profile.get('xCSRF', '')):
                logging.warning(f'attempted CSRF by "{profile["user"]}"')
                raise bottle.HTTPError(403, 'security violation detected')
        else:
            msg = 'will not serve in-session request without xCSRF'
            raise bottle.HTTPError(403, msg)

    if file:
        logging.debug(f'serving static file "{request_file_fp}"')
        return bottle.static_file(os.path.basename(request_file_fp), \
                                  root=request_page_fp)

    template_file = os.path.join(template_dir_fp, template) + '.tpl'
    if not os.access(template_file, os.R_OK):
        msg = f'missing or no read access to template file "{template_file}"'
        logging.error(msg)
        raise bottle.HTTPError(404, 'template not found')
    else:
        logging.debug(f'using template file "{template_file}"')

    users = {}
    index = {}
    tree = {}
    if koi_data.get('get_index', False):
        (index, tree) = index_pages(pages_dir_fp)
    else:
        logging.debug('page did not request an index/tree')

    if koi_data.get('get_users', False):
        users = index_users()
    else:
        logging.debug('page did not request users')

    upload = {}
    if upload_requests:
        if num_up > config.upload_max_files:
            msg = 'will not upload over {0} files at a time'.\
                format(config.upload_max_files)
            raise bottle.HTTPError(413, msg)
        n = 0
        for up_request in upload_requests:
            upload[n] = get_upload(up_request)
            n += 1

    logging.info(f'serving page "{request_page_fp}"')
    return bottle.template(template, \
                           BOTTLE=bottle.request.environ, \
                           CONFIG=CONFIG,   \
                           INDEX=index,     \
                           ME=me,           \
                           PAGE=koi_data,   \
                           PROFILE=profile, \
                           QUERY=query,     \
                           TREE=tree,       \
                           UPLOAD=upload,   \
                           USERS=users)

### --- ###

if __name__ == '__main__':
    # Setting "reloader=True" will import modules twice... this does not
    # seem to be a problem, but in any case it's not a good idea to run
    # koi using the bottle server (it's really only for debugging).
    # The advantage of the reloader is that koi will automatically
    # restart every time this file, template or config is saved.
    bottle.run(host='localhost', port=config.local_http_port, \
               reloader=True, debug=True)
