#!/bin/bash -eu

script_path=$(cd "$(dirname "$0")"; pwd -P)

. "${script_path}/config.sh"

# check for src dir
[[ ! -d "${script_path}/src" ]] && { echo "src directory not found" 1>&2 ; exit 1 ; }

# docker_cmd
docker_cmd=${DOCKER_CMD:-docker}

# for a symlink name <prefix>_<type>.sh echo <type> or nothing
function get_link_type() {
    local script_prefix="${1:-}"
    local script_test="${2:-}"
    [[ -z "$script_prefix" ]] && { echo "get_link_type script_prefix not set" 1>&2 ; exit 1 ; }
    [[ -z "$script_test" ]] && { echo "get_link_type script_test not set" 1>&2 ; exit 1 ; }

    if [[ "$script_test" =~ ${script_prefix}_(.*)\.sh$ ]]
    then
        echo "${BASH_REMATCH[1]}"
    fi
}

# for a given link type, generate the container name
function get_container_name() {
    local link_type_val="${1:-}"
    local container_name_val="${container_name:-}"
    if [[ -n "${link_type_val}" ]]
    then
        local container_name_name="container_name_${link_type_val}"
        [[ -n "${!container_name_name:-}" ]] && container_name_val="${!container_name_name}"
    fi

    # check for valid container name
    [[ -z "${container_name_val}" ]] && { echo "container_name not set" 1>&2 ; exit 1 ; }

    echo "${container_name_val}"
}

# for a given container name, generate the image name
function get_image_name() {
    local container_name_val="${1:-}"
    local repo_name=${DOCKER_REPO:-}

    echo "${repo_name:+${repo_name}/}${container_name_val}"
}

# vars may have changed, so set the global host_args with the latest start arguments
function set_host_args() {
    host_args=()
    [[ -n "${container_network:-}" ]] && host_args=(--net "${container_network}")
    host_args+=(--hostname "${container_hostname:-${container_name//_/-}}" --name "${container_name}")
    eval "declare -p host_args" 1>/dev/null 2>&1
}

# choose what to do on symlink name
script_name=$(basename "$0")
case "$script_name" in
build_image*)
    link_type=$(get_link_type "build_image" "${script_name}")
    container_name=$(get_container_name "${link_type}")
    image_name=$(get_image_name "${container_name}")

    if [[ -n "${link_type}" ]]
    then
        build_args_name="build_args_${link_type}[@]"
        [[ -n "${!build_args_name:-}" ]] && build_args=("${!build_args_name}")
    fi

    cmd_title=("#### BUILD ${image_name}")
    cmd_args=("${docker_cmd}" build)
    if [[ -n "${build_args:-}" ]]
    then
        cmd_title+=("'${build_args[*]}'")
        cmd_args+=("${build_args[@]}")
    fi

    if [[ $# -ne 0 ]]
    then
        cmd_title+=("'$*'")
        cmd_args+=("$@")
    fi

    cmd_args+=(--rm -t "${image_name}" "${script_path}/src")

    echo "${cmd_title[*]}"
    exec "${cmd_args[@]}"
    ;;

start_container*)
    link_type=$(get_link_type "start_container" "${script_name}")
    container_name_init="${container_name:-}"
    container_name=$(get_container_name "${link_type}")
    image_name=$(get_image_name "${container_name}")

    if [[ -n "${link_type}" ]]
    then
        [[ "${container_name_init}" == "${container_name}" ]] && container_name="${container_name}_${link_type}"

        docker_args_name="docker_args_${link_type}[@]"
        [[ -n "${!docker_args_name:-}" ]] && docker_args=("${!docker_args_name}")

        command_args_name="command_args_${link_type}[@]"
        [[ -n "${!command_args_name:-}" ]] && command_args=("${!command_args_name}")

        daemon_args_name="daemon_args_${link_type}[@]"
        [[ -n "${!daemon_args_name:-}" ]] && daemon_args=("${!daemon_args_name}")
    fi

    set_host_args

    cmd_title=("#### START ${container_name}")
    cmd_args=("${docker_cmd}" run)

    if [[ -n "${container_daemon:-}" ]]
    then
        cmd_title=("#### START DAEMON ${container_name}")
        cmd_args+=(-d --restart unless-stopped)
    else
        cmd_args+=(--rm)
    fi

    if [[ -z "${container_daemon:-}" && $# -ne 0 ]]
    then
        cmd_args+=(-ti)
    fi

    if [[ -n "${docker_args:-}" ]]
    then
        cmd_args+=("${docker_args[@]}")
    fi

    cmd_args+=("${host_args[@]}" "${image_name}")

    if [[ $# -ne 0 ]]
    then
        cmd_title+=("'$*'")
        cmd_args+=("$@")
    elif [[ -n "${container_daemon:-}" && -n "${daemon_args:-}" ]]
    then
        cmd_title+=("'${daemon_args[*]}'")
        cmd_args+=("${daemon_args[@]}")
    elif [[ -z "${container_daemon:-}" && -n "${command_args:-}" ]]
    then
        cmd_title+=("'${command_args[*]}'")
        cmd_args+=("${command_args[@]}")
    fi

    echo "${cmd_title[*]}"
    exec "${cmd_args[@]}"
    ;;

stop_container*)
    link_type=$(get_link_type "stop_container" "${script_name}")
    container_name_init="${container_name:-}"
    container_name=$(get_container_name "${link_type}")
    image_name=$(get_image_name "${container_name}")

    if [[ -n "${link_type}" ]]
    then
        [[ "${container_name_init}" == "${container_name}" ]] && container_name="${container_name}_${link_type}"

        docker_stop_timeout_name="docker_stop_timeout_${link_type}"
        [[ -n "${!docker_stop_timeout_name:-}" ]] && docker_stop_timeout="${!docker_stop_timeout_name}"
    fi

    echo "#### STOP ${container_name}"
    set +e
    "${docker_cmd}" stop ${docker_stop_timeout:+--time ${docker_stop_timeout}} "${container_name}"
    "${docker_cmd}" logs --tail 100 "${container_name}"
    "${docker_cmd}" rm -v "${container_name}"
    set -e
    ;;

tail_logs*)
    link_type=$(get_link_type "tail_logs" "${script_name}")
    container_name_init="${container_name:-}"
    container_name=$(get_container_name "${link_type}")
    image_name=$(get_image_name "${container_name}")

    if [[ -n "${link_type}" ]]
    then
        [[ "${container_name_init}" == "${container_name}" ]] && container_name="${container_name}_${link_type}"
    fi

    echo "#### TAIL ${container_name}"
    exec "${docker_cmd}" logs --tail 100 -f "${container_name}"
    ;;

exec_bash*)
    link_type=$(get_link_type "exec_bash" "${script_name}")
    container_name_init="${container_name:-}"
    container_name=$(get_container_name "${link_type}")
    image_name=$(get_image_name "${container_name}")

    if [[ -n "${link_type}" ]]
    then
        [[ "${container_name_init}" == "${container_name}" ]] && container_name="${container_name}_${link_type}"
    fi

    echo "#### EXEC BASH ${container_name}"
    exec "${docker_cmd}" exec -ti "${container_name}" bash
    ;;

push_image*)
    link_type=$(get_link_type "push_image" "${script_name}")
    container_name=$(get_container_name "${link_type}")
    image_name=$(get_image_name "${container_name}")

    echo '#### PUSH'

    version=""
    while [[ $# -ne 0 ]]
    do
        if [[ "${1}" == "-y" ]]
        then
            push_git_tag="y"
        else
            version="${1}"
        fi

        shift
    done

    if [[ -z "${version}" ]]
    then
        exec "${docker_cmd}" images | grep "^${image_name} "

    else
        if [[ "${version}" != "latest" ]]
        then
            echo "#### TAG ${image_name}:${version}"
            "${docker_cmd}" tag "${image_name}:latest" "${image_name}:${version}"
        fi

        "${docker_cmd}" push "${image_name}:${version}"

        if [[ $(git diff --stat) != '' ]]; then
            echo "#### Repository state is dirty, please commit before git tag"
            exit 1
        fi

        if [[ "${version}" != "latest" ]]
        then
            echo "#### GIT TAG ${version}"
            git tag -a "${version}" -m "${image_name}:${version}"

            if [[ -z "${push_git_tag:-}" ]]
            then
                read -rp "git push origin --tags? [Y/n]: " -n 1 push_git_tag
            fi

            if [[ -z "${push_git_tag}" || "${push_git_tag}" == "y" || "${push_git_tag}" == "Y" ]]
            then
                git push origin --tags
            fi
        fi
    fi
    ;;

list_remote_tags*)
    link_type=$(get_link_type "list_remote_tags" "${script_name}")
    container_name=$(get_container_name "${link_type}")
    image_name=$(get_image_name "${container_name}")

    echo '#### LIST REMOTE TAGS'

    if [[ "${DOCKER_REPO:-}" =~ ^[0-9]*\.dkr\.ecr\.[^\.]*\.amazonaws\.com\/*(.*)$ ]]
    then
        image_info=$(aws ecr describe-images --repository-name "${BASH_REMATCH[1]:+${BASH_REMATCH[1]}/}${container_name}" | jq '.imageDetails[] | select (.imageTags != null)' | jq -s -c 'sort_by(.imagePushedAt)[] | .imageTags' | tail -r)
        echo "${image_info}"
    else
        echo "Unknown repository: ${DOCKER_REPO:-}"
    fi
    ;;

initialise_*)
    # TODO does not currently support link types
    container_name=$(get_container_name "")
    image_name=$(get_image_name "${container_name}")

    [[ ! "${script_name}" =~ initialise_(.*)\.sh$ ]] && { echo 'unable to determine volume' 1>&2 ; exit 1 ; }
    volume_id="${BASH_REMATCH[1]}"

    volume_name_var="volume_name_${volume_id}"
    volume_dest_var="volume_dest_${volume_id}"
    volume_name="${!volume_name_var}"
    volume_dest="${!volume_dest_var}"
    volume_src="${1:-}"

    [[ -z "${volume_src}" ]] && { echo "src directory not provided" 1>&2 ; exit 1 ; }

    container_name="${container_name}_${volume_name}"
    echo "#### INITIALISE ${container_name} (${volume_src} -> ${volume_dest})"

    trap '${docker_cmd} rm -v ${container_name}' SIGINT SIGTERM EXIT

    set_host_args

    ${docker_cmd} create --rm -v "${container_name}:${volume_dest}" "${host_args[@]}" "${image_name}"
    tar -cf - -C "${volume_src}" . | ${docker_cmd} cp - "${container_name}:${volume_dest}"
    ;;

backup_*)
    # TODO does not currently support link types
    container_name=$(get_container_name "")
    image_name=$(get_image_name "${container_name}")

    [[ ! "${script_name}" =~ backup_(.*)\.sh$ ]] && { echo 'unable to determine volume' 1>&2 ; exit 1 ; }
    volume_id="${BASH_REMATCH[1]}"

    volume_name_var="volume_name_${volume_id}"
    volume_dest_var="volume_dest_${volume_id}"
    volume_name="${!volume_name_var}"
    volume_dest="${!volume_dest_var}"
    volume_backup="backup_${container_name}_${volume_name}.tgz"

    echo "#### BACKUP ${volume_id} (${volume_dest} -> ${volume_backup})"

    exec "${docker_cmd}" cp "${container_name}:${volume_dest}" - | gzip -c > "${volume_backup}"
    ;;

*)
    echo "#### ERROR unsupported invocation: ${script_name}" 1>&2
    exit 1
    ;;
esac
