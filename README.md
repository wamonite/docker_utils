# `docker_utils`

`docker_utils.sh` is a script to simplify common `docker` tasks. The tasks are set up as symlinks to `docker_utils.sh` where the name of symlink determines the task.

## Config

The tasks are configured via a local bash script `config.sh` by setting values for named variables. All `*_args` variables must be arrays rather than strings for correct parsing of whitespace.

    #!/bin/bash

    container_name=my_container
    build_args=( \
      --no-cache \
      --label maintainer="Warren Moore <warren.moore@spatialbuzz.com>" \
    )

## Tasks

### `build_image.sh`
* `docker build --rm` for the configured image
* Image name is set by the config variable `container_name`
* If the environment variable `DOCKER_REPO` is defined, the image name is set to `<DOCKER_REPO>/<container_name>`
* Extra arguments to the build command can be supplied with the config array `build_args` e.g. `builds_args=(--no-cache)`
* If command line arguments are supplied, they are added as build options and`build_args` are ignored e.g. `./build_image.sh --no-cache`

### `start_container.sh`
* `docker run` the configured image
* Image and container name is set by the config variable `container_name`
* By default, will run with `--rm` as a foreground container with the config variable `command_args` appended to the run command
* If the config variable `docker_args` is defined and non-zero, it is inserted after the run but before the image and command arguments e.g. `docker_args=(-v data:/data -p 80:80)`
* If command line arguments are supplied, will run with `-ti` as a foreground container and arguments are appended to the run command (config variable `command_args` is ignored)
* If the config variable `container_daemon` is defined and non-zero is, will run with `-d --restart unless-stopped` with the config variable `daemon_args` appended to the run command
    * If command line arguments are supplied, these override `daemon_args`
* If the config variable `container_network` is defined, it is added to the run options as `--net <container_network>` e.g. `container_network=host`
* If the config variable `container_hostname` is defined, it is added to the run options as `--hostname <container_hostname>` otherwise `--hostname <container_name>` is used (with `_` replaced with `-`)

### `stop_container.sh`
* For a daemonised container, will run `docker stop`, `docker logs --tail 100` then `docker rm -v` for the running container
* If config variable `docker_stop_timeout` is set, it is added to the stop options as `--time <docker_stop_timeout>`

### `tail_logs.sh`
* `docker logs --tail 100 -f <container_name>` for the running container

### `exec_bash.sh`
* `docker exec -ti <container_name> bash` for the running container

### `push_image.sh` and `list_remote_tags.sh`
* See **Pushing images**

### `initialise_*.sh` and `backup_*.sh`
* See **Volume commands**

## Link types

If a single Dockerfile can build and run multiple images/containers you can use link types. A link type is specified by adding `_<link name>` to the task symlink e.g. `build_image_v1.sh` has the link name `v1`.

When a task is invoked as a link type, any config variables with the suffix `_<link name>` will override the standard config variable e.g. `build_image_v1.sh` would use `container_name_v1=my_container_v1` over `container_name=my_container`.

This applies to all tasks except `initialise_*.sh` and `backup_*.sh`.

## Pushing images

* `push_image.sh` without command line arguments will show all local images of the current image name
* `push_image.sh` with a command line argument will push the latest build of the current image tagged with the argument provided
* If the `push_image.sh` command line argument is not `latest` the argument will be used as the image tag
    * the local image will be tagged with the argument prior to pushing
    * the local git repository will be tagged with the version. NOTE: make sure you have committed all local changes before pushing a versioned image as the script does not check if your git repository has any local changes or nor does it check if the latest image has been rebuilt since any changes have been made locally or remotely (need a CI setup to do this)
    * you will be asked if you wish to push the tag to the remote git repository, which is recommended
* If you wish to review what tags have been pushed to our ECR repository for the configured image, run `list_remote_tags.sh`
    * This executes and parses `aws ecr describe-images --repository-name <*/container_name>` so you will need AWS credentials available to run this task e.g. `envu ./list_remote_tags.sh`

## Volume commands

`initialise_<volume_id>.sh` and `backup_<volume_id>.sh` are tasks for initialising and backing up named volumes. Like link types, the volumes are referenced by adding the volume id to the symlink. As these commands use the same mechanism as link types, link types cannot be used with these tasks.

The task link volume id is used to dereference the named volume name and mount path within the container.

* `volume_name_<volume_id>` is used to determine the named volume name `<container_name>_<volume_name>`
* `volume_dest_<volume_id>` is used to determine the mount path within the container

### Initialise

* `initialise_<volume_id>.sh <source path>` will run `docker create --rm` with the named volume `<container_name>_<volume_name>` mounted on `<volume_dest>`
* The source path is then copied into the container to the location specified by `<volume_dest>`(via `tar -cf - -C <source path> .` piped to `docker cp`)
* Once to copy completes, the created container is removed with `docker rm -v` leaving the seeded named volume

### Backup

* `backup_<volume_id>.sh` will create the local backup file `backup_<container_name>_<volume_name>.tgz` of the destination path (via `docker cp` piped to `gzip` to file)

## Debug

To trace execution of the task script, the first line `docker_utils.sh` needs to be set to `#!/bin/bash -eux`. As `config.sh` is sourced by `docker_utils.sh`, changing that will make no difference.

## Contact

          @wamonite     - twitter
           \_______.com - web
    warren____________/ - email

