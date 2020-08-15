#!/usr/bin/python3

if __name__ == '__main__':

    import time
    import json
    import os
    from koi import __version__

    print('\nkoi Gallery Generator')
    print('=====================\n')
    user = input('koi user name (gallery curator): ')
    user = user.lower()
    print('\nAll subsequent fields are optional, press <enter> to skip\n')
    title = input('Title: ')
    creator = input('Creator: ')
    keywords = input('Keywords: ')
    now = int(time.time())
    koi_data = {'title': title, 'keywords': keywords, 'notes': [], \
                'timestamp': now, 'creator': creator, 'koi_version': __version__, \
                'editors': [user], 'editor_groups': [], 'tags': []}
    koi_data['acl'] = {'gallery.koi': {'users': [user], 'groups': [], \
                                       'ips': '*', 'time': now}}
    koi_data['thumbnail'] = {'size': [260, 260], 'quality': 90, 'optimize': True, \
                             'type': 'JPEG', 'square': True, 'frame': True, \
                             'progressive': True}
    koi_data['histogram'] = {'height': 150, 'fg_col': [80, 80, 80], \
                             'bg_col': [180, 180, 180], 'lines_col': [220, 220, 220], \
                             'border_col': [60, 60, 60], 'show': True, 'n_lines': 5, \
                             'create': True}
    koi_data['image'] = {'formats': ['.jpg', '.jpeg', '.png'], 'unhide_tag': 'unhide', \
                         'hide_new': True}
    koi_data['library'] = {}
    koi_data['get_users'] = True
    koi_data['created'] = now
    with open("gallery.koi", 'w', encoding='utf-8') as fd:
        json.dump(koi_data, fd, ensure_ascii=False)
    os.chmod("gallery.koi", 0o600)
    print(f'\nCreated gallery.koi, you can now move it into the appropriate web page directory')
    print('Remember to run "acledit.py" to set the proper ACL control if nedeed\n')
