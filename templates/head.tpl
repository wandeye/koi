% import logging
% logging.debug(f'head.tpl: processing template')
%
% pages = CONFIG['dir_pages']
% assets = CONFIG['page_assets']
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="stylesheet" href="/{{pages}}/{{assets}}/normalize.css">
    <link rel="stylesheet" href="/{{pages}}/{{assets}}/skeleton.css">
    <link rel="stylesheet" href="/{{pages}}/{{assets}}/koi.css">
    <link rel="icon" type="image/png" href="/{{pages}}/{{assets}}/koi.png">
