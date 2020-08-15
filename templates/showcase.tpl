% import logging
% user = PROFILE.get('user','')
% template = ME['template']+'.tpl'
% logging.info(f'{template}:{user}: processing template')
% if user:
%   xCSRF = f'<input name="xCSRF" type="hidden" value="{PROFILE["xCSRF"]}">'
% else:
%   xCSRF = ''
% end
%
% import random
% import json
% import os
%
% pages = CONFIG['dir_pages']
% assets = CONFIG['page_assets']
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
%   logging.debug(f'{template}:{user}: executing "get_slide(<slides>)"')
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
%
% #####################################################################################
%
% def update_library(img_id, action):
%   """
    update_library(img_id[str], action[str])

    Update the image library/ACL in "showcase.koi". "action" can be "add" or "delete"
    Images can only be added/deleted via the back-end.

"""
%   logging.debug(f'{template}:{user}: executing "update_library({img_id}, {action})"')
%   koi_file_fp = os.path.join(ME['path'], 'showcase.koi')
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
%     del koi_data['library'][img_id]
%     with open(koi_file_fp, "w", encoding='utf-8') as fd:
%       json.dump(koi_data, fd, ensure_ascii=False)
%     end
%     os.chmod(koi_file_fp, 0o600)
%     return
%   end
%   koi_data['library'][img_id] = {'watermark': '', 'tags': [], 'caption': '', \
%                                  'comments': {}, 'marked': '', 'data': {}, \
%                                  'hidden': True, 'talent': {}, 'www': '', 'keywords': '', \
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
% def get_photos():
%   """
    get_photos() -> (slides[list], show[str])

    Return a list of images (photo file names) and a "show" hidden-input string to
    display hidden images (empty if proper tag is not in QUERY).

"""
%   logging.debug(f'{template}:{user}: executing "get_photos()"')
%   images = [i for i in PAGE['library']]
%   if PAGE['image']['unhide_tag'] in QUERY:
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
%   (slides, show) = get_photos()
% end
% logging.info(f'{template}:{user}: processing DOCTYPE')
<!DOCTYPE html>
  <head>
    {{!refresh}}
    % include('head.tpl')
    <link rel="stylesheet" href="/{{pages}}/{{assets}}/showcase.css">
    <title>{{PAGE['title']}}</title>
  </head>
  <body>
% #####################################################################################
      % if ERR:
          <p><font class="error">{{ERR}}</font></p>
% #####################################################################################
      % elif refresh:
      %   pass
% #####################################################################################
      % elif not slides:
          <p style="margin: 50px;">nothing to see here<p>
% #####################################################################################
      % else:
      %   logging.debug(f'{template}:{user}: displaying slides')
      %   (img_id, nxt, prev, tot, idx) = get_slide(slides)
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
              <button form="prev" id="prevbtn">PRE</button>
              <button form="nxt" id="nxtbtn">NXT</button>
              <center>
                <span title="{{img_id}}">
                  <button style="border: none;" form="nxt">
                    <img class="photo" src="{{ME['uri']}}/{{img_id}}">
                  </button>
                </span>
                <div class="watermark">
                  {{PAGE['library'][img_id]['watermark']}}
                </div>
              </center>
      % end
  </body>
</html>
