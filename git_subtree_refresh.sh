#!/bin/bash -eu

git_url="git@github.com:wamonite"
git_repository="docker_utils"
git_branch="master"
remote_name="${git_repository}"
dest_path="${git_repository}"

# git subtree commands need to be run in the git root
git_root="$(git rev-parse --show-toplevel)"
pushd ${git_root}

# add or fetch the subtree remote
if [[ -z "$(git remote | grep ${remote_name} | head -n 1 | cut -d ' ' -f 1)" ]]
then
    git remote add -f ${remote_name} ${git_url}/${git_repository}
else
    git fetch ${remote_name} ${git_branch}
fi

# squash and merge the subtree
if [[ ! -d "${dest_path}" ]]
then
    git subtree add --prefix ${dest_path} ${remote_name} ${git_branch} --squash
else
    git subtree pull --prefix ${dest_path} ${remote_name} ${git_branch} --squash
fi


# update old symlinks
script_name="docker_utils.sh"

function list_old_symlinks() {
    for link_name in $(find . -type l)
    do
        [[ "$(basename $(readlink ${link_name}))" == "${script_name}" ]] && echo ${link_name}
    done
}

for link_name in $(list_old_symlinks)
do
    echo "UPDATING: ${link_name}"
    if [[ -e "${link_name}" ]]
    then
        rm "${link_name}"
        ln -s "${dest_path}/${script_name}" "${link_name}"
        git add "${link_name}"
    fi
done

if [[ -e "${script_name}" ]]
then
    git rm "${script_name}"
fi
