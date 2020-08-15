% import logging
% # The edit.koi ACL must require users to be logged-in to access this template,
% # and must futhermore be in the "site_editors" list in "config.py".
% user = PROFILE['user']
% template = ME['template']+'.tpl'
% logging.info(f'{template}:{user}: processing template')
%
% import os
% import time
% import json
% import markdown
% import socket
% import datetime
% import re
%
% no_bleach = False
% try:
%   import bleach
% except:
%   logging.warning(f'{template}:{user}: could not import bleach')
%   no_bleach = True
%   ERR = 'you need to install bleach'
% end
%
% max_up_size = f'{CONFIG["upload_max_size"]/(1024*1024)}MB'
% clock_format = '%Y-%m-%dT%H:%M'
% pages = CONFIG['dir_pages']
% assets = CONFIG['page_assets']
% valid_slug = re.compile(CONFIG['slug_re'])
% xCSRF = f'<input name="xCSRF" type="hidden" value="{PROFILE["xCSRF"]}">'
% art_ACL = """<details>
             <summary>
               Access control list for <em>{name}</em>
               <span title="all HTML allowed">{trusted}</span>
             </summary>
             <div class="row">
               <div class="twelve columns">
                 <span title="who can edit this page?">
                   Enter a space-separated list of users who can edit this article:
                   <input required form="{formID}" name="editors" size="25" type="text"
                          value="{editors}">
                 </span>
               </div>
             </div>
             <p>
               In the three entries below, the
               first field is a space-separated list of users who can
               access the {item} (use a <em>single</em> <strong>*</strong>
               for anyone, or <em>add</em> a <strong>*</strong> after your
               username so that only logged-in users can see the {item}).
               Second field is a space-separated list of IPs/subnets
               which can access the {item} (use <strong>*</strong> for
               anywhere). Note that subnets can be specified as
               <strong>xxx.yyy</strong> (no trailing dot). Third field
               is the release date. To block a user or IP/subnet prepend a
               <strong>!</strong> as in <strong>!Julia</strong><br>
               Remember to open access once you are ready to make the
               {item} public.
             </p>
             <div class="row">
               <div class="three columns">
                 <span title="who can access the {item}?">
                   <input required form="{formID}" name="who" size="12"
                          type="text" value="{acl_users}">
                 </span>
               </div>
               <div class="three columns">
                 <span title="from that IPs?">
                   <input required form="{formID}" class="u-pull-left"
                          name="where" size="12" type="text"
                          value="{acl_ips}">
                 </span>
               </div>
               <div class="three columns">
                 <span title="when is the {item} accessible?">
                   <input required form="{formID}" class="u-pull-left"
                          name="when" size="12" type="datetime-local"
                          value="{acl_time}">
                 </span>
               </div>
               <div class="three columns">
                 &nbsp;
               </div>
             </div>
             <hr>
           </details>"""
% file_ACL = """<details>
             <summary>
               Access control list for <em>{name}</em> {origin}
             </summary>
             <div class="row">
               <div class="three columns">
                 <span title="who can access the {item}?">
                   <input required form="{formID}" name="who" size="12"
                          type="text" value="{acl_users}">
                 </span>
               </div>
               <div class="three columns">
                 <span title="from that IPs?">
                   <input required form="{formID}" class="u-pull-left"
                          name="where" size="12" type="text"
                          value="{acl_ips}">
                 </span>
               </div>
               <div class="three columns">
                 <span title="when is the {item} accessible?">
                   <input required form="{formID}" class="u-pull-left"
                          name="when" size="12" type="datetime-local"
                          value="{acl_time}">
                 </span>
               </div>
               <div class="three columns">
                 &nbsp;
               </div>
             </div>
             <hr>
           </details>"""
% md_guide = """                   <div class="twelve columns center">
                     <table class="md_guide">
                       <tbody>
                         <tr>
                             <td class="preformatted">*Italic*</td>
                             <td class="postformatted">
                               <em>Italic</em>
                             </td>
                         </tr>
                         <tr>
                             <td class="preformatted">**Bold**</td>
                             <td class="postformatted">
                               <strong>Bold</strong>
                             </td>
                         </tr>
                         <tr>
                             <td class="preformatted">
                                 Heading 1<br/>
                                 =========
                             </td>
                             <td>
                               <h1 class="postformatted-heading">
                                 Heading 1
                               </h1>
                             </td>
                         </tr>
                         <tr>
                             <td class="preformatted">
                                 Heading 2<br/>
                                 ---------
                             </td>
                             <td>
                               <h2 class="postformatted-heading2">
                                 Heading 2
                               </h2>
                             </td>
                         </tr>
                         <tr>
                             <td class="preformatted">
                                 [r e i m e i k a](https://reimeika.ca)
                             </td>
                             <td class="postformatted">
                               <a href="https://reimeika.ca/">r e i m e i k a</a>
                             </td>
                         </tr>
                         <tr>
                             <td class="preformatted">
                                 ![k o i](/{0}/{1}/koi.png "k o i")
                             </td>
                             <td class="postformatted">
                                 <img src="/{0}/{1}/koi.png" alt="k o i" title="k o i"/>
                             </td>
                         </tr>
                         <tr>
                             <td class="preformatted">
                                 &gt; Blockquote
                             </td>
                             <td class="postformatted">
                                 <blockquote>Blockquote</blockquote>
                             </td>
                         </tr>
                         <tr>
                             <td class="preformatted">
                                 <p>
                                     - List<br/>
                                     - List<br/>
                                     - List<br/>
                                 </p>
                             </td>
                             <td class="postformatted">
                                 <ul>
                                     <li>List</li>
                                     <li>List</li>
                                     <li>List</li>
                                 </ul>
                             </td>
                         </tr>
                         <tr>
                             <td class="preformatted">
                                 <p>
                                     1. One<br/>
                                     2. Two<br/>
                                     3. Three
                                 </p>
                             </td>
                             <td class="postformatted">
                                 <ol>
                                     <li>One</li>
                                     <li>Two</li>
                                     <li>Three</li>
                                 </ol>
                             </td>
                         </tr>
                         <tr>
                             <td class="preformatted">
                                 Horizontal Rule<br/>
                                 <br/>
                                 ---
                             </td>
                             <td class="postformatted">
                                 Horizontal Rule
                                 <hr>
                             </td>
                         </tr>
                         <tr>
                             <td class="preformatted">
                                 `Inline code`
                                 </td>
                             <td class="postformatted">
                                 <code class="preformatted">Inline code</code>
                             </td>
                         </tr>
                       </tbody>
                     </table>
                   </div>""".format(pages, assets)
% md_help = """            <div class="row">
              <div class="twelve columns center">
                <details>
                  <summary>markdown help</summary>
                  <center>{0}</center>
                </details>
              </div>
            </div>""".format(md_guide)
%
% #####################################################################################
%
% def save_json(file_fp, data, info):
%   """
    save_json(file_fp[str], data, info[str]) -> ERR[str]

    Dump the JSON data into file_fp. Return non-empty ERR if oops. "info" provides
    extra information about the data in case of error.

"""
%   logging.debug(f'{template}:{user}: executing "save_json({file_fp}, <data>, {info})"')
%   ERR = ''
%   try:
%     with open(file_fp, "w", encoding='utf-8') as fd:
%       json.dump(data, fd, ensure_ascii=False)
%     end
%     os.chmod(file_fp, 0o600)
%     logging.debug(f'{template}:{user}: saved file "{file_fp}"')
%   except Exception as e:
%     logging.error(f'{template}:{user}: unable to save file "{file_fp}" [{e}]')
%     ERR = f'unable to save {info}'
%   end
%   return ERR
% end
%
% #####################################################################################
%
% def check_slug(slug):
%   """
    check_slug(slug[str]) -> (slug[str], ERR[str])

    Check the validity of the slug. Unless invalid ERR is empty.

"""
%   logging.debug(f'{template}:{user}: executing "check_slug({slug})"')
%   ERR = ''
%   if not valid_slug.match(slug):
%     ERR = 'slug does not match slug_re'
%     logging.debug(f'{template}:{user}: {ERR}')
%     return (slug,  ERR)
%   end
%   if slug in INDEX:
%     ERR = 'slug already exists'
%   end
%   return (slug, ERR)
% end
%
% #####################################################################################
%
% def get_listing(template):
%   """
    get_listing(template[str]) -> listing[list]

    Get a listing of information for all "template" pages, each entry the dictionary:

      {'page': page, 'title': title, 'item': item, 'popup': popup, 'warn', warn}

"""
%   logging.debug(f'{template}:{user}: executing "get_listing({template})"')
%   listing = []
%   for page, entry in TREE.items():
%     if entry['template'] != template:
%       continue
%     end
%     if '*' in INDEX[page]['editors']:
%       pass
%     elif user.lower() not in INDEX[page]['editors']:
%       continue
%     end
%     koi_file_fp = os.path.join(entry['path'], f'{template}.koi')
%     modified = time.localtime(os.path.getmtime(koi_file_fp))
%     modified = time.strftime('%H:%M:%S %d-%b-%Y', modified)
%     uri = entry['uri']
%     # Sort by "title" but list "item"
%     title = INDEX[page]['title']
%     item = title
%     if not title:
%       title = page
%       item = uri
%     end
%     keywords = INDEX[page]['keywords']
%     warn = ''
%     popup = ''
%     if template == 'article':
%       if not INDEX[page]['markdown'] and not INDEX[page]['trusted']:
%         warn = '<span class="error" title="untrusted HTML article, the editor will destroy most markup">&#10071;&nbsp;</span>'
%       end
%       rev = INDEX[page]['rev']
%       popup = f"URI: {uri}\nlast modified: {modified}\nkeywords: {keywords}\nrev: {rev}"
%     elif template == 'gallery':
%       tot = len(INDEX[page]['library'])
%       popup = f"URI: {uri}\nlast modified: {modified}\nkeywords: {keywords}\nimages: {tot}"
%     end
%     listing.append({'page': page, 'title': title, 'item': item, 'popup': popup, 'warn': warn})
%   end
%   return listing
% end
%
% #####################################################################################
%
% def check_editors(page):
%   """
    check_editors(page[str])

    Check editing permision of page. Unless input has been tampered with this
    function should always return, hence the finality of raising a SystemExit.

"""
%   logging.debug(f'{template}:{user}: executing "check_editors({page})"')
%   if '*' in INDEX[page]['editors']:
%     return
%   elif user.lower() not in INDEX[page]['editors']:
%     logging.error(f'{template}:{user}: user "{user}" is not an editor (tampering?)')
%     raise SystemExit
%   end
%   return
% end
%
% #####################################################################################
%
% def get_page():
%   """
    get_page() -> (page[str], page_fp[str], title[str])

    Return existing "page" in QUERY (if valid), the full path to the page, and
    its title. Unless input has been tampered with this function should always
    return, hence the finality of raising a SystemExit.

"""
%   logging.debug(f'{template}:{user}: executing "get_page()"')
%   page = QUERY.get('page', '').rstrip('/')
%   # The "edit" page resides at the same level as all other pages, so
%   # we use it to determine the directory in which to store the article
%   # pages.
%   pages_fp = os.path.dirname(ME['path'])
%   page_fp = os.path.join(pages_fp, page)
%   try:
%     # Check if the page exists and is an article.
%     if TREE[page]['template'] not in ('article', 'gallery'):
%       raise ValueError
%     end
%   except Exception as e:
%     logging.error(f'{template}:{user}: invalid template "{TREE[page]["template"]}" requested (tampering?)')
%     raise SystemExit
%   end
%   return (page, page_fp, INDEX[page]['title'])
% end
%
% #####################################################################################
%
% def get_file_fp(page):
%   """
    get_file_fp(page[str]) -> file_fp[str]

    If there is a "file" in the QUERY inside "page" verify its existence and
    return its full path. Unless input has been tampered with this function
    should always return, hence the finality of raising a SystemExit.

"""
%   logging.debug(f'{template}:{user}: executing "get_file_fp({page})"')
%   if not (file := QUERY.get('file', '')):
%     return file
%   end
%   # Check if the file exists.
%   if file not in TREE[page]['files']:
%     logging.error(f'{template}:{user}: file "{file}" is not in "{page}" (tampering?)')
%     raise SystemExit
%   end
%   file_fp = os.path.join(TREE[page]['path'], file)
%   return file_fp
% end
%
% #####################################################################################
%
% def delete(page='', page_fp='', file_fp=''):
%   """
    delete(page[str], page_fp=[str], file_fp[str]) -> ERR[str]

    Delete a page or a file depending on which is present in
    the function call. A "page" deletion will make a backup
    (including files), "file" deletions are final.

"""
%   logging.debug(f'{template}:{user}: executing "delete({page}, {page_fp}, {file_fp})"')
%   ERR = ''
%   if file_fp:
%     try:
%       os.remove(file_fp)
%     except Exception as e:
%       ERR = 'unable to delete file'
%       logging.error(f'{template}:{user}: {ERR} "{file_fp}" [{e}]')
%       return ERR
%     end
%   else:
%     path = os.path.dirname(page_fp)
%     # We add the "created" timestamp to avoid clashes since slugs can be renamed
%     if TREE[page]['template'] == 'article':
%       target_page = os.path.join(path, f'.{page}-{INDEX[page]["rev"]}-{INDEX[page]["created"]}')
%     elif TREE[page]['template'] == 'gallery':
%       target_page = os.path.join(path, f'.{page}-{INDEX[page]["created"]}')
%     else:
%       logging.error(f'{template}:{user}: invalid template "{TREE[page]["template"]}" requested (tampering?)')
%       raise SystemExit
%     end
%     try:
%       os.rename(page_fp, target_page)
%     except Exception as e:
%       ERR = 'unable to delete page'
%       logging.error(f'{template}:{user}: {ERR} "{page_fp}" [{e}]')
%     end
%     return ERR
%   end
% end
%
% #####################################################################################
%
% def process_acl():
%   """
    process_acl() -> (acl_users[str/list], acl_ips[str/list], acl_time[int], editors[list])

    Process an ACL from QUERY parameters.

"""
%   logging.debug(f'{template}:{user}: executing "process_acl()"')
%   users_lc = [i.lower() for i in USERS]
%   if QUERY['who'].strip() != '*':
%     allowed_users = [i.lower() for i in QUERY['who'].split() if i[0] != '!']
%     blocked_users = [i[1:].lower() for i in QUERY['who'].split() if i[0] == '!']
%   end
%   if QUERY['where'].strip() != '*':
%     allowed_ips = [i for i in QUERY['where'].split() if i[0] != '!']
%     blocked_ips = [i[1:] for i in QUERY['where'].split() if i[0] == '!']
%   end
%   if QUERY['who'].strip() == '*':
%     acl_users = '*'
%   else:
%     acl_allowed = [i for i in allowed_users if i in users_lc or i == '*']
%     acl_blocked = ['!'+i for i in blocked_users if i in users_lc]
%     acl_users = acl_allowed + acl_blocked
%   end
%   # Subnets must be of the form xxx.yyy (no trailing ".")
%   if QUERY['where'].strip() == '*':
%     acl_ips = '*'
%   else:
%     acl_allowed = [i for i in allowed_ips if socket.inet_aton(i)]
%     acl_blocked = ['!'+i for i in blocked_ips if socket.inet_aton(i)]
%     acl_ips = acl_allowed + acl_blocked
%   end
%   # Files don't have QUERY["editors"] (and don't use "editors")
%   editors = []
%   if QUERY.get('editors', ''):
%     editors = [i.lower() for i in QUERY['editors'].split()]
%     editors = [i for i in editors if i in users_lc or i == '*']
%   end
%   if user.lower() not in editors:
%     editors = [user.lower()] + editors
%   end
%   acl_time = int(time.mktime(time.strptime(QUERY['when'], clock_format)))
%   return (acl_users, acl_ips, acl_time, editors)
% end
%
% #####################################################################################
%
% def save_file_acl(page, page_fp, file):
%   """
    save_file_acl(page[str], page_fp[str], file[str]) -> (page[str], ERR[str])

    Save a file ACL in the "article.koi" of "page".

"""
%   logging.debug(f'{template}:{user}: executing "save_file_acl({page}, {page_fp}, {file})"')
%   ERR = ''
%   if file.startswith(CONFIG['noserve_prefix']) or \
%      file.endswith(CONFIG['noserve_suffix']) or file.endswith('.koi'):
%     logging.error(f'{template}:{user}: invalid file "{file}" requested (tampering?)')
%     ERR = 'invalid file'
%     return (page, ERR)
%   end
%   try:
%     (acl_users, acl_ips, acl_time, editors) = process_acl()
%   except Exception as e:
%     logging.error(f'{template}:{user}: invalid ACL detected [{e}]')
%     ERR = 'invalid ACL'
%     return (page, ERR)
%   end
%   koi_data = INDEX[page]
%   koi_data['acl'][file] = {'users': acl_users, 'groups': [], 'ips': acl_ips, \
%                            'time': acl_time}
%   koi_file_fp = os.path.join(page_fp, 'article.koi')
%   ERR = save_json(koi_file_fp, koi_data, 'ACL data')
%   return (page, ERR)
% end
%
% #####################################################################################
%
% def get_koi_data(acl_users, acl_ips, acl_time, editors):
%   """
    get_koi_data(acl_users[list], acl_ips[list], acl_time[int], editors[list])
                 -> (koi_data[dict], page[str], page_fp[str], new[bool])

    Get the article QUERY koi data from the editor form. If it's a new article name the
    appropriate path ("page_fp"), otherwise make sure to verify an existing path.

"""
%   logging.debug(f'{template}:{user}: executing "get_koi_data({acl_users}, {acl_ips}, {acl_time})"')
%   koi_data = {}
%   if not (author := PROFILE['name']):
%     author = user
%   end
%   # When "new_page" there won't be a "page" in the "save" QUERY as it'll
%   # be named below.
%   if 'page' not in QUERY:
%     new = True
%   else:
%     new = False
%   end
%   # This editor automatically generates page names, but can edit an
%   # article in a non-standard-named page if already present (created
%   # directly on the filesystem, say).
%   if new:
%     start = int(time.time())
%     while True:
%       timestamp = int(time.time())
%       page = str(timestamp)
%       page_fp = os.path.join(os.path.dirname(ME['path']), page)
%       if timestamp-start > 10:
%         logging.error(f'{template}:{user}: cannot create new page, load > 1req/s?')
%         raise SystemExit
%       end
%       if os.path.isdir(page_fp):
%         time.sleep(1)
%         continue
%       else:
%         break
%       end
%     end
%     koi_data['rev'] = '0'.zfill(5)
%     koi_data['created'] = timestamp
%     koi_data['trusted'] = False
%     koi_data['markdown'] = True
%     koi_data['notes'] = []
%     koi_data['author'] = author
%   else:
%     # page CANNOT be empty unless input has been tampered with, but we
%     # deal with this in "get_page()". Note that "title" may be outdated
%     # but we don't use it (we set the [maybe] updated one below).
%     timestamp = int(time.time())
%     (page, page_fp, title) = get_page()
%     check_editors(page)
%     rev = int(INDEX[page]['rev'])+1
%     koi_data['rev'] = str(rev).zfill(5)
%     koi_data['created'] = INDEX[page]['created']
%     koi_data['trusted'] = INDEX[page]['trusted']
%     koi_data['markdown'] = INDEX[page]['markdown']
%     koi_data['notes'] = INDEX[page]['notes']
%     koi_data['author'] = INDEX[page]['author']
%   end
%   koi_data['timestamp'] = timestamp
%   try:
%     title = QUERY['title']
%     body = QUERY['body']
%     if not koi_data['trusted']:
%       logging.error(f'Article "{page}" is not trusted, bleaching.')
%       title = bleach.clean(title, strip=True)
%       body = bleach.clean(body, tags=bleach.ALLOWED_TAGS + ['pre'], strip=True)
%     end
%     keywords = bleach.clean(QUERY['keywords'], strip=True)
%   except Exception as e:
%     # This CANNOT happen unless input has been tampered with.
%     logging.error(f'{template}:{user}: unexpected QUERY [{e}] (tampering?)')
%     raise SystemExit
%   end
%   koi_data['title'] = title
%   koi_data['keywords'] = keywords
%   koi_data['body'] = body
%   koi_data['editors'] = editors
%   koi_data['koi_version'] = CONFIG['koi_version']
%   koi_data['last_edit_by'] = user
%   koi_data['editor_groups'] = []
%   koi_data['tags'] = []
%   koi_data['acl'] = {'article.koi': {'users': acl_users, 'groups': [], \
%                      'ips': acl_ips, 'time': acl_time}}
%   return (koi_data, page, page_fp, new)
% end
%
%
% #####################################################################################
%
% def new_gallery():
%   """
    new_gallery() -> (page[str], ERR[str])

    Create a new gallery.

"""
%   logging.debug(f'{template}:{user}: executing "new_gallery()"')
%   ERR = ''
%   timestamp = int(time.time())
%   page = str(timestamp)
%   page_fp = os.path.join(os.path.dirname(ME['path']), page)
%   koi_file_fp = os.path.join(page_fp, 'gallery.koi')
%   if not (creator := PROFILE['name']):
%     creator = user
%   end
%   ver = CONFIG['koi_version']
%   koi_data = {'title': 'untitled', 'keywords': '', 'notes': [], \
%               'timestamp': timestamp, 'creator': creator, 'koi_version': ver, \
%               'editors': [user.lower()], 'editor_groups': [], 'tags': []}
%   koi_data['acl'] = {'gallery.koi': {'users': [user.lower()], 'groups': [], \
%                      'ips': '*', 'time': timestamp}}
%   koi_data['thumbnail'] = PAGE['def_thumbnail']
%   koi_data['histogram'] = PAGE['def_histogram']
%   koi_data['image'] = PAGE['def_image']
%   koi_data['library'] = {}
%   koi_data['get_users'] = True
%   koi_data['created'] = timestamp
%   try:
%     os.mkdir(page_fp, mode=0o700)
%   except Exception as e:
%     logging.error(f'{template}:{user}: unable to make the directory "{page_fp}" [{e}]')
%     ERR = 'unable to save the gallery'
%     return (page, ERR)
%   end
%   ERR = save_json(koi_file_fp, koi_data, 'gallery')
%   return (page, ERR)
% end
%
% #####################################################################################
%
% def save_article():
%   """
    save_article() -> (page[str], ERR[str])

    Save "article.koi", making a backup if not new.

"""
%   logging.debug(f'{template}:{user}: executing "save_article()"')
%   ERR = ''
%   page = ''
%   try:
%     (acl_users, acl_ips, acl_time, editors) = process_acl()
%   except Exception as e:
%     logging.error(f'{template}:{user}: invalid ACL detected [{e}]')
%     ERR = 'invalid ACL'
%     return (page, ERR)
%   end
%   (koi_data, page, page_fp, new) = get_koi_data(acl_users, acl_ips, acl_time, editors)
%   koi_file_fp = os.path.join(page_fp, 'article.koi')
%   if new:
%     try:
%       os.mkdir(page_fp, mode=0o700)
%     except Exception as e:
%       logging.error(f'{template}:{user}: unable to make the directory "{page_fp}" [{e}]')
%       ERR = 'unable to save the article'
%       return (page, ERR)
%     end
%   else:
%     rev = INDEX[page]['rev']
%     bak_file_fp = os.path.join(page_fp, f'.article.koi-{rev}')
%     try:
%       os.rename(koi_file_fp, bak_file_fp)
%     except Exception as e:
%       logging.error(f'{template}:{user}: unable to backup "{koi_file_fp}" [{e}]')
%       ERR = 'unable to save the article'
%       return (page, ERR)
%     end
%   end
%   ERR = save_json(koi_file_fp, koi_data, 'article')
%   if ERR:
%     return (page, ERR)
%   end
%   slug = QUERY.get('slug', '')
%   if not new and slug != page:
%     (slug, ERR) = check_slug(slug)
%     if not ERR:
%       try:
%         slug_fp = os.path.join(os.path.dirname(page_fp), slug)
%         # os.rename(page_fp, slug_fp.encode('utf-8'))
%         os.rename(page_fp, slug_fp)
%         logging.debug(f'{template}:{user}: renamed slug "{page}" to "{slug}"')
%         page = slug
%       except Exception as e:
%         ERR = 'unable to rename slug'
%         logging.error(f'{template}:{user}: {ERR} "{slug}" [{e}]')
%       end
%     end
%   end
%   return (page, ERR)
% end
%
% #####################################################################################
%
% def save_upload(page_fp):
%   """
    save_upload(page_fp[str]) -> (files[dict], ERR[str])

    Save all files from an upload returning a dictionary with
    information about each file.

"""
%   logging.debug(f'{template}:{user}: executing "save_upload({page_fp})"')
%   files = {}
%   ERR = ''
%   max_msg = f'max: {max_up_size}'
%   if not UPLOAD:
%     ERR = 'no upload file found'
%     logging.debug(f'{template}:{user}: "{ERR}"')
%   else:
%     for key, up in UPLOAD.items():
%       file_name = up['safe_name']
%       if os.path.splitext(file_name)[1].lower() not in PAGE['upload']['exts']:
%         logging.error(f'{template}:{user}: attempted to upload a non-valid file "{file_name}" (tampering?)')
%         raise SystemExit
%       end
%       try:
%         if not up['OK']:
%           logging.debug(f'{template}:{user}: file "{file_name}" is too large ({max_msg})')
%           raise IOError(f'file too large ({max_msg})')
%         end
%         file_name_fp = os.path.join(page_fp, file_name)
%         if os.path.exists(file_name_fp) and not PAGE['upload']['overwrite']:
%           logging.debug(f'{template}:{user}: will not over-write "{file_name}"')
%           raise IOError(f'file already exists')
%         end
%         with open(file_name_fp, 'wb') as fd:
%           fd.write(up['file_data'])
%         end
%         ftype = up['content_type']
%         fsize = len(up['file_data'])
%         files[file_name] = {'OK': True, 'status': 'success', 'type': ftype, 'size': fsize}
%         logging.debug(f'{template}:{user}: saved file "{file_name}"')
%       except IOError as e:
%         files[file_name] = {'OK': False, 'status': e}
%       except Exception as e:
%         logging.error(f'{template}:{user}: unable to save file "{file_name}" [{e}]')
%         files[file_name] = {'OK': False, 'status': 'unable to save file'}
%       end
%     end
%   end
%   return (files, ERR)
% end
%
% #####################################################################################
% logging.info(f'{template}:{user}: processing DOCTYPE')
<!DOCTYPE html>
  <head>
    <script>
      function goBack() {window.history.back();}
    </script>
    % include('head.tpl')
    <title>{{PAGE['title']}}</title>
  </head>
  <body>
    <div class="container">
      % include('header.tpl', show_search=True, show_login=False, hr=True)
% #####################################################################################
      % if not any(i.lower() == user.lower() for i in CONFIG['site_editors']):
          <p><font class="error">you must be an editor to access this page</font></p>
% #####################################################################################
      % elif no_bleach:
          <div class="row">
            <div class="twelve columns">
              <font class="error">{{ERR}}</font>
            </div>
          </div>
% #####################################################################################
      % elif not 'action' in QUERY:
      %   logging.debug(f'{template}:{user}: displaying pages list')
      %   art_listing = get_listing('article')
      %   gal_listing = get_listing('gallery')
          <form id="new_article" action="{{ME['uri']}}" method="post">
            {{!xCSRF}}
          </form>
          <form id="new_gallery" action="{{ME['uri']}}" method="post">
            {{!xCSRF}}
          </form>
          <form id="ask_delete" action="{{ME['uri']}}" method="post">
            {{!xCSRF}}
            <input name="action" type="hidden" value="ask_delete">
          </form>
          <form id="edit" action="{{ME['uri']}}" method="post">
            {{!xCSRF}}
            <input name="action" type="hidden" value="edit">
          </form>
          <h6 id="articles">Articles</h6>
          <div class="row navstrip">
            <div class="twelve columns">
              <span title="write a new article">
                <button form="new_article" class="button-primary" name="action"
                        value="new_article" type="submit">
                  new
                </button>
              </span>
            </div>
          </div>
          <div class="row">
            <div class="twelve columns">
              <ul>
      %         for i in sorted(art_listing, key=lambda x: x['title'].lower()):
      %           # "listing" entries are of the form:
      %           #  {'page': page, 'title': title, 'item': item, 'popup': popup, 'warn': warn}
                  <li>{{!i['warn']}}
                    <span title="{{i['popup']}}">
      %               # There is no good reason for article pages to have
      %               # unsafe names, so escaped regardless (no "!") as an
      %               # abundance of caution.
                      <button form="edit" class="button" name="page" type="submit"
                              value="{{i['page']}}">
                        {{i['item']}}
                      </button>
                    </span>
                    <span title="delete this article">
                      <button form="ask_delete" class="button xButton" name="page"
                              type="submit" value="{{i['page']}}">
                        &#9747;
                      </button>
                    </span>
                  </li>
      %         end
              </ul>
            </div>
          </div>
          <h6 id="galleries">Galleries</h6>
          <div class="row navstrip">
            <div class="twelve columns">
              <span title="create a new gallery">
                <button form="new_gallery" class="button-primary" name="action"
                        value="new_gallery" type="submit">
                  new
                </button>
              </span>
            </div>
          </div>
          <div class="row">
            <div class="twelve columns">
              <ul>
      %         for i in sorted(gal_listing, key=lambda x: x['title'].lower()):
                  <li>
                    <span title="{{i['popup']}}">
                      <a href="/{{pages}}/{{i['page']}}" class="button">{{i['item']}}</a>
                    </span>
                    <span title="delete this gallery">
                      <button form="ask_delete" class="button xButton" name="page"
                              type="submit" value="{{i['page']}}">
                        &#9747;
                      </button>
                    </span>
                  </li>
      %         end
              </ul>
            </div>
          </div>
% #####################################################################################
      % elif QUERY.get('action', '') == 'ask_delete':
      %   (page, page_fp, title) = get_page()
      %   if not title:
      %      title = 'untitled'
      %   end
      %   check_editors(page)
      %   file = os.path.basename(get_file_fp(page))
          <form id="do_delete" action="{{ME['uri']}}" method="post">
            {{!xCSRF}}
            <input form="do_delete" name="page" type="hidden" value="{{page}}">
          </form>
      %   # Created/uploaded pages and file names are highly sanitized.
      %   if file:
      %     uri = f'/{pages}/{page}/{file}'
            <input form="do_delete" name="file" type="hidden" value="{{file}}">
      %     title = file
      %   else:
      %     uri = TREE[page]['uri']
      %   end
          <div class="row navstrip">
            <div class="twelve columns">
              <button class="button" onclick="goBack()">go back</button>
            </div>
          </div>
          <div class="row">
            <div class="twelve columns">
              Are you sure you want to delete
              <span title="open in a new tab">
                <a href="{{uri}}" class="button" target="_blank" >{{title}}</a>
              </span>
              <span title="confirm delete">
                <button form="do_delete" class="button xButton" name="action"
                        type="submit" value="do_delete">
                  &#9747;
                </button> ?
              </span>
            </div>
          </div>
% #####################################################################################
      % elif QUERY.get('action', '') == 'do_delete':
      %   (page, page_fp, title) = get_page()
      %   check_editors(page)
      %   if file_fp := get_file_fp(page):
      %     item = 'File'
      %     name = os.path.basename(file_fp)
      %     ERR = delete(file_fp=file_fp)
      %   else:
      %     item = TREE[page]['template'].capitalize()
      %     name = title
      %     ERR = delete(page=page, page_fp=page_fp)
      %   end
      %   if not ERR:
            <form id="file_manager" action="{{ME['uri']}}" method="post">
              {{!xCSRF}}
              <input type="hidden" name="action" value="file_manager">
            </form>
            <form id="edit" action="{{ME['uri']}}" method="post">
              {{!xCSRF}}
              <input name="action" type="hidden" value="edit">
            </form>
            <div class="row navstrip">
              <div class="twelve columns">
      %         if not file_fp:
                  <span title="return to the pages list">
                    <a class="button" href="{{ME['uri']}}">pages</a>
                  </span>
      %         else:
                  <span title="go to the file manager">
                    <button form="file_manager" class="button" name="page" type="submit"
                            value="{{page}}">files</button>
                  </span> |
                  <span title="edit the article">
                    <button form="edit" class="button" name="page" type="submit"
                            value="{{page}}">edit</button>
                  </span>
      %         end
              </div>
            </div>
            <div class="row"
              <div class="twelve columns">
                {{item}} <em>{{name}}</em> deleted.
              </div>
            </div>
      %   else:
            <div class="row navstrip">
              <div class="twelve columns">
                <button class="button" onclick="goBack()">Go Back</button>
              </div>
            </div>
            <div class="row">
              <div class="twelve columns">
                <font class="error">{{ERR}}</font>
              </div>
            </div>
      %   end
% #####################################################################################
      % elif QUERY.get('action', '') == 'new_gallery':
      %   logging.info(f'{template}:{user}: creating a new gallery')
      %   (page, ERR) = new_gallery()
      %   if not ERR:
            <meta http-equiv="refresh" content="0;URL='/{{pages}}/{{page}}?xCSRF={{PROFILE['xCSRF']}}'">
      %   else:
            <div class="row">
              <div class="twelve columns">
                <font class="error">{{ERR}}</font>
              </div>
            </div>
      %   end
% #####################################################################################
      % elif QUERY.get('action', '') == 'new_article':
      %   logging.info(f'{template}:{user}: writing a new article')
      %   acl = art_ACL.format(name='untitled', item='page', acl_users=user.lower(), \
      %                    acl_time=time.strftime(clock_format, time.localtime()), \
      %                    acl_ips='*', editors=user.lower(), \
      %                    formID='save_article', trusted='')
          <form id="save_article" action="{{ME['uri']}}" method="post">
            {{!xCSRF}}
          </form>
          <div class="row navstrip">
            <div class="twelve columns">
              <span title="return to the article list">
                <a class="button" href="{{ME['uri']}}">
                  articles
                </a>
              </span> |
              <span title="save your edits">
                <button form="save_article" class="button-primary" name="action"
                        type="submit" value="save_article">
                  save
                </button>
              </span>
            </div>
          </div>
          <div class="row">
            <div class="twelve columns">
              {{!acl}}
            </div>
          </div>
          <div class="row">
            <div class="seven columns">
              <input form="save_article" name="title" placeholder="title" size="40"
                     type="text">
            </div>
            <div class="five columns">
              <span title="space-separated list of keywords">
                <input form="save_article" class="u-pull-right" placeholder="keywords"
                       name="keywords" size="20" type="text">
              </span>
            </div>
          </div>
          <div class="row">
            <div class="twelve columns">
              <textarea form="save_article" name="body" placeholder="body"
                        rows="15"></textarea>
            </div>
          </div>
          <div class="row">
            <div class="twelve columns">
              {{!md_help}}
            </div>
          </div>
% #####################################################################################
      % elif QUERY.get('action', '') == 'edit':
      %   (page, page_fp, title) = get_page()
      %   check_editors(page)
      %   if INDEX[page]['trusted']:
      %     trusted = '(<k>trusted</k>)'
      %   else:
      %     trusted = ''
      %   end
      %   logging.info(f'{template}:{user}: editing existing page "{page}"')
      %   uri = f'/{pages}/{page}'
      %   koi_acl = INDEX[page]['acl']['article.koi']
      %   clock = datetime.datetime.fromtimestamp(koi_acl['time']).strftime(clock_format)
      %   acl = art_ACL.format(name=title, item='page', acl_users=' '.join(koi_acl['users']), \
      %                    acl_ips=' '.join(koi_acl['ips']), \
      %                    editors=' '.join(INDEX[page]['editors']), \
      %                    acl_time=clock, formID='save_article', trusted=trusted)
      %   body = INDEX[page]['body']
          <form id="file_manager" action="{{ME['uri']}}" method="post">
            {{!xCSRF}}
            <input type="hidden" name="action" value="file_manager">
          </form>
          <form id="file_uploader" action="{{ME['uri']}}" method="post">
            {{!xCSRF}}
            <input type="hidden" name="action" value="file_uploader">
          </form>
          <form id="save_article" method="post" action="{{ME['uri']}}">
            {{!xCSRF}}
            <input type="hidden" name="page" value="{{page}}">
          </form>
          <div class="row navstrip">
            <div class="twelve columns">
              <span title="opens page in new tab">
                <a class="button" href="{{uri}}" target="_blank">webpage</a>
              </span> |
              <span title="go to the file manager">
                <button form="file_manager" class="button" name="page" type="submit"
                        value="{{page}}">files</button>
              </span> |
              <span title="upload files">
                <button form="file_uploader" class="button" name="page" type="submit"
                        value="{{page}}">uploader</button>
              </span> |
              <span title="return to the articles list">
                <a class="button" href="{{ME['uri']}}">articles</a>
              </span> |
              <span title="save your edits">
                <button form="save_article" class="button-primary" name="action"
                        type="submit" value="save_article">save</button>
              </span>
       %      if QUERY.get('saved', ''):
                <span style="margin-left: 10px" class="fade-out"><k>saved</k></span>
       %      end
            </div>
          </div>
          {{!acl}}
          <div class="row">
            <div class="six columns">
              <span title="title">
      %         # Even bleach'ed HTML cannot be safely used in an HTML attribute
      %         # https://bleach.readthedocs.io/en/latest/clean.html
                <input form="save_article" name="title" placeholder="title"
                       size="35" type="text" value="{{title}}">
              </span>
            </div>
            <div class="two columns">
              <span title="slug ({{CONFIG['slug_re']}})">
                <input required form="save_article" name="slug" pattern="{{!CONFIG['slug_re']}}"
                       size="8" type="text" value="{{page}}">
              </span>
            </div>
            <div class="four columns">
              <span title="space-separated list of keywords">
                <input form="save_article" class="u-pull-right" name="keywords"
                       placeholder="keywords" size="20" type="text"
                       value="{{INDEX[page]['keywords']}}">
              </span>
            </div>
          </div>
          <div class="row">
            <div class="twelve columns">
              <span title="article body">
      %         # bleach'ed HTML is OK in an HTML context
                <textarea form="save_article" name="body"
                          placeholder="body" rows="15">{{!body}}</textarea>
              </span>
            </div>
          </div>
          <div class="row">
            <div class="twelve columns">
              {{!md_help}}
            </div>
          </div>
% #####################################################################################
      % elif QUERY.get('action', '') == 'file_manager':
      %   (page, page_fp, title) = get_page()
      %   if not title:
      %      title = 'untitled'
      %   end
      %   check_editors(page)
      %   logging.info(f'{template}:{user}: managing files from "{page}"')
      %   uri = f'/{pages}/{page}'
      %   page_acl = INDEX[page]['acl']
      %   img_list = ['.jpg', '.jpeg', '.png', '.gif', '.tif', '.tiff', '.svg', '.mng', \
      %               '.webp', '.apng', '.jp2', '.jxl', '.bmp', '.jfif', '.heic', '.jxr']
      %   n = 0
          <form id="ask_delete" action="{{ME['uri']}}" method="post">
            {{!xCSRF}}
            <input type="hidden" name="page" value="{{page}}">
            <input type="hidden" name="action" value="ask_delete">
          </form>
          <form id="edit" action="{{ME['uri']}}" method="post">
            {{!xCSRF}}
            <input name="action" type="hidden" value="edit">
          </form>
          <form id="file_uploader" action="{{ME['uri']}}" method="post">
            {{!xCSRF}}
            <input type="hidden" name="action" value="file_uploader">
          </form>
          <div class="row navstrip">
            <div class="twelve columns">
              <span title="edit the article">
                 <button form="edit" class="button" name="page" type="submit"
                         value="{{page}}">edit</button>
              </span> |
              <span title="upload files">
                <button form="file_uploader" class="button" name="page" type="submit"
                        value="{{page}}">uploader</button>
              </span>
            </div>
          </div>
          <div class="row">
            <div class="twelve columns">
              <p>
                Files in
                <span title="{{title}} (opens in new tab)">
                  <a class="button" href="{{uri}}" target="_blank">{{title}}</a>
                </span>
              </p>
              <ol style="margin-top: 15px;">
      %         for file in sorted(TREE[page]['files'], key=str.lower):
      %           if file.startswith(CONFIG['noserve_prefix']) or \
      %              file.endswith(CONFIG['noserve_suffix']) or file.endswith('.koi'):
      %             continue
      %           end
      %           n += 1
      %           if file in page_acl:
      %             origin = "(currently assigned)"
      %             acl_users = ' '.join(page_acl[file]['users'])
      %             acl_ips = ' '.join(page_acl[file]['ips'])
      %             acl_time = datetime.datetime.fromtimestamp(page_acl[file]['time']).\
      %                        strftime(clock_format)
      %           else:
      %             origin = "(currently inherited from page)"
      %             acl_users = ' '.join(page_acl['article.koi']['users'])
      %             acl_ips = ' '.join(page_acl['article.koi']['ips'])
      %             acl_time = datetime.datetime.fromtimestamp(page_acl['article.koi']['time']).\
      %                        strftime(clock_format)
      %           end
      %           (ref, ext) = os.path.splitext(file)
      %           if ext.lower() in img_list:
      %              link = f'![{ref}]({uri}/{file} "{ref}")'
      %           else:
      %              link = f'[{ref}]({uri}/{file})'
      %           end
      %           acl = file_ACL.format(name=file, item='file', acl_users=acl_users, acl_ips=acl_ips,
      %                            acl_time=acl_time, formID=f'save_file_acl_{n}', origin=origin)
                  <li>
                    <span title="open file in new tab">
                      <a class="button" href="{{uri}}/{{file}}"
                         style="text-transform: none;" target="_blank">{{file}}</a>
                    </span>
                    <span title="delete this file">
                      <button form="ask_delete" class="button xButton" name="file" type="submit"
                              value="{{file}}">
                        &#9747;
                      </button>
                    </span>
                    <form id="save_file_acl_{{n}}" action="{{ME['uri']}}" style="display: inline;"
                          method="post">
                      {{!xCSRF}}
                      <input type="hidden" name="page" value="{{page}}">
                      <input form="save_file_acl_{{n}}" name="file" type="hidden" value="{{file}}">
                      <span title="save acl">
                        <button form="save_file_acl_{{n}}" class="button-primary" name="action"
                                type="submit" value="save_file_acl">
                          save
                        </button>
                      </span>
                      <span title="markdown link to file">
                        <input style="margin-left: 20px;" disabled value='{{link}}' size="40">
                      </span>
                      {{!acl}}
                    </form>
                  </li>
      %         end
              </ol>
            </div>
          </div>
      %   if not n:
            <div class="row">
              <div class="twelve columns">
                No files have been uploaded to this page.
              </div>
            </div>
      %   end
% #####################################################################################
      % elif QUERY.get('action', '') == 'save_file_acl':
      %   (page, page_fp, title) = get_page()
      %   check_editors(page)
      %   file = os.path.basename(get_file_fp(page))
      %   if not file:
      %     logging.error(f'{template}:{user}: file is missing in request (tampering?)')
      %     raise SystemExit
      %   end
      %   (page, ERR) = save_file_acl(page, page_fp, file)
      %   if ERR:
            <p><font class="error">{{ERR}}</font></p>
            <button class="button" onclick="goBack()">Go Back</button>
      %   else:
            <button class="button" onclick="goBack()">Go Back</button> |
            <form style="display: inline;" method="post" action="{{ME['uri']}}">
              {{!xCSRF}}
              <input type="hidden" name="page" value="{{page}}">
              <button class="button" name="action" value="edit" type="submit">editor</button>
            </form>
            <p>File ACL saved</p>
      %   end
% #####################################################################################
      % elif QUERY.get('action', '') == 'save_article':
      %   (page, ERR) = save_article()
      %   uri = f'/{pages}/{page}'
      %   logging.debug(f'{template}:{user}: saving article "{page}"')
      %   if ERR:
            <p><font class="error">{{ERR}}</font></p>
            <button class="button" onclick="goBack()">Go Back</button>
      %   else:
            <meta http-equiv="refresh" content="0;URL='{{ME['uri']}}?action=edit&page={{page}}&saved=OK&xCSRF={{PROFILE['xCSRF']}}'">
      %   end
% #####################################################################################
      % elif QUERY.get('action', '') == 'file_uploader':
      %   (page, page_fp, title) = get_page()
      %   if not title:
      %      title = 'untitled'
      %   end
      %   check_editors(page)
      %   logging.debug(f'{template}:{user}: running file_uploader on page "{page}"')
      %   uri = f'/{pages}/{page}'
      %   if PAGE['upload']['overwrite']:
      %     action = "will be"
      %   else:
      %     action = "will not be"
      %   end
          <form id="file_manager" action="{{ME['uri']}}" method="post">
            {{!xCSRF}}
            <input type="hidden" name="action" value="file_manager">
          </form>
          <form id="upload" action="{{ME['uri']}}" enctype="multipart/form-data"
                method="post">
            {{!xCSRF}}
            <input name="page" type="hidden" value="{{page}}">
          </form>
          <form id="edit" action="{{ME['uri']}}" method="post">
            {{!xCSRF}}
            <input name="action" type="hidden" value="edit">
          </form>
          <div class="row navstrip">
            <div class="twelve columns">
              <span title="edit the article">
                 <button form="edit" class="button" name="page" type="submit"
                         value="{{page}}">edit</button>
              </span> |
              <span title="go to the file manager">
                <button form="file_manager" class="button" name="page" type="submit"
                        value="{{page}}">files</button>
              </span> |
              <input form="upload" class="button-primary" name="action" type="submit"
                     value="upload">
            </div>
          </div>
          <div class="row">
            <div class="twelve columns">
              <p>
                Select up to {{CONFIG['upload_max_files']}} files to upload to
                <span title="{{title}} (opens in new tab)">
                  <a class="button" href="{{uri}}" target="_blank">{{title}}</a>
                </span>
              </p>
              <p>
                Note that existing files with the same name {{action}} overwritten.<br>
                Allowed extensions are: <k>&middot;</k> {{!' <k>&middot;</k> '.join(PAGE['upload']['exts'])}}
                (max size: {{max_up_size}} each)
              </p>
            </div>
          </div>
          <div class="row">
            <div class="twelve columns">
              <p>
                <input form="upload" accept="{{', '.join(PAGE['upload']['exts'])}}"
                       name="file_upload" type="file" multiple>
              </p>
            </div>
          </div>
% #####################################################################################
      % elif QUERY.get('action', '') == 'upload':
      %   (page, page_fp, title) = get_page()
      %   if not title:
      %      title = 'untitled'
      %   end
      %   check_editors(page)
      %   (files, ERR) = save_upload(page_fp)
      %   logging.debug(f'{template}:{user}: uploading files to page "{page}"')
      %   uri = f'/{pages}/{page}'
          <form id="edit" action="{{ME['uri']}}" method="post">
            {{!xCSRF}}
            <input name="action" type="hidden" value="edit">
          </form>
          <form id="file_manager" action="{{ME['uri']}}" method="post">
            {{!xCSRF}}
            <input type="hidden" name="action" value="file_manager">
          </form>
          <div class="row navstrip">
            <div class="twelve columns">
              <button class="button" onclick="goBack()">Go Back</button> |
              <span title="{{title}} (opens in new tab)">
                <a href="{{uri}}" class="button" target="_blank">webpage</a>
              </span> |
              <span title="go to the file manager">
                <button form="file_manager" class="button" name="page" type="submit"
                        value="{{page}}">files</button>
              </span> |
              <span title="edit the article">
                <button form="edit" class="button" name="page" type="submit"
                        value="{{page}}">edit
                </button>
              </span>
            </div>
          </div>
      %   for key, entry in files.items():
      %     if entry['OK']:
              <p>
                Saved file
                <span title="open file in new tab">
                  <a class="button" href="{{uri}}/{{key}}"
                     style="text-transform: none;" target="_blank">{{key}}</a>
                </span>
              </p>
      %     else:
              <p>
                Unable to save file <em>{{key}}</em>: <font class="error">{{entry['status']}}</font>
              </p>
      %     end
      %   end
      %   if ERR:
            <div class="row">
              <div class="twelve columns">
                <font class="error">{{ERR}}</font>
              </div>
            </div>
      %   end
% #####################################################################################
      % else:
      %   logging.debug(f'{template}:{user}: unknown action requested')
          <p><font class="error">unknown action requested</font></p>
      % end
% #####################################################################################
    </div>
  </body>
</html>
