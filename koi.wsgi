import os, sys
sys.stdout = sys.stderr
sys.path = ['/www/wsgi/koi/'] + sys.path
import bottle
import koi
os.chdir(os.path.dirname(__file__))
application = bottle.default_app()
