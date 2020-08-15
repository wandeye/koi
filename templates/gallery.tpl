% import logging
% template = ME['template']+'.tpl'
% if user := PROFILE.get('user', ''):
%   xCSRF = f'<input name="xCSRF" type="hidden" value="{PROFILE["xCSRF"]}">'
% else:
%   xCSRF = ''
% end
% logging.info(f'{template}:{user}: processing template')
% clock_format = '%Y-%m-%dT%H:%M'
% ACL = """<p>
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
             {item} public. All photos are individually subject
             to the same ACL as the gallery and cannot be accessed
             otherwise.
           </p>
           <div class="row">
             <div class="four columns">
               <span title="who can view the {item}?">
                 <input required form="{formID}" name="who" size="19"
                        type="text" value="{acl_users}">
               </span>
             </div>
             <div class="four columns">
               <span title="from that IPs?">
                 <input required form="{formID}" class="u-pull-left"
                        name="where" size="17" type="text"
                        value="{acl_ips}">
               </span>
             </div>
             <div class="four columns">
               <span title="when is the {item} accessible?">
                 <input required form="{formID}" class="u-pull-right"
                        name="when" size="15" type="datetime-local"
                        value="{acl_time}">
               </span>
             </div>
           </div>
           <hr>"""
%
% import random
% import os
% import copy
% import time
% import datetime
% import json
% import socket
% import re
%
% no_pil = False
% try:
%   from PIL import Image, ImageDraw, ImageOps
%   import PIL.ExifTags as PILX
% except:
%   logging.error(f'{template}:{user}: could not import PIL')
%   no_pil = True
%   ERR = 'you need to install PIL'
% end
% no_bleach = False
% try:
%   import bleach
% except:
%   logging.error(f'{template}:{user}: could not import bleach')
%   no_bleach = True
%   ERR = 'you need to install bleach'
% end
% no_ns = False
% try:
%   import natsort
% except:
%   logging.warning(f'{template}:{user}: could not import natsort')
%   no_ns = True
% end
%
% pages = CONFIG['dir_pages']
% assets = CONFIG['page_assets']
% valid_slug = re.compile(CONFIG['slug_re'])
% hst_ext = '.hst.png'
% tn_ext = '.tn.jpg'
%
% #####################################################################################
%
% def check_slug(slug):
%   """
    check_slug(slug[str]) -> (slug[str], ERR[str])

    Check the validity of the slug.

"""
%   logging.debug(f'{template}:{user}: executing "check_slug({slug})"')
%   ERR = ''
%   if not valid_slug.match(slug):
%     ERR = 'slug does not match slug_re'
%     logging.debug(f'{template}:{user}: {ERR}')
%     return (slug,  ERR)
%   end
%   if os.path.isdir(os.path.join(os.path.dirname(ME['path']), slug)):
%     ERR = 'slug already exists'
%     logging.debug(f'{template}:{user}: {ERR}')
%   end
%   return (slug, ERR)
% end
%
% #####################################################################################
%
% def check_editor(must=True):
%   """
    check_editor(must[bool]) -> editor[bool]

    Check editor credentials. Unless input has been tampered with this
    function should always return, hence the finality of raising a SystemExit
    if "must" is "True".

"""
%   logging.debug(f'{template}:{user}: executing "check_editor({must})"')
%   editor = False
%   if user and ('*' in PAGE['editors'] or user.lower() in PAGE['editors']):
%     editor = True
%   end
%   if must and not editor:
%     logging.error(f'{template}:{user}: user "{user}" is not a editor (tampering?)')
%     raise SystemExit
%   end
%   return editor
% end
%
% #####################################################################################
%
% def get_img_id():
%   """
    get_img_id() -> img_id[str]

    Get an image from QUERY and verify its validity. Unless input has been tampered
    with this function should always return, hence the finality of raising a SystemExit.

"""
%   logging.debug(f'{template}:{user}: executing "get_img_id()"')
%   img_id = QUERY.get('img_id', '')
%   if img_id not in PAGE['library']:
%     logging.error(f'{template}:{user}: invalid image "{img_id}" (tampering?)')
%     raise SystemExit
%   end
%   return img_id
% end
%
% #####################################################################################
%
% def get_exif(img_fp):
%   """
    get_exif(img_fp[str]) -> exif_data[dict]

    Given an image's full path return its EXIF data.

"""
%   logging.debug(f'{template}:{user}: executing "get_exif({img_fp})"')
%   im = Image.open(img_fp)
%   exif_data = {}
%   exif2label = {'DateTimeOriginal': 'date taken', 'ExposureTime': 'exposure time', \
%                 'FocalLength': 'focal length (mm)', 'FNumber': 'aperture', \
%                 'ISOSpeedRatings': 'ISO', 'ExposureProgram': 'exposure', \
%                 'Flash': 'flash', 'MeteringMode': 'metering mode', \
%                 'WhiteBalance': 'white balance', 'FocalLengthIn35mmFilm': '35mm equiv', \
%                 'Model': 'camera model', 'Flash': 'flash'}
%   # http://www.awaresystems.be/imaging/tiff/tifftags/privateifd/exif.html
%   ep = {0: 'not defined', 1: 'manual', 2: 'normal program', \
%         3: 'aperture priority', 4: 'shutter priority', 5: 'creative program', \
%         6: 'action program', 7: 'portrait mode', 8: 'landscape mode'}
%   mm = {0: 'unknown', 1: 'average', 2: 'center weighted average', 3: 'spot', \
%         4: 'multi spot', 5: 'pattern', 6: 'partial', 255: 'other', 65535: 'unknown'}
%   wb = {0: 'auto', 1: 'manual'}
%   # Full flash codes at:
%   # http://www.awaresystems.be/imaging/tiff/tifftags/privateifd/exif/flash.html
%   # Real way of doing this:
%   #   (hex code) & (bit value) == (bit value)
%   # e.g. for strobe light (bits 1 and 2 on => 000110):
%   #   0x001D & int('000110', 2) == int('000110', 2) => False
%   #   0x001F & int('000110', 2) == int('000110', 2) => True
%   # Flash is off for: 0x000 0x010 0x018 0x020
%   try:
%     exif_it = im._getexif().items()
%   except Exception as e:
%     logging.debug(f'{template}:{user}: unable to extract EXIF data')
%     return exif_data
%   end
%   if exif_it:
%     exif_dict = dict((PILX.TAGS[k], v) for (k, v) in exif_it if k in PILX.TAGS)
%   end
%   for k, v in exif_dict.items():
%     if k in exif2label:
%       if k == 'ExposureProgram':
%         exif_data[exif2label[k]] = ep[v]
%       elif k == 'MeteringMode':
%         exif_data[exif2label[k]] = mm[v]
%       elif k == 'WhiteBalance':
%         exif_data[exif2label[k]] = wb[v]
%       elif k == 'FocalLength':
%         exif_data[exif2label[k]] = f'{int(v[0]/v[1])}'
%       elif k == 'FNumber':
%         exif_data[exif2label[k]] = f'f/{v[0]/v[1]}'
%       elif k == 'Model':
%         exif_data[exif2label[k]] = v.lower()
%       elif k == 'ExposureTime':
%         exif_data[exif2label[k]] = f'{int(v[0]/10)}/{int(v[1]/10)}s'
%       elif k == 'Flash':
%         if v in [0, 16, 24, 32]:
%           exif_data[exif2label[k]] = 'off'
%         else:
%           exif_data[exif2label[k]] = 'on'
%         end
%       else:
%         exif_data[exif2label[k]] = v
%       end
%     end
%   end
%   (xpix, ypix) = im.size
%   exif_data['geometry'] = f'{xpix}x{ypix}px'
%   exif_data['size'] = f'{os.stat(img_fp).st_size/1000}kB'
%   return exif_data
% end
%
% #####################################################################################
%
% def make_tn(img_fp):
%   """
    make_fn(img_fp[str]) -> tn_fp[str]

    Given an image's full path generate a thumbnail and retun its full path.

"""
%   logging.debug(f'{template}:{user}: executing "make_tn({img_fp})"')
%   tn_fp = ''
%   tn_fp = img_fp+tn_ext
%   is_tn = os.path.exists(tn_fp)
%   img_ts = os.stat(img_fp).st_mtime
%   if is_tn and os.stat(tn_fp).st_mtime >= img_ts:
%     return tn_fp
%   end
%   im = Image.open(img_fp)
%   try:
%     if is_tn:
%       os.remove(tn_fp)
%     end
%     tn_dict = PAGE['thumbnail']
%     if tn_dict['square']:
%       TN = ImageOps.fit(im, tn_dict['size'], Image.ANTIALIAS)
%     else:
%       TN = im.copy()
%       TN.thumbnail(tn_dict['size'], Image.ANTIALIAS)
%     end
%     if TN.mode != 'RGB':
%       TN = TN.convert('RGB')
%     end
%     TN.save(tn_fp, tn_dict['type'], quality=tn_dict['quality'], \
%             optimize=tn_dict['optimize'], progressive=tn_dict['progressive'])
%     os.chmod(tn_fp, 0o600)
%   except Exception as e:
%       logging.debug(f'{template}:{user}: error creating thumbnail {tn_fp} [{e}]')
%       tn_fp = ''
%   end
%   return tn_fp
% end
%
% #####################################################################################
%
% # http://tophattaylor.blogspot.ca/2009/05/python-rgb-histogram.html
% # http://www.cambridgeincolour.com/tutorials/histograms2.htm
% # http://stackoverflow.com/questions/596216/formula-to-determine-brightness-of-rgb-color
% # http://alienryderflex.com/hsp.html
% def make_hst(img_fp):
%   """
    make_hst(img_fp[str]) -> hst_fp[str]

    Given an image's full path generate a histogram (if PAGE['histogram']['create']
    is True) and retun its full path.

"""
%   logging.debug(f'{template}:{user}: executing "make_hst({img_fp})"')
%   hst_fp = ''
%   if not PAGE['histogram']['create']:
%     return hst_fp
%   end
%   hst_fp = img_fp+hst_ext
%   is_hst = os.path.exists(hst_fp)
%   img_ts = os.stat(img_fp).st_mtime
%   if is_hst and os.stat(hst_fp).st_mtime >= img_ts:
%     return hst_fp
%   end
%   im = Image.open(img_fp)
%   try:
%     if is_hst:
%       os.remove(hst_fp)
%     end
%     rgb_hst = im.histogram()
%     depth = len(rgb_hst)
%     bdr_col = tuple(PAGE['histogram']['border_col'])
%     fg_col = tuple(PAGE['histogram']['fg_col'])
%     bg_col = tuple(PAGE['histogram']['bg_col'])
%     lin_col = tuple(PAGE['histogram']['lines_col'])
%     height = PAGE['histogram']['height']
%     n_lines = PAGE['histogram']['n_lines']
%     if depth in [768, 1024]:
%       r_hst = rgb_hst[0:256]
%       g_hst = rgb_hst[256:512]
%       b_hst = rgb_hst[512:768]
%       rw = 0.299; gw = 0.587; bw = 0.114
%       hst_data = [(rw*r_hst[i]**2 + gw*g_hst[i]**2 + bw*b_hst[i]**2)**0.5 for \
%                   i in range(0,256)]
%     elif depth == 256:
%       hst_data = rgb_hst
%     else:
%       raise ValueError
%     end
%     width = len(hst_data)
%     y_scale = height/max(hst_data)
%     canvas = Image.new("RGBA", (width, height), bg_col)
%     draw = ImageDraw.Draw(canvas)
%     if n_lines:
%       xmarker = width/n_lines
%       x = 0
%       for i in range(1, n_lines+1):
%         draw.line((x, 0, x, height), fill=lin_col)
%         x+=xmarker
%       end
%     end
%     x=0
%     for i in hst_data:
%       if int(i)==0:
%         pass
%       else:
%         draw.line((x, height, x, height-(i*y_scale)), fill=fg_col)
%       end
%       x+=1
%     end
%     # Top
%     draw.line((0, 0, width, 0), fill=bdr_col)
%     # Right side
%     draw.line((width-1, 0, width-1, height), fill=bdr_col)
%     # Bottom
%     draw.line((0, height-1, width, height-1), fill=bdr_col)
%     # Left side
%     draw.line((0, 0, 0, height), fill=bdr_col)
%     canvas.save(hst_fp, 'PNG')
%     os.chmod(hst_fp, 0o600)
%   except Exception as e:
%       logging.debug(f'{template}:{user}: error creating histogram {hst_fp} [{e}]')
%       hst_fp = ''
%   end
%   return hst_fp
% end
%
% #####################################################################################
%
% def get_slide(slides):
%   """
    make_fn(slides[list]) -> (img_id[str], nxt[str], prev[str])

    Get an img_id (using QUERY data if present) and return the prior
    and net slides (again as an img_id of each). "img_id" is the name of
    the file, btw.

"""
%   logging.debug(f'{template}:{user}: executing "get_slide({slides})"')
%   tot = len(slides)
%   img_id = QUERY.get('img_id', '')
%   # The following also sanitizes img_id:
%   if not img_id:
%     img_id = slides[random.randint(0, tot-1)]
%   elif img_id not in slides:
%     img_id = slides[0]
%   end
%   current = slides.index(img_id)
%   if img_id == slides[-1]:
%     nxt = slides[0]
%   else:
%     nxt = slides[min(current+1, tot-1)]
%   end
%   if img_id == slides[0]:
%     prev = slides[-1]
%   else:
%     prev = slides[max(current-1, 0)]
%   end
%   return (img_id, nxt, prev, tot, current+1)
% end
%
% #####################################################################################
%
% def save_upload():
%   """
    save_upload() -> (files[dict], ERR[str])

    Save all files from an upload returning a dictionary with
    information about each file.

"""
%   logging.debug(f'{template}:{user}: executing "save_upload()"')
%   files = {}
%   ERR = ''
%   max_msg = f'max: {CONFIG["upload_max_size"]/(1024*1024)}MB'
%   if not UPLOAD:
%     ERR = 'no upload file found'
%     logging.debug(f'{template}:{user}: "{ERR}"')
%   else:
%     for key, up in UPLOAD.items():
%       img_id = up['safe_name']
%       if os.path.splitext(img_id)[1].lower() not in PAGE['image']['formats']:
%         logging.error(f'{template}:{user}: attempted to upload a non-valid image "{img_id}" (tampering?)')
%         raise SystemExit
%       end
%       try:
%         if not up['OK']:
%           logging.debug(f'{template}:{user}: file "{img_id}" is too large ({max_msg})')
%           raise IOError
%         end
%         with open(os.path.join(ME['path'], img_id), 'wb') as fd:
%           fd.write(up['file_data'])
%         end
%         ftype = up['content_type']
%         fsize = len(up['file_data'])
%         try:
%           update_library(img_id, action='add')
%           OK = True
%           status = 'success'
%         except Exception as e:
%           logging.debug(f'{template}:{user}: unable to update image library [{e}]')
%           OK = False
%           status = 'unable to update library'
%         end
%         files[img_id] = {'OK': OK, 'status': status, 'type': ftype, 'size': fsize}
%         logging.debug(f'{template}:{user}: saved file "{img_id}"')
%       except IOError:
%         files[img_id] = {'OK': False, 'status': f'file too large ({max_msg})'}
%       except Exception as e:
%         logging.error(f'{template}:{user}: unable to save file "{img_id}" [{e}]')
%         files[img_id] = {'OK': False, 'status': 'unable to save file'}
%       end
%     end
%   end
%   return (files, ERR)
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
%   editors = [i.lower() for i in QUERY['editors'].split()]
%   editors = [i for i in editors if i in users_lc or i == '*']
%   if user.lower() not in editors:
%     editors = [user.lower()] + editors
%   end
%   acl_time = int(time.mktime(time.strptime(QUERY['when'], clock_format)))
%   return (acl_users, acl_ips, acl_time, editors)
% end
%
% #####################################################################################
%
% def update_gallery():
%   """
    update_gallery() -> (page[str], ERR[str])

    Update the gallery ACL in "gallery.koi".

"""
%   logging.debug(f'{template}:{user}: executing "update_gallery()"')
%   ERR = ''
%   page = ME['page']
%   try:
%     title = bleach.clean(QUERY['title'], strip=True)
%     keywords = bleach.clean(QUERY['keywords'], strip=True)
%   except Exception as e:
%     # This CANNOT happen unless input has been tampered with.
%     logging.error(f'{template}:{user}: unexpected QUERY [{e}] (tampering?)')
%     raise SystemExit
%   end
%   koi_data = copy.deepcopy(PAGE)
%   koi_file_fp = os.path.join(ME['path'], 'gallery.koi')
%   (acl_users, acl_ips, acl_time, editors) = process_acl()
%   koi_data['editors'] = editors
%   koi_data['title'] = title
%   koi_data['keywords'] = keywords
%   koi_data['acl']['gallery.koi'] = {'users': acl_users, 'groups': [], 'ips': acl_ips, \
%                                     'time': acl_time}
%   try:
%     with open(koi_file_fp, "w", encoding='utf-8') as fd:
%       json.dump(koi_data, fd, ensure_ascii=False)
%     end
%     os.chmod(koi_file_fp, 0o600)
%   except Exception as e:
%     ERR = 'unable to update gallery'
%     logging.error(f'{template}:{user}: {ERR} "{koi_file_fp}" [{e}]')
%     return (page, ERR)
%   end
%   slug = QUERY.get('slug', '')
%   if slug != page:
%     (slug, ERR) = check_slug(slug)
%     if not ERR:
%       try:
%         slug_fp = os.path.join(os.path.dirname(ME['path']), slug)
%         os.rename(ME['path'], slug_fp)
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
% def update_library(img_id, action):
%   """
    update_library(img_id[str], action[str])

    Update the image library/ACL in "gallery.koi". "action" can be "add", "delete", or
    "update". For "add" the img_id input is sanitized by the upload routine (or added
    through the back-end). For the latter two the img_id must already be present in the
    library.

"""
%   logging.debug(f'{template}:{user}: executing "update_library({img_id}, {action})"')
%   koi_file_fp = os.path.join(ME['path'], 'gallery.koi')
%   # We need a fresh re-read if we're going to run this function in a loop
%   # (the PAGE info becomes stale after the first loop).
%   with open(koi_file_fp, "r", encoding='utf-8') as fd:
%     koi_data = json.load(fd)
%   end
%   img_fp = os.path.join(ME['path'], img_id)
%   if action == 'delete':
%     if os.path.isfile(img_fp):
%       os.remove(img_fp)
%     end
%     if os.path.isfile(img_fp+tn_ext):
%       os.remove(img_fp+tn_ext)
%     end
%     if os.path.isfile(img_fp+hst_ext):
%       os.remove(img_fp+hst_ext)
%     end
%     del koi_data['library'][img_id]
%     if img_id in koi_data['acl']:
%       del koi_data['acl'][img_id]
%     end
%     with open(koi_file_fp, "w", encoding='utf-8') as fd:
%       json.dump(koi_data, fd, ensure_ascii=False)
%     end
%     os.chmod(koi_file_fp, 0o600)
%     return
%   end
%   if action == 'add':
%     hide = PAGE['image']['hide_new']
%   elif action == 'update':
%     if QUERY.get('hide', '') == 'show':
%       hide = False
%     else:
%       hide = True
%     end
%   end
%   koi_data['library'][img_id] = {'watermark': '', 'tags': [], 'caption': '', \
%                                  'comments': {}, 'marked': '', 'data': {}, \
%                                  'hidden': hide, 'talent': {}, 'www': '', 'keywords': '', \
%                                  'email': '', 'photographer': '', 'credits': {}, \
%                                  'social': {}, 'location': '', 'copyright': ''}
%   with open(koi_file_fp, "w", encoding='utf-8') as fd:
%     json.dump(koi_data, fd, ensure_ascii=False)
%   end
%   os.chmod(koi_file_fp, 0o600)
%   return
% end
%
% #####################################################################################
%
% def get_photos(editor):
%   """
    get_photos(editor[bool]) -> (slides[list], show[str])

    Return a list of images (photo file names) and a "show" hidden-input string to
    display hidden images (empty if proper tag is not in QUERY).

"""
%   logging.debug(f'{template}:{user}: executing "get_photos(<images>, {editor})"')
%   images = [i for i in PAGE['library']]
%   if not no_ns:
%     images = natsort.natsorted(images, alg=natsort.ns.IGNORECASE)
%   end
%   if editor:
%     slides = images
%     show = ''
%   elif PAGE['image']['unhide_tag'] in QUERY:
%     slides = images
%     show = f'<input name="{PAGE["image"]["unhide_tag"]}" type="hidden">'
%   else:
%     slides = [i for i in images if not PAGE['library'][i]['hidden']]
%     show = ''
%   end
%   return (slides, show)
% end
%
% #####################################################################################
%
% def sync_db():
%   """
    sync_db() -> (refresh[str], ERR[str])

    Synchronize images on disk with those in the gallery.koi library and return a
    refresh HTML string (empty if not needed).

"""
%   logging.debug(f'{template}:{user}: executing "sync_db()"')
%   ERR = ''
%   refresh = ''
%   images = [i for i in ME['files'] if os.path.splitext(i)[1].lower() in PAGE['image']['formats']]
%   images = [i for i in images if not (i.endswith(tn_ext) or i.endswith(hst_ext))]
%   # Sync database (in case of back-end additions/deletions).
%   for img_id in images:
%     if img_id not in PAGE['library']:
%       try:
%         update_library(img_id, action='add')
%         refresh = '<meta http-equiv="refresh" content="0">'
%       except Exception as e:
%         logging.debug(f'{template}:{user}: unable to update image library [{e}]')
%         ERR = 'unable to update library'
%       end
%     end
%   end
%   for img_id in PAGE['library']:
%     if img_id not in images:
%       try:
%         update_library(img_id, action='delete')
%         refresh = '<meta http-equiv="refresh" content="0">'
%       except Exception as e:
%         logging.debug(f'{template}:{user}: unable to update image library [{e}]')
%         ERR = 'unable to update library'
%       end
%     end
%   end
%   return (refresh, ERR)
% end
%
% #####################################################################################
%
% (refresh, ERR) = sync_db()
% if not (refresh or ERR):
%   editor = check_editor(must=False)
%   (slides, show) = get_photos(editor)
%   tot = len(slides)
% end
% logging.info(f'{template}:{user}: processing DOCTYPE')
<!DOCTYPE html>
  <head>
    {{!refresh}}
    <script>
      function goBack() {window.history.back();}
    </script>
    % include('head.tpl')
    <link rel="stylesheet" href="/{{pages}}/{{assets}}/gallery.css">
    <title>{{PAGE['title']}}</title>
  </head>
  <body>
    <div class="container">
      % include('header.tpl', show_search=True, show_login=True, hr=False)
% #####################################################################################
      % if ERR:
          <p><font class="error">{{ERR}}</font></p>
% #####################################################################################
      % elif refresh:
      %   pass
% #####################################################################################
      % elif no_pil or no_bleach:
          <div class="row">
            <div class="twelve columns">
              <font class="error">{{ERR}}</font>
            </div>
          </div>
% #####################################################################################
      % elif QUERY.get('action', '') == 'upload':
      %   check_editor()
      %   (files, ERR) = save_upload()
          <form id="gallery" action="{{ME['uri']}}" method="post">
            {{!xCSRF}}
          </form>
          <div class="row navstrip">
            <div class="twelve columns">
              <button form="gallery" class="button" name="mode" type="submit"
                      value="grid">gallery
              </button>
            </div>
          </div>
      %   for key, entry in files.items():
      %     if entry['OK']:
              <p>
                Saved file
                <span title="open file in new tab">
                  <a class="button" href="{{ME['uri']}}/{{key}}"
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
      % elif QUERY.get('action', '') == 'update_gallery':
      %   check_editor()
      %   (page, ERR) = update_gallery()
          <form id="gallery" action="/{{pages}}/{{page}}" method="post">
            {{!xCSRF}}
          </form>
          <div class="row navstrip">
            <div class="twelve columns">
              <button form="gallery" class="button" name="mode" type="submit"
                      value="grid">gallery
              </button>
            </div>
          </div>
      %   if not ERR:
            <p>the gallery has been updated</p>
      %   else:
            <p><font class="error">{{ERR}}</font></p>
      %   end
% #####################################################################################
      % elif QUERY.get('action', '') == 'update_library':
      %   check_editor()
      %   (img_id, nxt, prev, tot, idx) = get_slide(slides)
          <form id="cur" action="{{ME['uri']}}" method="post">
            {{!xCSRF}}
            <input name="img_id" type="hidden" value="{{img_id}}">
            <input name="mode" type="hidden" value="slides">
          </form>
          <form id="prev" action="{{ME['uri']}}" method="post">
            {{!xCSRF}}
            {{!show}}
            <input name="img_id" type="hidden" value="{{prev}}">
            <input name="mode" type="hidden" value="slides">
          </form>
          <form id="nxt" action="{{ME['uri']}}" method="post">
            {{!xCSRF}}
            {{!show}}
            <input name="img_id" type="hidden" value="{{nxt}}">
            <input name="mode" type="hidden" value="slides">
          </form>
          <div class="row navstrip">
            <div class="twelve columns">
              <div class="one columns">
                <button form="prev" class="NavButton">PRE</button>
              </div>
              <div class="one columns">
                <button form="cur" class="NavButton">CUR</button>
              </div>
              <div class="one columns">
                <button form="nxt" class="NavButton">NXT</button>
              </div>
            </div>
          </div>
      %   try:
      %     update_library(img_id, action="update")
      %     if QUERY.get('hide', '') == 'show':
              <p>the image is no longer hidden</p>
      %     else:
              <p>the image now requires <code>?{{PAGE['image']['unhide_tag']}}</code> in the URL to be displayed</p>
      %     end
      %   except Exception as e:
      %     logging.debug(f'{template}:{user}: unable to update image library [{e}]')
            <p><font class="error">unable to update image library</font></p>
      %   end
% #####################################################################################
      % elif QUERY.get('action', '') == 'ask_delete':
      %   check_editor()
      %   img_id = get_img_id()
          <form id="do_delete" action="{{ME['uri']}}" method="post">
            {{!xCSRF}}
            <input form="do_delete" name="img_id" type="hidden" value="{{img_id}}">
          </form>
          <div class="row navstrip">
            <div class="twelve columns">
              <button class="button" onclick="goBack()">go back</button>
            </div>
          </div>
          <div class="row">
            <div class="twelve columns">
              Are you sure you want to delete photo {{img_id}}
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
      %   check_editor()
      %   img_id = get_img_id()
      %   ERR = ''
      %   try:
      %     update_library(img_id, action="delete")
      %   except Exception as e:
      %     logging.debug(f'{template}:{user}: unable to update image library [{e}]')
      %     ERR = 'unable to update library'
      %   end
          <form id="gallery" action="{{ME['uri']}}" method="post">
            {{!xCSRF}}
            <input name="mode" type="hidden" value="grid">
          </form>
          <div class="row navstrip">
            <div class="twelve columns">
              <button form="gallery" class="button">gallery</button>
            </div>
          </div>
          <div class="row">
            <div class="twelve columns">
      %       if not ERR:
                {{img_id}} has been deleted
      %       else:
                <p><font class="error">{{ERR}}</font></p>
      %       end
            </div>
          </div>
% #####################################################################################
      % elif not QUERY.get('mode', '') or QUERY.get('mode', '') == 'grid':
      %   gal_acl = PAGE['acl']['gallery.koi']
      %   editors = ' '.join(PAGE['editors'])
      %   clock = datetime.datetime.fromtimestamp(gal_acl['time']).strftime(clock_format)
      %   acl = ACL.format(acl_users=' '.join(gal_acl['users']), \
      %                    acl_ips=' '.join(gal_acl['ips']), \
      %                    acl_time=clock, formID='update_gallery', item='gallery')
          <form id="update_gallery" action="{{ME['uri']}}" method="post">
            {{!xCSRF}}
            <input name="action" type="hidden" value="update_gallery">
          </form>
          <form id="upload" action="{{ME['uri']}}" enctype="multipart/form-data"
                method="post">
            {{!xCSRF}}
          </form>
          <div class="row columns navstrip">
            <div class="nine columns">
      %       if editor:
                <span class="u-pull-right">
                  <span title="save editors/title/keywords/ACL">
                    <button form="update_gallery" class="button-primary" name="action"
                            type="submit" value="update_gallery">save</button>
                  </span> &nbsp;
                  <span title="gallery title">
                    <input form="update_gallery" name="title" size="12" type="text"
                           value="{{PAGE['title']}}">
                  </span> &nbsp;
                  <span title="slug ({{CONFIG['slug_re']}})">
                    <input form="update_gallery" name="slug" size="9" type="text"
                           value="{{ME['page']}}">
                  </span> &nbsp;
                  <span title="space-separated list of keywords">
                    <input form="update_gallery" name="keywords" size="10" type="text"
                           placeholder="keywords" value="{{PAGE['keywords']}}">
                  </span>
                </span>
      %       else:
                <span class="u-pull-right">{{PAGE['title']}}</span>
      %       end
            </div>
            <div class="three columns">
              &nbsp;
            </div>
          </div>
      %   if not slides:
          <div class="row">
            <div class="twelve columns">
              <center>
              <p style="margin-top: 200px;">there are currently no images in the gallery</p>
              </center>
            </div>
          </div>
      %   end
          <div class="row">
            <div class="twelve columns">
              <div class="grid">
      %         # Looping over slides keeps thumbnails hidden too.
      %         for img_id in slides:
      %           tn_fp = make_tn(os.path.join(ME['path'], img_id))
      %           if editor and PAGE['library'][img_id]['hidden']:
      %             h = ' hidden'
      %           else:
      %             h = ''
      %           end
                  <div class="box">
                    <form action="{{ME['uri']}}" method="post">
                      {{!xCSRF}}
                      {{!show}}
                      <input name="mode" type="hidden" value="slides">
                      <input name="img_id" type="hidden" value="{{img_id}}">
                      <span title="{{img_id+h}}">
                        <button style="border: none;">
                          <img class="thumb{{h}}" src="{{ME['uri']}}/{{os.path.basename(tn_fp)}}">
                        </button>
                      </span>
                    </form>
                  </div>
      %         end
              </div>
            </div>
          </div>
      %   if editor:
            <div class="row subnav">
              <div class="twelve columns">
                <center>
                  <details>
                    <summary>gallery ACL</summary>
                    <p>
                      Gallery curators (space-separated list of user names):
                      <span title="who can edit this gallery?">
                        <input required form="update_gallery" name="editors" size="14" type="text"
                               value="{{editors}}">
                      </span>
                    </p>
                    {{!acl}}
                  </details>
                </center>
              </div>
            </div>
            <div style="margin-top: 20px;" class="row">
              <div class="twelve columns">
                <center>
                  <input form="upload" accept="{{', '.join(PAGE['image']['formats'])}}" name="file_upload"
                         type="file" multiple>
                  <input form="upload" class="button-primary" name="action" type="submit"
                         value="upload">
                </center>
              </div>
            </div>
      %   end
% #####################################################################################
      % elif QUERY.get('mode', '') == 'slides':
      %   logging.debug(f'{template}:{user}: displaying slides')
      %   (img_id, nxt, prev, tot, idx) = get_slide(slides)
      %   if PAGE['acl'].get(img_id, {}):
      %     img_acl = PAGE['acl'][img_id]
      %   else:
      %     img_acl = PAGE['acl']['gallery.koi']
      %   end
      %   clock = datetime.datetime.fromtimestamp(img_acl['time']).strftime(clock_format)
      %   img_fp = os.path.join(ME['path'], img_id)
      %   exif = get_exif(img_fp)
      %   exif['name'] = img_id
      %   tn_fp = make_tn(img_fp)
      %   hst_fp = make_hst(img_fp)
      %   if editor and PAGE['library'][img_id]['hidden']:
      %     h_class = ' hidden'
      %     toggle = 'show'
      %     pwd = f" (requires ?{PAGE['image']['unhide_tag']})"
      %   else:
      %     h_class = ''
      %     toggle = 'hide'
      %     pwd = f" (will need ?{PAGE['image']['unhide_tag']})"
      %   end
          <form id="update_library" method="post" action="{{ME['uri']}}">
            {{!xCSRF}}
            <input name="img_id" type="hidden" value="{{img_id}}">
            <input name="hide" type="hidden" value="{{toggle}}">
          </form>
          <form id="ask_delete" method="post" action="{{ME['uri']}}">
            {{!xCSRF}}
            <input name="img_id" type="hidden" value="{{img_id}}">
          </form>
          <form id="prev" action="{{ME['uri']}}" method="post">
            {{!xCSRF}}
            {{!show}}
            <input name="img_id" type="hidden" value="{{prev}}">
            <input name="mode" type="hidden" value="slides">
          </form>
          <form id="nxt" action="{{ME['uri']}}" method="post">
            {{!xCSRF}}
            {{!show}}
            <input name="img_id" type="hidden" value="{{nxt}}">
            <input name="mode" type="hidden" value="slides">
          </form>
          <form id="mode" action="{{ME['uri']}}" method="post">
            {{!xCSRF}}
            {{!show}}
            <input name="mode" type="hidden" value="grid">
          </form>
          <div class="row">
            <div class="one columns">
              <button form="prev" class="NavButton">PRE</button>
            </div>
            <div class="one columns">
              <button form="mode" class="NavButton">GRD</button>
            </div>
            <div class="one columns">
              <button form="nxt" class="NavButton">NXT</button>
            </div>
            <div class="nine columns">
              <div class="caption">
                {{PAGE['library'].get(img_id, {}).get('caption', '')}}
              </div>
            </div>
          </div>
          <div class="row">
            <div class="twelve columns">
              <center>
                <span title="{{PAGE['library'].get(img_id, {}).get('comment', '')}}">
                  <button style="border: none;" form="nxt">
                    <img class="photo{{h_class}}" src="{{ME['uri']}}/{{img_id}}">
                  </button>
                </span>
              </center>
            </div>
          </div>
      %   if editor:
            <div style="margin: 20px 0;" class="row">
              <div class="twelve columns">
                <center>
                  <span title="{{toggle}} this photo{{pwd}}">
                    <button form="update_library" class="button-primary" name="action"
                            type="submit" value="update_library">{{toggle}}</button>
                  </span>&nbsp;
                  <span title="delete this photo">
                    <button form="ask_delete" class="button xButton" name="action"
                            type="submit" value="ask_delete">&#9747;</button>
                  </span>
                </center>
              </div>
            </div>
      %   end
          <div class="row">
            <div class="twelve columns">
              <center>
                <details>
                  <summary>
                      Details
                  </summary>
                  <div class="row">
                    <div class="six columns">
                      gallery: {{PAGE['title']}} ({{idx}}/{{tot}})<br>
      %               for i in ['name', 'date taken', 'geometry', 'size', 'camera model', 'flash', 'white balance', 'metering mode', 'exposure']:
      %                 if i not in exif:
      %                   continue
      %                 end
                        {{i}}: {{exif[i]}}<br>
      %               end
                    </div>
                    <div class="six columns">
      %               for i in ['focal length (mm)', 'exposure time', 'aperture', 'ISO']:
      %                 if i not in exif:
      %                   continue
      %                 end
                        {{i}}: {{exif[i]}}<br>
      %               end
      %               if hst_fp:
                        <img style="margin-top: 10px;" src="{{ME['uri']}}/{{os.path.basename(hst_fp)}}">
      %               end
                    </div>
                  </div>
                </details>
              </center>
            </div>
          </div>
% #####################################################################################
      % else:
      %   logging.debug(f'{template}:{user}: unknown request')
          <p><font class="error">could not process request</font></p>
      % end
% #####################################################################################
    </div>
  </body>
</html>
