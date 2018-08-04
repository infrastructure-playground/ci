#!/bin/bash  #general
docker login || exit 1  #general

default_backend_repository=django
default_frontend_repository=angularjs

read -p "Backend repository name [$default_backend_repository]: " backend_repository
read -p "Frontend repository name [$default_frontend_repository]: " frontend_repository

backend=${backend_repository:-$default_backend_repository}
frontend=${frontend_repository:-$default_frontend_repository}

git submodule init
git submodule update --init --remote

sed -i "" "s/ng serve --aot --host=0.0.0.0/ping google.com/" $frontend/entrypoint.sh

docker-compose pull  #dev
docker-compose up -d  #dev
docker-compose exec angularjs npm install  #dev

sed -i "" "s/ping google.com/ng serve --aot --host=0.0.0.0/" $frontend/entrypoint.sh

docker-compose restart $frontend
docker-compose exec $backend python manage.py shell -c "from django.contrib.auth.models import User; User.objects.create_superuser('admin', '', 'pass1234')"  #dev

docker-compose restart nginx  #dev
