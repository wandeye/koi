% import logging
% logging.info(f'header.tpl: processing template')
%
% pages = CONFIG['dir_pages']
% edit = CONFIG['page_edit']
% search = CONFIG['page_search']
% search_var = CONFIG['search_var']
% login = CONFIG['page_login']
% max_len = CONFIG['search_max_query_len']
% search_var = CONFIG['search_var']
% if user := PROFILE.get('user', ''):
%   xCSRF = f'<input name="xCSRF" type="hidden" value="{PROFILE["xCSRF"]}">'
% else:
%   xCSRF = ''
% end
% if hr:
%   hr='<hr>'
% else:
%   hr=''
% end
       <hr>
       <div class="row">
         <div class="two columns">
           <h2><a class="koi" href="/">{{CONFIG['site_name']}}</a></h2>
         </div>
         <div class="two columns">
           % if user and user.lower() in PAGE.get('editors', ''):
           %   if ME['template'] == "article":
                 <form action="/{{pages}}/{{edit}}" method="post">
                   {{!xCSRF}}
                   <input name="action" type="hidden" value="edit">
                   <button class="button u-pull-right" name="page"
                           type="submit" value="{{ME['page']}}">
                     edit
                   </button>
                 </form>
           %   elif ME['template'] == "gallery":
                 <a class="button" href="/{{pages}}/{{edit}}#galleries"
                    style="margin-left: 32px">
                   galleries
                 </a>
           %   end
           % elif user and ME['template'] not in ["edit", "login"] \
           %           and any(i.lower() == user.lower() for i in CONFIG['site_editors']):
               <form action="/{{pages}}/{{edit}}" method="post">
                 {{!xCSRF}}
                 <a class="button" href="/{{pages}}/{{edit}}"
                    style="margin-left: 32px">
                   editor
                 </a>
               </form>
           % else:
               &nbsp;
           % end
         </div>
         <div class="six columns">
           % if show_search:
               <form action="/{{pages}}/{{search}}" method="post">
                 {{!xCSRF}}
                 <button class="u-pull-right button" type="submit">search</button>
                 <span title="{{CONFIG['search_box_popup']}}">
                   <input class="searchbox" maxlength="{{max_len}}"
                          name="{{search_var}}" size="12" type="text">
                 </span>
               </form>
           % else:
               &nbsp;
           % end
         </div>
         <div class="two columns">
           % if user:
               <form action="/{{pages}}/{{login}}" method="post">
                 {{!xCSRF}}
                 <span title="good-bye {{PROFILE['user']}}!">
                   <button class="u-pull-right button" name="action"
                           type="submit" value="logout">logout</button>
                 </span>
               </form>
           % elif show_login:
               <a class="button" href="/{{pages}}/{{login}}">login</a>
           % else:
               &nbsp;
           % end
         </div>
       </div>
       {{!hr}}
