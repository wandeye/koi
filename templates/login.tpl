% import logging
% template = ME['template']+'.tpl'
% logging.info(f'{template}: processing template')
%
% import datetime
% pages = CONFIG['dir_pages']
% edit = CONFIG['page_edit']
% logging.info(f'{template}: processing DOCTYPE')
<!DOCTYPE html>
<html lang="en">
  <head>
    % include('head.tpl')
    <title>{{PAGE['title']}}</title>
  </head>
  <body>
    <div class="container">
    % if ERR:
    %   include('header.tpl', show_search=False, show_login=True, hr=True)
        <p><font class="error">{{ERR}}</font></p>
    % elif QUERY.get('action', '') == 'logout':
    %   include('header.tpl', show_search=False, show_login=True, hr=True)
        <p>You have successfully logged out.</p>
    % elif not PROFILE:
    %   include('header.tpl', show_search=False, show_login=False, hr=True)
        <form action="{{ME['uri']}}" method="post">
          <div class="row">
            <div class="twelve columns">
              <label>username</label>
              <input required name="user" type="text">
            </div>
          </div>
          <div class="row">
            <div class="twelve columns">
              <label>password</label>
              <input required name="password" type="password">
            </div>
          </div>
          <div class="row">
            <div class="twelve columns">
              <button class="button-primary" name="action" type="submit" value="login">login</button>
            </div>
          </div>
        </form>
    % elif PROFILE:
    %   include('header.tpl', show_search=True, show_login=False, hr=True)
    %   if PROFILE['nonce']:
          <form action="{{ME['uri']}}" method="post">
            <input name="action" type="hidden" value="chknonce">
            <label>email verification code</label>
            <input required name="nonce" type="text">
            <br><button class="button-primary" type="submit">submit</button>
          </form>
    %   else:
    %     name = PROFILE['name']
    %     if not name:
    %       name = PROFILE['user']
    %     end
    %     if any(i.lower() == PROFILE['user'].lower() for i in CONFIG['site_editors']):
            <div class="row navstrip">
              <div class="twelve columns">
                <a class="button" href="/{{pages}}/{{edit}}">editor</a>
              </div>
            </div>
    %     end
          <div class="row">
            <div class="twelve columns">
              Welcome <k>{{name}}</k>!
            </div>
          </div>
    %   end
    % else:
    %   include('header.tpl', show_search=False, show_login=True, hr=False)
        <p><font class="error">unexpected request</font></p>
    % end
    </div>
  </body>
</html>
