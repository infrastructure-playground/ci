# READ BEFORE CLONING #
This repository is for instant set-up of our Dockerized project's dev environment

## Make sure you have your app passwords for your 2FA
* From your avatar in the bottom left, click Bitbucket settings.
* Click App passwords under Access management.
* Click Create app password.
* Input your name for the label
* Select the specific access and permissions you want this application password to have.
* Copy the generated password and either record or paste it into the application you want to give access.

## Make sure that you have at least Docker 17.05 version on your MAC
* Simply click the Docker icon on the upper left screen and choose Check for Updates...

## Install the submodules
`$ cd ci-{project}`

`$ git submodule init`

`$ git submodule update --init --remote`

## Login to Docker
`$ docker login`

## Start the project
`$ docker-compose pull`

`$ docker-compose up -d`

## Real-time file change between local files and container
Apply bind mount via volumes in docker-compose.yml like:
```
volumes:
    - ./{submodule}:/usr/src/app/
```

## Build the images locally
`$ docker-compose build`

## Update the images from cloud registry
`$ docker-compose pull && docker-compose up -d --no-build`


## Update a specific image
`$ docker-compose pull <container_alias>` like `docker-compose pull {submodule}`

`$ docker-compose up -d`

## To ssh inside a container
`$ docker exec -it <container_id> bash`

`$ docker exec -it <container_id> ash`(for alpine tagged images)

You can also use compose like `$ docker-compose exec <container_alias> bash`

## To test a Docker's default container execution like `CMD` or `ENTRYPOINT`
* Go to ci-{project} folder
`$ docker-compose restart <container_alias>` like `docker-compose restart {submodule}`

`$ docker-compose logs --tail=100 -f <container_alias>` like `docker-compose logs --tail=100 -f {submodule}`

### Adding new projects in the ci
```
$ git checkout -b upgrade/implement-<project_name>
$ git submodule add <repository_url>
```
* Go to `.gitmodules` file and add `branch = master` like


### Adding a new project in your current project bundle
```
$ git pull origin master
$ git submodule update --init --remote
$ docker-compose up -d --no-recreate
```

### Notes for updating our static front-end projects
```
$ docker-compose pull <frontend_image>
$ docker rm -f <frontend_container_alias>
$ docker-compose up -d --no-recreate
``

### Fixes
`$ git checkout -b fix/bug-fix-name`
