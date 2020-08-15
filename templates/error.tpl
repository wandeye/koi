% import logging
% logging.info(f'error.tpl: processing template')
%
% pages = CONFIG['dir_pages']
% login = CONFIG['page_login']
% assets = CONFIG['page_assets']
<!DOCTYPE html>
  <head>
    <script>
      function goBack() {window.history.back();}
    </script>
    % include('head.tpl')
    <title>[{{CODE}}] error</title>
  </head>
  <body>
    <div class="container">
      <hr>
      <h2><a class="koi" href="/">{{!CONFIG['site_name']}}</a></h2>
      <hr>
      %# if CODE == 400:
      %#    <p class="error">[{{CODE}}] Bad Request</p>
      %# elif CODE == 403:
      %#    <p class="error">[{{CODE}}] Forbidden</p>
      %# elif CODE == 404:
      %#    <p class="error">[{{CODE}}] Not Found</p>
      %# elif CODE == 413:
      %#    <p class="error">[{{CODE}}] Payload Too Large</p>
      %# elif CODE == 500:
      %#    <p class="error">[{{CODE}}] Internal Server Error.</p>
      %# end
      % if CODE in [400, 403, 404, 413, 500]:
 	  <p><font class="error">[{{CODE}}] {{DETAILS}}</font></p>
      % end
      % if DETAILS == 'invalid token':
        <form action="/{{pages}}/{{login}}" method="post">
          <button type="submit">login</button>
        </form>
      % else:
        <button class="button" onclick="goBack()">Go Back</button>
      % end
    </div>
  </body>
</html>
