####################################################################
# Your site
#
# Only used in templates.

site_name='NAME'
site_editors=[]

####################################################################
# Connectivity

# Login sessions require SSL regardless of the setting below (unless
# DEBUG mode is on, see below).
force_ssl=False

# bottle port for serving HTTP requests, only if running ./koi.py
local_http_port='8080'

####################################################################
# Logs
#
# Ref: https://docs.python.org/3/library/logging.html
# These settings also apply to all templates that keep logs.

# Supported levels are: DEBUG, INFO, WARNING, ERROR, and CRITICAL.
# Note that only DEBUG level allows unencrypted logins.
loglevel='INFO'

# Format of the log.
logformat='%(levelname)s: koi: %(asctime)s: %(lineno)d: %(message)s'

####################################################################
# Directories
#
# "koi.py", "config.py", and "koi.wsgi" all reside in the top-level
# directory underneath which a directory containing the templates
# and another containing the web pages should reside e.g.
#
#   /usr/local/etc/wsgi/,
#                       |-uid1.json
#                       |-uid2.json
#                       `-etc...
#   /www/wsgi/,
#             |-koi.py
#             |-koi.wsgi
#             |-config.py
#             |-templates,
#             |          |-login.tpl
#             |          |-search.tpl
#             |          |-edit.tpl
#             |          |-error.tpl
#             |          `-etc...
#             `-pages/,
#                     |-main
#                     |-assets
#                     |-search
#                     |-login
#                     |-edit
#                     |-slug1
#                     |-slug2
#                     `-etc...

# The directory in which all pages are located.
dir_pages='pages'

# The directory which contains all templates.
dir_templates='templates'

# Directory where accouts are stored. This should be a full
# path outside the koi path.
dir_accounts_fp='/usr/local/etc/wsgi'

# If empty will use the default python tmp directory.
dir_tmp=''

####################################################################
# Site tree
#
# All page directories should be under "dir_pages". See the diagram
# in "Directories" above.

# Top-level page.
page_home='main'

# Login page.
page_login='login'

# Assets page (CSS files and the such).
page_assets='assets'

# Editor page.
page_edit='edit'

# Search page.
page_search='search'

# Slug restriction for the edit template.
slug_re=r'^[a-zA-Z0-9][a-zA-Z0-9_-]{0,75}$'

####################################################################
# Standard templates
#
# Templates are files in "dir_templates" named <template>.tpl.
# Choose the proper <template> names below.

tpl_error='error'

tpl_session='login'

####################################################################
# Search settings
#
# These setting are only used by the search template and wherever
# a search form may be present.

# The input variable used for search queries.
search_var='search_query'

# Maximum length of the search string.
search_max_query_len=100

# For the simple search engine (ssearch.tpl) uncomment this:
# search_box_popup='case-insensitive search for all words'
# For the whoosh search engine (wsearch.tpl) uncomment this:
search_box_popup='AND/OR/phrase/field:/fuzzy~ search'

####################################################################
# Session settings
#

# Cookie/token expiry in seconds.
session_timeout=3600*8

# Whether sessions are IP-locked
session_allow_roaming=False

# Cookie integrity signature, use a long (32 chars at least)
# random string. CHANGE THIS! Tip: run python and type
# import secrets
# secrets.token_hex()
session_cookie_sig=''

####################################################################
# Two-factor/email settings
#

# Two-factor email From/Subject lines.
twoF_from='admin@yourdomain.org'
twoF_subject='koi login verification'

# Two-factor email body. {nonce} will be replaced by the actual
# token.
twoF_msg="""
A login request has been made.

Your verification token is: {nonce}

If you did not make the login request your account may be
compromised. Similarly, if the above token doesn't work
your account may be compromised. In either case contact:
               admin@yourdomain.org
"""

# SMTP settings for sending the two-factor code.
smtp_server=''
smtp_port=587
smtp_TLS=True
smtp_login=''
smtp_passwd=''

####################################################################
# Miscellaneous restrictions
#

# Regular expression which determines allowable user names.
# Make sure not to allow strings which could lead to a XSS
# attack. The default expression allows alphanumeric names
# in any language and most email addresses.
# Useful link: https://regex101.com/r/rV7zK8/1
user_re=r'^[\w][\w_.+-]{0,50}(@[\w][\w_.+-]{0,50}\.[\w]{2,7})?$'

# Tuples of strings which will block serving pages and files
# starting or ending with the listed entries (for example,
# hidden files or emacs backups). ".koi" files are never served.
noserve_prefix=('.')
noserve_suffix=('~','.bak','.swp')

####################################################################
# Upload settings
#

# Maximum file size.
upload_max_size=10*1024*1024

# Maximum number of files to upload per request.
upload_max_files=5

upload_chunk_size=8192
