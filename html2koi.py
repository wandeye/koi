#!/usr/bin/python3

if __name__ == '__main__':

    import time
    import json
    import os
    from koi import __version__

    print('\nHTML to koi file converter')
    print('==========================\n')
    html = input('HTML file: ')
    user = input('koi user name (article editor): ')
    user = user.lower()
    print('\nAll subsequent fields are optional, press <enter> to skip\n')
    title = input('Title: ')
    author = input('Author: ')
    keywords = input('Keywords: ')
    markdown = input('Use Markdown [y/N]? ')
    if markdown.lower() == 'y':
        markdown = True
    else:
        markdown = False
    print('\nNote that, if untrusted, the article editor will destroy most markup')
    trusted = input('Trusted (arbitrary HTML allowed) [Y/n]? ')
    if trusted.lower() == 'n':
        trusted = False
    else:
        trusted = True
    now = int(time.time())
    acl = {"article.koi": {"users": [user], "groups": [], "ips": "*",
                           "time": now}}
    with open(html, 'r') as fd:
        html = fd.read()
    koi_data = {"title": title, "keywords": keywords, "body": html, \
                "timestamp": now, "author": author, "koi_version": __version__, \
                "editors": [user], "editor_groups": [], "acl": acl, \
                "rev": "00000", "created": now, "trusted": trusted, \
                "markdown": markdown, 'notes': [], 'last_edit_by': user}
    with open("article.koi", 'w', encoding='utf-8') as fd:
        json.dump(koi_data, fd, ensure_ascii=False)
    os.chmod("article.koi", 0o600)
    print(f'\nCreated article.koi, you can now move it into the appropriate web page directory')
    print('Remember to run "acledit.py" to set the proper ACL control if nedeed\n')
