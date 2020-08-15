% import logging
% logging.info(f'footer.tpl: processing template')
%
% pages = CONFIG['dir_pages']
% assets = CONFIG['page_assets']
<div class="row">
  <div class="five columns">
    <hr>
  </div>
  <div class="two columns">
    <img title="鯉コンテンツマネージメントシステム"
         class="footer" src="/{{pages}}/{{assets}}/koi_footer.png">
  </div>
  <div class="five columns">
    <hr>
  </div>
</div>
