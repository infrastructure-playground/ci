#!/bin/bash  #general

docker login || exit 1  #general

# value of variable below gets the second root folder and removes non-alphanumeric characters
default_docker_organization=$(awk -F'/' 'NF>2{print $(NF-1)}' <<<"$PWD" | sed 's/[^a-zA-Z0-9]//g')
default_backend_repository=django  #general
default_frontend_repository=angularjs  #general

read -p "Docker organization [$default_docker_organization]: " docker_organization
read -p "Backend repository name [$default_backend_repository]: " backend_repository  #general
read -p "Frontend repository name [$default_frontend_repository]: " frontend_repository  #general

organization=${docker_organization:-$default_docker_organization}
backend=${backend_repository:-$default_backend_repository}
frontend=${frontend_repository:-$default_frontend_repository}

docker pull python:3
docker pull node:latest
docker pull postgres:latest
docker pull nginx:latest
docker-compose -f docker-compose-start.yml build
docker-compose -f docker-compose-start.yml up -d

# # Django starter script
docker-compose -f docker-compose-start.yml exec $backend rm -rf .dockerignore .gitignore entrypoint.sh gunicorn_conf.py manage.py project Dockerfile static project/development_settings.py project/production_settings.py project/test_settings.py
docker-compose -f docker-compose-start.yml exec $backend django-admin.py startproject project .
docker-compose -f docker-compose-start.yml exec $backend pip freeze > django/requirements.txt

python_version=$(docker-compose -f docker-compose-start.yml exec $backend python -V | sed 's/[^0-9.]//g')

cat >> $backend/gunicorn_conf.py <<EOF
bind = '0.0.0.0:8000'
loglevel = 'debug'
errorlog = '-'
accesslog = '-'
# the formula is based on the assumption that for a given core, one worker
# will be reading or writing from the socket while the other worker is
# processing a request.
workers = 2
preload = True
reload = True
worker_class = 'gevent'  # async type worker, so the app can handle a stream of requests in parallel
EOF
cat >> $backend/entrypoint.sh <<EOF
#!/bin/bash
# run makemigrate until database is already available, useful on first time setup
# as makemigrate comes first before creating the default 'db, password and user'
until python manage.py makemigrations && python manage.py migrate
do
  echo "Try again"
done &

gunicorn -c gunicorn_conf.py project.wsgi:application
EOF
chmod u+x $backend/entrypoint.sh
cat >> $backend/Dockerfile <<EOF
FROM $organization/$backend:latest as project

# using multi-staging with multiple copies to continuously keep the environment and avoid the maximum image layer error
FROM python:$python_version
WORKDIR /usr/src/app
EXPOSE 8000

# Install vim, enable compilemessages and m2crypto
RUN apt-get update && \
    apt-get install vim -y

# To copy existing python packages commands
COPY --from=project /usr/local/bin/. /usr/local/bin/.

# To copy existing python packages
COPY --from=project /usr/local/lib/python3.6/site-packages/. /usr/local/lib/python3.6/site-packages/.

# COPY locale locale
# RUN python manage.py compilemessages
COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt

# To copy existing migration files
COPY --from=project /usr/src/app/. .

COPY . .
RUN timeout 30 yes | python manage.py makemigrations

ENTRYPOINT ["/usr/src/app/entrypoint.sh"]
EOF
cat >> $backend/project/development_settings.py <<EOF
import os

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = os.environ.get('SECRET_KEY', 'secret_key')

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = True

CDN_HOSTNAME = os.environ.get('CDN_HOSTNAME')
if CDN_HOSTNAME:
    # put "CDN Credentials" here if any
    pass

# Database
# https://docs.djangoproject.com/en/1.11/ref/settings/#databases
if os.environ.get('DOCKERIZED'):  # To avoid error in makemigrations during build
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql_psycopg2',
            'HOST': os.environ.get('POSTGRES_SERVICE'),
            'NAME': os.environ.get('POSTGRES_DB'),
            'PASSWORD': os.environ.get('POSTGRES_PASSWORD'),
            'PORT': os.environ.get('POSTGRES_PORT'),
            'USER': os.environ.get('POSTGRES_USER')
        }
    }

EOF
cat >> $backend/project/production_settings.py <<EOF
import os
from configparser import SafeConfigParser
from django.conf import settings

config_file = os.path.join(settings.BASE_DIR, 'settings', 'configs.cfg')
config_parser = SafeConfigParser()
config_parser.read(config_file)

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = config_parser.get('django', 'SECRET_KEY')

DEBUG = False

CDN_HOSTNAME = config_parser.get('file_storage', 'CDN_HOSTNAME')

# Database
# https://docs.djangoproject.com/en/1.11/ref/settings/#databases
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'HOST': config_parser.get('postgres', 'SERVICE'),
        'NAME': config_parser.get('postgres', 'DB'),
        'PASSWORD': config_parser.get('postgres', 'PASSWORD'),
        'PORT': config_parser.get('postgres', 'PORT'),
        'USER': config_parser.get('postgres', 'USER')
    }
}
EOF
cat >> $backend/project/test_settings.py <<EOF
SECRET_KEY = 'test'

# CACHES = {
#     'default': {
#         'BACKEND': 'redis_cache.RedisCache',
#         'LOCATION': 'redis://127.0.0.1:6379',
#         'OPTIONS': {
#             'DB': 1,
#         }
#     },
# }
# BROKER_URL = 'amqp://guest:guest@localhost:5672//'
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'NAME': 'postgres',
        'USER': 'postgres',
        'PASSWORD': 'postgres',
        'HOST': 'localhost',
        'PORT': '5432'
    }
}
EOF
cat >> $backend/project/settings.py <<EOF
STATIC_ROOT = 'static'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')
MEDIA_URL = '/media/'

if os.environ.get('ENV') == 'prod':
    from .production_settings import *
elif os.environ.get('ENV') == 'test':
    from .test_settings import *
else:
    from .development_settings import *
EOF
cat >> $backend/.dockerignore <<EOF
#migration files
*/migrations/*
!*/migrations/__init__.py

# Byte-compiled / optimized / DLL files
__pycache__/

# celery beat schedule file
celerybeat-schedule

celerybeat.pid
celeryd.pid

# git
.git

# Editor
*.DS_Store

# Byte-compiled / optimized / DLL files
__pycache__/
*.py[cod]
*$py.class
db.sqlite3

# media
media/*
EOF
cat >> $backend/.gitignore <<EOF
# Byte-compiled / optimized / DLL files
__pycache__/
*.py[cod]
*$py.class
# C extensions
*.so

# DB
*.db

# Editor
*.DS_Store

# Distribution / packaging
.Python
env/
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
#lib/
lib64/
parts/
sdist/
var/
*.egg-info/
.installed.cfg
*.egg

# PyInstaller
#  Usually these files are written by a python script from a template
#  before PyInstaller builds the exe, so as to inject date/other infos into it.
*.manifest
*.spec

# Installer logs
pip-log.txt
pip-delete-this-directory.txt

# Unit test / coverage reports
htmlcov/
.tox/
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*,cover
.hypothesis/

# Translations
*.mo
*.pot

# Django stuff:
*.log
local_settings.py

# Flask stuff:
instance/
.webassets-cache

# Scrapy stuff:
.scrapy

# Sphinx documentation
docs/_build/

# PyBuilder
target/

# IPython Notebook
.ipynb_checkpoints

# pyenv
.python-version

# celery beat schedule file
celerybeat-schedule

# dotenv
.env

# virtualenv
venv/
ENV/

# Spyder project settings
.spyderproject

# Rope project settings
.ropeproject

#migration files
*/migrations/*
!*/migrations/__init__.py

.idea/
db.sqlite3

# media
media/*
EOF

sed -i "" "s/DEBUG = True//" $backend/project/settings.py
sed -i "" "s/SECRET_KEY = '.*'//" $backend/project/settings.py
sed -i "" "s/ALLOWED_HOSTS = .*/ALLOWED_HOSTS = ['*']/" $backend/project/settings.py
sed -i "" "s/TIME_ZONE = 'UTC'/TIME_ZONE = 'Asia\/Singapore'/" $backend/project/settings.py

# AngularJS starter script
docker-compose -f docker-compose-start.yml exec $frontend rm -rf .dockerignore .gitignore project entrypoint.sh Dockerfile
docker-compose -f docker-compose-start.yml exec $frontend ng new project --directory .

node_version=$(docker-compose -f docker-compose-start.yml exec $frontend node -v | sed 's/[^0-9.]//g')
cat >> $frontend/entrypoint.sh <<EOF
#!/bin/bash
ng build --watch --prod --build-optimizer && chmod u+x dist &
ng serve --aot --host=0.0.0.0
EOF
cat >> $frontend/.dockerignore <<EOF
.DS_Store
EOF
cat >> $frontend/.gitignore <<EOF
.DS_Store
EOF
cat >> $frontend/Dockerfile <<EOF
FROM $organization/$frontend:latest as project

FROM node:$node_version
WORKDIR /usr/src/app
EXPOSE 4200
RUN apt-get update && \
    apt-get install vim -y && \
    npm install -g @angular/cli

# COPY --from=project /usr/src/app/node_modules node_modules
COPY package.json package.json
RUN npm install

COPY . .

ENTRYPOINT ["/usr/src/app/entrypoint.sh"]
EOF
cat >> $frontend/.dockerignore <<EOF
.DS_Store
node_modules/
dist/
npm-debug.log
EOF
cat >> $frontend/.gitignore <<EOF
.DS_Store
node_modules/
dist/
npm-debug.log
EOF
chmod u+x $frontend/entrypoint.sh

sed -i "" 's|"outputPath": "dist/project"|"outputPath": "dist"|' $frontend/angular.json

# Nginx starter script
rm -rf nginx/conf.d/default.conf nginx/Dockerfile .dockerignore .gitignore
# 'EOF' is to avoid using $ as variable indicator but will be used as string instead
cat >> nginx/conf.d/default.conf <<'EOF'
server {
    listen 8000;
    server_name         localhost;

    location / {
        proxy_pass      http://django:8000;
        proxy_set_header Host $host:$proxy_port;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /static {
        alias   /usr/src/app/django/static;
    }

    location /media {
        alias   /usr/src/app/django/media;
    }
}

server {
    listen 80;
    server_name         localhost;

    location / {
        root /usr/src/app/angularjs/dist;
    }
}
EOF
cat >> nginx/Dockerfile <<EOF
FROM nginx:latest

ENV TZ Asia/Singapore
COPY conf.d/. /etc/nginx/conf.d/
EOF
cat >> nginx/nginx.conf <<EOF

user  nginx;
worker_processes  auto;
worker_cpu_affinity auto;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    # client_body_in_file_only on;
    client_body_in_single_buffer on;

    log_format  main  '{"Client-IP":$remote_addr, "Remote-User":$remote_user, "Time":[$time_local], "Request-Method":$request_method, '
                      '"Host":$scheme://$host:$server_port, "Path":$request_uri "Status-Code":$status, "Body-Size":$body_bytes_sent, '
                      '"Connection-Requests":$connection_requests, "Proxy-Response-Time":$request_time "HTTP-Referrer":$http_referer, '
                      '"HTTP-User-Agent":$http_user_agent, "HTTP-X-Forwarded-For":$http_x_forwarded_for, '
                      '"Request-Body": $request_body, "Authorization-Header": $http_Authorization}';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    gzip  on;

    include /etc/nginx/conf.d/*.conf;
}
EOF

# Postgres starter script
cat >> postgres/Dockerfile <<EOF
FROM postgres:latest
ENV PG_MAX_WAL_SENDERS 8
ENV PG_WAL_KEEP_SEGMENTS 8
COPY setup-replication.sh /docker-entrypoint-initdb.d/
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint-initdb.d/setup-replication.sh /docker-entrypoint.sh
EOF

docker-compose build  #dev
docker-compose up -d  #dev

docker-compose exec $backend python manage.py collectstatic
docker-compose exec $backend python manage.py shell -c "from django.contrib.auth.models import User; User.objects.create_superuser('admin', '', 'pass1234')"  #dev

sed -i "" "s/# COPY [.]*/COPY $1/" $frontend/Dockerfile

nginx_version=$(docker-compose exec nginx nginx -v 2>&1 | sed 's/[^0-9.]//g')
pg_version=$(docker-compose exec postgres postgres --version | sed -E 's/.*PostgreSQL[^0-9.]+([0-9.]*).*/\1/')


sed -i "" "s/nginx:latest/nginx:$nginx_version/" nginx/Dockerfile
sed -i "" "s/postgres:latest/postgres:$pg_version/" postgres/Dockerfile
docker-compose restart nginx  #dev

docker-compose push