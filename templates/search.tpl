% import logging
% user = PROFILE.get('user','')
% template = ME['template']+'.tpl'
% logging.info(f'{template}:{user}: processing template')
%
% import shutil
% import os
% no_whoosh = False
% try:
%   from whoosh import index
%   from whoosh.fields import Schema, TEXT, ID
%   from whoosh.analysis import FancyAnalyzer
%   from whoosh.qparser import MultifieldParser, FuzzyTermPlugin
% except:
%   logging.warning(f'{template}:{user}: could not import whoosh')
%   no_whoosh = True
%   ERR = 'you need to install whoosh'
% end
% max_len = CONFIG['search_max_query_len']
% search_var = CONFIG['search_var']
% index_fp = os.path.join(ME['path'], '.index')
% num_hits = 50
%
% ##########################################################################
%
% def make_index():
%   """
    make_index()

    Create an index from scratch into "index_fp".

"""
%   logging.debug(f'{template}:{user}: executing "make_index()"')
%
%   # So KEYWORD would seem to make sense below for "keywords"
%   # but then whoosh crashes searching phrases with:
%   #    Phrase search: 'keywords' field has no positions
%   # which googling a bit suggests a whoosh bug.
%   schema = Schema(body=TEXT(analyzer=FancyAnalyzer()), \
%                   title=TEXT(field_boost=2.0, \
%                              analyzer=FancyAnalyzer()), \
%                   author=TEXT(field_boost=2.0), \
%                   creator=TEXT(field_boost=2.0), \
%                   keywords=TEXT(field_boost=2.0), \
%                   page=ID(stored=True))
%
%   if os.path.exists(index_fp):
%     shutil.rmtree(index_fp)
%   end
%   os.mkdir(index_fp, mode=0o700)
%   logging.debug(f'{template}:{user}: creating search index.')
%   ix = index.create_in(index_fp, schema)
%   writer = ix.writer()
%   for page, data in INDEX.items():
%     body = data.get('body', '')
%     title = data.get('title', '')
%     author = data.get('author', '')
%     creator = data.get('creator', '')
%     keywords = data.get('keywords', '')
%     writer.add_document(body=body, title=title, author=author, \
%                         creator=creator, keywords=keywords, page=page)
%   end
%   writer.commit()
% end
%
% ##########################################################################
%
% def do_search(search_query):
%   """
    do_search(search_query[str]) -> matches[list]

    Search the site INDEX for matches on "search_query"
    (a string of space-separated words).
"""
%   logging.debug(f'{template}:{user}: executing "do_search({search_query})"')
%
%   ix = index.open_dir(index_fp)
%   fields = ['title', 'keywords', 'body', 'author', 'creator']
%   parser = MultifieldParser(fields, schema=ix.schema)
%   parser.add_plugin(FuzzyTermPlugin())
%   query = parser.parse(search_query)
%   logging.debug(f'{template}:{user}: searching...')
%   with ix.searcher() as searcher:
%     results = searcher.search(query, limit=num_hits)
%     hits = [i['page'] for i in results]
%   end
%   matches = []
%   logging.debug(f'{template}:{user}: filtering hits on ACL basis')
%   for page in hits:
%     # Note that other ACL restrictions may still apply on matches
%     # e.g. "ips"
%     koi_file = TREE[page]['template']+'.koi'
%     if 'acl' in INDEX[page]:
%       users_acl = INDEX[page]['acl'][koi_file]['users']
%       groups_acl = INDEX[page]['acl'][koi_file]['groups']
%     else:
%       users_acl = '*'
%     end
%     if users_acl == '*':
%       matches.append(page)
%     else:
%       if not PROFILE:
%         continue
%       end
%       if set(PROFILE['groups']).intersection(set(groups_acl)):
%         users_acl = [PROFILE['user']]
%       end
%       if '*' in users_acl or PROFILE['user'] in users_acl:
%         matches.append(page)
%       end
%     end
%   end
%   return matches
% end
%
% ##########################################################################
%
% logging.debug(f'{template}:{user}: processing DOCTYPE')
<!DOCTYPE html>
<html lang="en">
  <head>
    % include('head.tpl')
    <title>{{PAGE['title']}}</title>
  </head>
  <body>
    <div class="container">
      % include('header.tpl', show_search=True, show_login=True, hr=True)
% ##########################################################################
      % if no_whoosh:
          <div class="row">
            <div class="twelve columns">
              <font class="error">{{ERR}}</font>
            </div>
          </div>
% ##########################################################################
      % elif not search_var in QUERY:
          <p>No query found, try using the search field above</p>
% ##########################################################################
      % else:
      %   search_query = QUERY[search_var]
      %   logging.debug(f'{template}:{user}: parsing query "{search_query}"')
      %   if not search_query:
      %     logging.debug(f'{template}:{user}: empty search query, no matches returned')
            <p>No results on empty query</p>
      %   elif len(search_query) > max_len:
      %     msg = f'{template}:{user}: refusing search query exceeding {0} characters'
      %     logging.debug(msg.format(max_len))
            <p>Sorry, that search query is too long</p>
      %   else:
      %     if not os.path.isdir(index_fp):
      %       make_index()
      %     end
      %     update_idx = False
      %     idx_ts = os.stat(index_fp).st_mtime
      %     # Update the index if any pages were updated. Ignore if no timestamp.
      %     if any(INDEX[i].get('timestamp', 0) > idx_ts for i in INDEX):
      %       update_idx = True
      %     end
      %     # Update the index if any pages were deleted.
      %     if os.stat(os.path.dirname(ME['path'])).st_mtime > idx_ts:
      %       update_idx = True
      %     end
      %     if update_idx:
      %       make_index()
      %     end
      %     matches = do_search(search_query)
      %     if not matches:
              <p>No matches found for <em>{{search_query}}</em></p>
      %     else:
      %       hits = len(matches)
      %       if hits == 1:
      %         suf = ''
      %       else:
      %         suf='es'
      %       end
              <p>Found {{hits}} match{{suf}} for <em>{{search_query}}</em></p>
              <ol>
      %         for page in matches:
      %           uri = TREE[page]['uri']
      %           title = INDEX[page].get('title', '')
      %           if not title:
      %             title = f'uri > {uri}'
      %           end
                  <li><a class="button" href="{{uri}}">{{title}}</a></li>
      %         end
              </ol>
      %     end
      %   end
      % end
    </div>
  </body>
</html>
