% import logging
% import markdown
% template = ME['template']+'.tpl'
% if user := PROFILE.get('user', ''):
%   xCSRF = f'<input name="xCSRF" type="hidden" value="{PROFILE["xCSRF"]}">'
% else:
%   xCSRF = ''
% end
% logging.info(f'{template}:{user}: processing template')
% content = PAGE['body'].replace('{{!xCSRF}}', xCSRF)
% if PAGE['markdown']:
%   content = markdown.markdown(content)
% end
<!DOCTYPE html>
<html lang="en">
  <head>
    % include('head.tpl')
    <title>{{CONFIG['site_name']}}</title>
  </head>
  <body>
    <div class="container">
      <div class="row">
        <div class="twelve columns">
          % include('header.tpl', show_search=True, show_login=True, hr=True)
        </div>
      </div>
      <div class="row">
        <div class="twelve columns">
        % if PAGE['markdown']:
            <h1 class="title">{{!markdown.markdown(PAGE['title'])}}</h1>
        % else:
            <h1 class="title">{{!PAGE['title']}}</h1>
        % end
        </div>
      </div>
      <div class="row">
        <div class="twelve columns">
          {{!content}}
        </div>
      </div>
      <div class="row">
        <div class="twelve columns">
          % include('footer.tpl')
        </div>
      </div>
    </div>
  </body>
</html>
