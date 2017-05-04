#!/bin/bash -eu

# 2017-04-27 13:42

script_path=$(cd $(dirname $0); pwd -P)

. "${script_path}/config.sh"

# minimum requirements
[ -z "${container_name:-}" ] && { echo "container_name not set" 1>&2 ; exit 1 ; }
[ ! -d "${script_path}/src" ] && { echo "src directory not found" 1>&2 ; exit 1 ; }

# defaults
repo_name=${DOCKER_REPO:-}
image_name="${repo_name:+${repo_name}/}${container_name}"
docker_cmd=${DOCKER_CMD:-docker}
if [[ ! -z "${DOCKER_HOST:-}" && "${DOCKER_HOST}" =~ ^tcp://(.*):[0-9]*$ ]]
then
    container_hostname="${BASH_REMATCH[1]}"
fi

# for a symlink name <prefix>_<type>.sh echo <type> or nothing
function get_link_type() {
    script_prefix="${1:-}"
    [ -z "$script_prefix" ] && { echo "get_link_type script_prefix not set" 1>&2 ; exit 1 ; }

    if [[ "$script_name" =~ ${script_prefix}_(.*)\.sh$ ]]
    then
        echo "${BASH_REMATCH[1]}"
    fi
}

# vars may have changed, so echo the latest start arguments
function get_host_args() {
    echo "${container_network:+--net ${container_network}} --hostname ${container_hostname:-${container_name}} --name ${container_name}"
}

# choose what to do on symlink name
script_name=$(basename $0)
case "$script_name" in
build_image*)
    echo "#### BUILD ${image_name}"
    exec ${docker_cmd} build --rm -t "${image_name}" "${script_path}/src"
    ;;

start_container*)
    link_type=$(get_link_type "start_container")

    if [ ! -z "${link_type}" ]
    then
        container_name="${container_name}_${link_type}"

        docker_args_name="docker_args_${link_type}"
        docker_args="${!docker_args_name}"
    fi

    if [ $# -ne 0 ]
    then
        echo "#### START ${container_name} '$@'"
        exec ${docker_cmd} run --rm -ti ${docker_args:-} $(get_host_args) ${image_name} $@
    elif [ ! -z "${container_daemon:-}" ]
    then
        echo "#### START DAEMON ${container_name}"
        exec ${docker_cmd} run -d --restart unless-stopped ${docker_args:-} $(get_host_args) ${image_name}
    else
        echo "#### START ${container_name}"
        exec ${docker_cmd} run --rm ${docker_args:-} $(get_host_args) ${image_name}
    fi
    ;;

stop_container*)
    link_type=$(get_link_type "stop_container")

    if [ ! -z "${link_type}" ]
    then
        container_name="${container_name}_${link_type}"
    fi

    echo "#### STOP ${container_name}"
    set +e
    ${docker_cmd} stop "${container_name}"
    ${docker_cmd} logs --tail 100 "${container_name}"
    ${docker_cmd} rm -v "${container_name}"
    set -e
    ;;

tail_logs*)
    link_type=$(get_link_type "tail_logs")

    if [ ! -z "${link_type}" ]
    then
        container_name="${container_name}_${link_type}"
    fi

    echo "#### TAIL ${container_name}"
    exec ${docker_cmd} logs --tail 100 -f "${container_name}"
    ;;

push_image*)
    echo '#### PUSH'

    version="${1:-}"

    if [ -z "${version}" ]
    then
        exec ${docker_cmd} images | grep "^${image_name} "

    else
        if [ "${version}" != "latest" ]
        then
            ${docker_cmd} tag "${image_name}:latest" "${image_name}:${version}"
        fi

        ${docker_cmd} push "${image_name}:${version}"

        if [ "${version}" != "latest" ]
        then
            git tag -a "${version}" -m "${image_name}:${version}"
        fi
    fi
    ;;

initialise_*)
    [[ ! "${script_name}" =~ initialise_(.*)\.sh$ ]] && { echo 'unable to determine volume' 1>&2 ; exit 1 ; }
    volume_id="${BASH_REMATCH[1]}"

    volume_name_var="volume_name_${volume_id}"
    volume_dest_var="volume_dest_${volume_id}"
    volume_name="${!volume_name_var}"
    volume_dest="${!volume_dest_var}"
    volume_src="${1:-}"

    [ -z "${volume_src}" ] && { echo "src directory not provided" 1>&2 ; exit 1 ; }

    container_name="${container_name}_${volume_name}"
    echo "#### INITIALISE ${container_name} (${volume_src} -> ${volume_dest})"

    trap "${docker_cmd} rm -v ${container_name}" SIGINT SIGTERM EXIT

    ${docker_cmd} create --rm -v ${container_name}:${volume_dest} $(get_host_args) ${image_name}
    tar -cf - -C ${volume_src} . | ${docker_cmd} cp - ${container_name}:${volume_dest}
    ;;

backup*)
    [[ ! "${script_name}" =~ backup_(.*)\.sh$ ]] && { echo 'unable to determine volume' 1>&2 ; exit 1 ; }
    volume_id="${BASH_REMATCH[1]}"

    volume_name_var="volume_name_${volume_id}"
    volume_dest_var="volume_dest_${volume_id}"
    volume_name="${!volume_name_var}"
    volume_dest="${!volume_dest_var}"
    volume_backup="backup_${container_name}_${volume_name}.tgz"

    echo "#### BACKUP ${volume_id} (${volume_dest} -> ${volume_backup})"

    exec ${docker_cmd} cp ${container_name}:${volume_dest} - | gzip -c > "${volume_backup}"
    ;;

*)
    echo "#### CONFIG ${container_name}"
    echo "container_name: $container_name"
    echo "repo_name: $repo_name"
    ;;
esac
