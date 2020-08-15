% import logging
% user = PROFILE.get('user','')
% template = ME['template']+'.tpl'
% logging.info(f'{template}:{user}: processing template')
% max_len = CONFIG['search_max_query_len']
% search_var = CONFIG['search_var']
% search_scope = ['title', 'keywords', 'body', 'author', 'creator']
%
% ##########################################################################
%
% def do_search(search_query):
%   """
    do_search(search_query[str]) -> matches[dict]

    Search the site INDEX for matches on "search_query"
    (a string of space-separated words).
"""
%   logging.debug(f'{template}:{user}: executing "do_search({search_query})"')
%   import re
%   import copy
%   punctuation = re.compile(r'[\W_]+')
%   search_query = punctuation.sub(' ', search_query)
%   search_words = set([i.lower() for i in search_query.split()])
%   matches = copy.deepcopy(INDEX)
%   logging.info(f'{template}:{user}: searching the INDEX')
%   for page, entries in INDEX.items():
%     # Note that other ACL restrictions may still apply on matches
%     # e.g. "ips"
%     if entries.get('acl', ''):
%       koi_file = TREE[page]['template']+'.koi'
%       if 'acl' in INDEX[page]:
%         users_acl = entries['acl'][koi_file]['users']
%         groups_acl = entries['acl'][koi_file]['groups']
%       else:
%       users_acl = '*'
%       end
%       if users_acl == '*':
%         pass
%       else:
%         if not PROFILE:
%           del matches[page]
%           continue
%         end
%         if set(PROFILE['groups']).intersection(set(groups_acl)):
%           users_acl = [PROFILE['user']]
%         end
%         if '*' not in users_acl:
%           if not PROFILE['user'] in users_acl:
%             del matches[page]
%             continue
%           end
%         end
%       end
%     end
%     match = False
%     for scope in search_scope:
%       # entries is INDEX[page]
%       if scope in entries and isinstance(entries[scope], str):
%         logging.debug(f'{template}:{user}: searching "{page}[\'{scope}\']"')
%         entry = punctuation.sub(' ', entries[scope])
%         entry_words = set([i.lower() for i in entry.split()])
%         if search_words.issubset(entry_words):
%           logging.debug(f'{template}:{user}: found match')
%           match = True
%           break
%         end
%       end
%     end
%     if not match:
%       del matches[page]
%     end
%   end
% return matches
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
      % if not search_var in QUERY:
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
      %         for page, entries in matches.items():
      %           uri = TREE[page]['uri']
      %           title = entries.get('title', '')
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
