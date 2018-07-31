#!/bin/bash  #general
docker login || exit 1  #general
docker-compose pull  #dev
docker-compose up -d  #dev
docker-compose exec django python manage.py shell -c "from django.contrib.auth.models import User; User.objects.create_superuser('admin', '', 'pass1234')"  #dev
docker-compose exec angularjs ng build --prod --build-optimizer  #dev
docker-compose restart nginx  #dev
