% import logging
% logging.info(f'files.tpl: processing template')
<!DOCTYPE html>
<html lang="en">
  <body>
    <div class="container">
      <div class="row">
        <div class="twelve columns">
          {{PAGE.get('body', '')}}
        </div>
      </div>
    </div>
  </body>
</html>
