# koi

**koi** is a content management system (CMS) written in [python](https://www.python.org) (3.8.2+) using the [bottle](https://www.bottlepy.org) microframework.

The CMS uses [JSON](https://www.json.org/json-en.html) files to store information. It can be fully curated and managed from the back-end OS, but for convenience it also features a simple web-based [markdown](https://daringfireball.net/projects/markdown) article editor which is additionally able to manipulate image galleries (an anti-[CSFR](https://en.wikipedia.org/wiki/Cross-site_request_forgery) mechanism is built-in, as are anti-[XSS](https://en.wikipedia.org/wiki/Cross-site_scripting) measures). A search functionality is included, as is multi-user support with optional email-based two-factor authentication.

To use **koi** to its fullest extent from the start the following should be run (as root, tested on Ubuntu 20.04):

<pre><code>apt install python3-markdown python3-whoosh python3-passlib python3-bleach python3-pil python3-natsort</code></pre>

#### local installation

**koi** can be downloaded from [reimeika.ca](https://www.reimeika.ca/pages/software-downloads/koi.zip) or from this repo (the `koi.zip` provides a convenient way to do this). Unzip the file `koi.zip` and type `cd koi`. The file `config.py` contains detailed explanations of all configuration options and should be reviewed. In particular `session_cookie_sig` **must** be set. Once this is done, running `./koi.py` will make this tutorial accessible at `http://localhost:8080`.

#### serving files

By default web pages are in the `pages` directory. To create a new web page first make a sub-directory `test` and copy a file into it, i.e. from inside the `koi` directory:

<pre><code>mkdir pages/test
cp logo.txt pages/test</code></pre>

The file is now located at `http://localhost:8080/pages/test/logo.txt` but clicking the link will complain about a missing `.koi` file and return a `403` error. In order to serve requests every page must have an associated [template](http://bottlepy.org/docs/0.12/stpl.html) in the `dir_templates` directory. Which template is used is determined by the name of a JSON `.koi` file inside the web page directory so that, for example, `article.koi` will use the template file `article.tpl`. The most basic template is `files.tpl` and the simplest document possible is storing the string `{}` into a file called `files.koi` within `test` as so:

<code>echo '{}' > pages/test/files.koi</code>

Once this is done the `files.tpl` template will be used to serve the `logo.txt` file which can now be retrieved by clicking the link above.

#### creating a web page

Although the files inside `test` can be now served, the web page `http://localhost:8080/pages/test` itself is empty. The `files.tpl` template can display the contents of a key called `body`, so replacing the empty JSON object with `{"body": "Hello world!"}` in `files.koi` will now show a "Hello world" web page at the above link:

<code>echo '{"body": "Hello world!"}' >! pages/test/files.koi</code>

Editing JSON files is not very practical and so **koi** includes a simple markdown article editor. However, for complex pages it may be preferable to use a dedicated HTML editor with full markup, and for this the included `html2koi.py` script (discussed later in this guide) provides a quick way to convert a `.html` document into a `.koi` file.

#### searching

The default search engine is powered by [whoosh](https://whoosh.readthedocs.io/en/latest/intro.html) which is a non-standard but readily-available module which might be have to be installed (as root), as well as [markdown](https://daringfireball.net/projects/markdown/syntax) in order to parse most pages:

<code>apt install python3-markdown python3-whoosh</code>

Main features of the search function are:

- query words can be separated by `AND` (the default), `OR`, `NOT`, `ANDNOT` and `ANDMAYBE`
- fuzzy queries e.g. `grafiti~` will find `graffiti` ([see more](https://whoosh.readthedocs.io/en/latest/parsing.html#adding-fuzzy-term-queries))
- phrase search using double quotes
- field searches on `title`, `body`, `keywords`, and `author` or `creator`

A complex search could be crafted as follows:

<code>author:yuma OR grafiti~ ANDNOT title:lavender</code>

The index is dynamically updated any time a new article or page is added, deleted, or modified. Note that both this and the simple search engine (see below) filter their results based on access control lists (ACLs) so that matches of restricted pages are not shown unless the user (or visitor) performing the search has access to them.

#### adding users

The basic functionality for creating websites through the back-end is to simply write templates and add content via their corresponding `.koi` JSON file. A simpler approach is to use the built-in article editor. However, in order to do so users must be added to the system. Note that this requires [passlib](https://passlib.readthedocs.io/en/stable/) so running `apt install python3-passlib` may be necessary.

For increased security all user management is deliberately done from the back-end, although a template could in principle be written to accomplish this over the web. Running the script `./accounts.py` offers a simple menu-driven command-line interface which allows, amongst other things, adding, deleting, listing, and modifying user accounts. Of note is the fact that the hashing algorithm is compatible with the Linux  `/etc/shadow` file, and thus offers the possibility of importing existing user accounts. User accounts are stored in JSON files inside the directory specified by `dir_accounts_fp` in `config.py` so it's important to review this setting before proceeding.

Adding an account is straightforward and can be done following the steps set by the script. User names are case-insensitive and restricted by the `user_re` configuration setting, which by default allows alphanumeric strings and email addresses in any language (so that "AIKA", "sora@remeika.ca", and "ゆま" are all valid, albeit not necessarily a prudent mix). If desired an email for two-factor authentication may be recorded, but care must be taken to configure the format of the message (`twoF_msg`) and SMTP settings in `config.py`.

Listing a user's profile via `accounts.py` shows the basic structure of the account and some information about their last login, logout, IP used, "locked" status, and groups they belong to (although "roles" and "data" are not currently used, **koi** understands groups and can process access control restrictions based on membership).

#### editing articles

By default **koi** has no users at all. Assuming a user has been created using `accounts.py` they need to be added to the `site_editors` list in `config.py`. Note that the editor requires the [bleach](https://bleach.readthedocs.io/en/latest/index.html) module to operate so `apt install python3-bleach` may be necessary.

Once a user has been created they can log in at `http://localhost:8080/pages/login`. If a two-factor email has been recorded a numerical token will be required to validate the login. After authenticating users can click on the **EDITOR** button (which is only shown to editors) to create a new page or see a listing of the pages they can edit and delete (hovering over an entry provides details about the web page). Only pages using the `article.tpl` or `gallery.tpl` templates are supported.

The editor is mostly self-explanatory. Articles are written in markdown (help for which is available from the collapsed section at the bottom of the editing page) and consist of a *title*, a *slug* (see below), a space-separated list of *keywords*, and a *body* (most elements will provide a helpful pop-up if hovered on). Controls for editing an article are:

- **WEBPAGE** opens the current web page in a new tab (must be refreshed after saving edits)
- **FILES** file manager to review and delete files, and also manage ACLs (see below)
- **UPLOADER** for uploading files unto the web page
- **ARTICLES** to return to the article listing
- **SAVE** to save the current article

Files (including images) can be linked and embedded in web pages using markdown syntax (the file manger provides the link/embed code for each file which can be copied and pasted into the article).

By default web pages are stored in directories named after the creation time-stamp e.g. `/pages/1593798867`, but can be renamed using the *slug* field after first saved. All article revisions are stored in hidden files as `.article.koi-rev#` (where `rev#` is the revision number) within the web page, so it's feasible to recover prior versions (though only from the back-end). Deleted articles and their files are also backed-up as hidden directories (e.g. `/pages/.name-rev#-timestamp`), although individually-deleted files are permanently removed.

#### curating a gallery

The editor offers a second function: that of creating image galleries. This feature requires [PIL](http://python-pillow.github.io/), and optionally [natsort](https://github.com/SethMMorton/natsort), and hence `apt install python3-pil python3-natsort` may be necessary. The default image formats supported are `.jpg` and `.png`.

As with articles, galleries have a <em>title</em>, a <em>slug</em>, and <em>keywords</em>. Two viewing modes are available, <em>grid</em> (overview of the entire image set) and <em>slide</em> (single picture view, with a <strong>▸ Details</strong> section at the bottom offering extra image information). By default a new gallery has the same curator (editor) and ACL permissions as new articles i.e. it's restricted to the user who created it.

After creating a new gallery images can be uploaded to the page when in <em>grid</em> view. The ACL (see next section) of individual images can only be set from the back-end, but a show/hide mechanism is available. When an image is uploaded it is automatically tagged as <em>hidden</em>.  In grid and slide views these images look slightly washed-out to the curator, and visitors will need to append `?unhide` at the end of the gallery URL to view them. A toggle button can be found under each image in slide view, and so a curator can control what images are always shown and which ones require the special URL. The `unhide_tag` is configurable in `edit.koi` from the back-end, as is the default state of the images upon upload (currently all hidden unless `hide_new` is set to `False`). Keep in mind that hiding images does not block a direct link to the image file (an ACL would be needed for that), but it provides a simple filter depending on the link followed to the gallery.

The last feature of the editor is ACL manipulation, explained in the section below.

#### access control lists (acls)

Articles and galleries have two types of restrictions: who can edit/curate them and who can view them. Newly-created articles and galleries can only be modified and viewed by their original author, but other editors can be added by clicking on the <strong>▸ Access control list for <<em>name</em>></strong> (or <strong>▸ gallery ACL</strong> in grid view) expandable section and modifying the list of users who can edit the page (note that it's impossible to remove oneself). Adding a wildcard <strong>\*</strong> allows <em>any</em> logged-in user to edit the article/gallery. Group-based editing controls are not currently implemented, nor is blocking with the <strong>!</strong> prefix (see below). ACL controls for articles and galleries are equivalent, so any reference to articles below applied also to galleries.

The  access control list for <em>viewing</em> articles can restrict access to web pages and files on a per-user, per-IP, and date-time basis (per-group is also supported but only through the back-end). This limits who can view a web page or download a file when clicking on a link. By default new articles can only be accessed by the user who originally wrote them, from any IP, starting from the creation date-time. To make an article universally available suffice to make the user ACL equal to <strong>\*</strong>, the IP ACL equal to <strong>\*</strong>, and leave the timestamp as-is. Other ACL features are:

- Adding a <strong>*</strong> to the user list will give access permissions to all logged-in users
- Subnets (possibly in combination with an IP address list) can be specified as <strong>xxx.yyy</strong>
- Setting a future release date will only allow access from that date-time onward
- To block, prepend <strong>!</strong> to a user or IP/subnet (overrides any conflicting allow directive)

Access control lists can be manipulated in exactly the same way from the file manager on a per-file basis (by default uploaded files inherit the ACL of the web page). Galleries only offer a per-image ACL via the back-end.

#### trusted articles, making forms

To thwart XSS attacks user input is sanitized using [bleach](https://bleach.readthedocs.io/en/latest/index.html) and context-based allowlists, and further escaped upon display unless used in an HTML context. This, however, strips most HTML code which is sometimes undesirable. **koi** supports the concept of <em>trusted</em> articles which allow full HTML-editing using the web editor. This setting can be toggled via the back-end by changing `trusted` to `True` in the `.koi` file, which in turn will add the tag "(trusted)" next to the ACL section near the top of the article editor. It is strongly encouraged that only select editors be allowed to modify such articles.

Forms can then be included in templates as well as trusted `.koi` files (or `.html` files converted using `html2koi.py`). **koi** provides an anti-CSFR measure via a token which is tied to the user session and which must be used when making a submission (in fact, **koi** forbids logged-in users to submit *any*  data — including uploads — unless a valid anti-CSFR token is present). Please refer to the tutorial for more information.

#### templates

**koi** includes a few templates in the `templates` directory (configurable via `dir_templates`) which can be studied for reference. Other than the special `login.tpl`, all templates are provided the following dictionaries:

- `BOTTLE`: the [WSGI environment ](https://www.python.org/dev/peps/pep-0333/#environ-variables)
- `CONFIG`: all parameters defined in `config.py`
- `INDEX`: the website index, each key being the `page` name and the corresponding `.koi` data
- `ME`: properties of the current page
- `PAGE`: the `.koi` JSON dictionary
- `PROFILE`: the current user's JSON profile (an empty dictionary if no session is ongoing)
- `QUERY`: the combined `GET` and `POST` dictionary
- `TREE`: the website tree, each key being the `page` name with the equivalent `ME` dictionary
- `UPLOAD`: a dictionary of uploaded files (with number keys `0` up to `upload_max_files`)
- `USERS`: overview of all users, each key being a user name and its `PROFILE` dictionary

Detailed dictionary keys:

- `ME`: `page`, `path`, `template`, `uri`, and `files` (a list of all non-hidden files/dirs in the directory)
- `PROFILE`:
    * auth: `hash`, `2f_email`
    * id: `user`, `uid`, `groups`, `name`
    * session:  `ip`, `token`, `nonce`, `xCSRF`, `login`, `logout`, `locked`
    * misc: `koi_version`
    * unused: `data`, `roles`
- `TREE[page]`: `path`, `template`, `uri`, and `files` (list of non-hidden files/dirs in each page directory)
- `UPLOAD[N]`: `OK`, `status`, `content_type`, `raw_filename`, `safe_name`, and the upload in `file_data`.
- `USERS[user]`: same as `PROFILE`

Note that for performance reasons `INDEX` and `TREE` are only provided if `get_index` is set to `True` in the `.koi` file, and similarly `USERS` is only provided if `get_users` is also `True`. Otherwise the dictionaries are present but empty (as is `UPLOAD` if no uploads are found). User names have their case preserved, but should be lower-cased for internal usage i.e. use `user.lower()`.

#### scripts and back-end usage

As mentioned earlier in this guide, **koi** can be readily used and managed from the back-end (which offers much more control and security at the expense of convenience). No users or editors are really necessary, and all GUI components can be disabled via ACL restrictions. For this purpose the following scripts are provided inside the `koi` directory:

- `accounts.py`: add, delete, modify and list user accounts with batch-import support
- `acledit.py`: manipulate a page's access control list
- `html2koi.py`: convert an HTML file into an `article.koi` file
- `mkgallery.py`: create a `gallery.koi` file

For example, to create a new gallery from the back-end the following procedure would be followed (starting from the `koi` directory). First, create the gallery:

<code>./mkgallery.py</code>

Set proper ACL permissions:

<code>./acledit.py</code>

Move `gallery.koi` to its page directory and populate the gallery:

<pre><code>mkdir pages/portfolio
mv gallery.koi pages/portfolio
cp -p /mnt/camera/*.jpg pages/portfolio/
</code></pre>

Upon visiting the page for the first time at `http://localhost:8080/pages/portfolio?unhide` the gallery will automatically be generated (and updated if images are added or deleted).

#### apache configuration

To run **koi** on an [apache](http://httpd.apache.org) web server via [mod_wsgi](https://modwsgi.readthedocs.io/en/develop/user-guides/quick-installation-guide.html) it may be necessary to run:

<code>apt install libapache2-mod-wsgi-py3</code>

Assuming a working SSL-enabled web server is already running,  the first step is to move the `koi` directory into a suitable location, say `/www/wsgi`, and modify the file `koi.wsgi` to set `sys.path` accordingly e.g.

<code>sys.path = ['/www/wsgi/koi/'] + sys.path</code>

Ownership (perhaps `www-data`) and permissions of files (`600`) and directories (`700`) should be reviewed, as should the settings in `config.py`, particularly `dir_accounts_fp` (say, `/usr/local/etc`) and a new `session_cookie_sig`. Setting `force_ssl` to `True` is highly recommended, and care should be taken not to run in `DEBUG` mode.

Adding the following code to an ssl `VirtualHost` may then suffice:

<pre><code>DocumentRoot /www/wsgi/koi
  ≺Directory /www/wsgi/koi≻
    Options None
    AllowOverride None
    Require all granted
  ≺/Directory≻
WSGIProcessGroup koi
WSGIDaemonProcess koi user=www-data group=www-data
WSGIScriptAlias / /www/wsgi/koi/koi.wsgi</code></pre>

Remember to `touch koi.wsgi` after adding a new template or making changes to existing ones in order to update the cache.

#### odds and ends

**—** URL <em>slugs</em> in the article editor are, by default, restricted to the following regular expression in `config.py`: `^[a-zA-Z0-9][a-zA-Z0-9_-]{0,75}$`. This allows for a mix of up to seventy-six underscores, dashes, and alphanumeric ASCII characters. This rule is not enforced by the <k>koi</k> core (which doesn't rely on the editor) but by the template `edit.tpl`.

**—** **koi** includes two search engines, a simple one in template `ssearch.tpl` and the more advanced `wsearch.tpl`. Which one is used is a simple matter of making a symlink of the preferred template file to `search.tpl`. The simple search engine has no external dependencies and requires no index, but does no more than a case-insensitive AND search of the submitted words with no concept of query analysis or scoring. The [whoosh](https://whoosh.readthedocs.io/en/latest/intro.html)-based engine `wsearch.tpl` is the default.

**—** If error messages are deemed too informative they can be tweaked in the `error.tpl` template, in particular the following snippet:

<pre><code>% if CODE in [400, 403, 404, 413, 500]:
   ≺p≻≺font class="error"≻[{{CODE}}] {{DETAILS}}≺/font≻≺/p≻
% end
</code></pre>

can be customized as desired (by, say, getting rid of `{{DETAILS}}` in extreme cases).

**—** `.koi` files can always be (carefully) edited directly using a text editor, or from within the python interpreter (but care must be taken not to delete standard fields which may be required by the editor):

<pre><code>import json
with open("pages/article/article.koi", "r") as fd:
  art = json.load(fd)

... do stuff to "art" ...

with open("pages/article/article.koi", "w") as fd:
  json.dump(art, fd, ensure_ascii=False)
</code></pre>

**—** While multi-lingual web page content should be fine, creating non-ASCII slugs and file names from the back-end will likely cause issues and should be avoided.

**—** An example of a complex ACL:

<pre><code>acl = {"article.koi":{"users": "*", "groups": [], "ips": "*", "time": 0},
       "araara.doc": {"users": ["クレア", "*"], "groups": [], "ips": ["8.8.8.8"], "time": 0}
       "kira.tex":   {"users": ["AIKA"], groups: ["av"], "ips": ["128.100"], "time": 0}
       "bday.pdf":   {"users": ["yuma", "!sora"], "groups": ["sod"], "ips": "*", "time": 0}
       "shibu.jpg":  {"users": ["kaho"], "groups": ["!moodyz"], "ips": "*", "time": 1604973574}}</code></pre>

These ACLs are not exclusive to articles and can be applied to any web page regardless of the template (for example, the login page, or the search engine).  The lack of an ACL entry in the `.koi` file is equivalent to making the web page and its files available to anyone.

#### colophone

**[koi](https://www.reimeika.ca)** and documentation is released under the [3-clause BSD license](https://en.wikipedia.org/wiki/BSD_licenses#3-clause_license_(%22BSD_License_2.0%22,_%22Revised_BSD_License%22,_%22New_BSD_License%22,_or_%22Modified_BSD_License%22))

[bottle](https://www.bottlepy.org) is distributed under the [MIT license](https://raw.githubusercontent.com/bottlepy/bottle/master/LICENSE)

CSS used is a customized version of [skeleton](http://www.getskeleton.com), distributed under the [MIT license](http://www.opensource.org/licenses/mit-license.php)

The [**koi** logo](https://freesvg.org/single-koi-nobori) is [public domain](https://creativecommons.org/publicdomain/zero/1.0/)
