#!/bin/bash
# This script converts all your git submodules into git subtrees,
# and ensures that your new subtrees point to the same commits as the
# old submodules did, unlike most other scripts that do this.
#
# THIS SCRIPT SHOULD BE PLACED OUTSIDE OF YOUR REPOSITORY!!!!!!!!!!
#
# Otherwise, the script will interfere with the git commits (unless you add it to .gitignore).
# Save the script in your home directory as `~/subtrees.sh`
# `cd` into your repository
# Run `~/subtrees.sh`
# Enjoy!

CVT_FAILED=()

git submodule sync
git submodule update --depth 1

function iterate_modules() {
    while read mpath; do
        if [[ $mpath != \[submodule* ]]; then
            continue
        fi

        echo converting $mpath
        read mpath
        read murl
        # extract the module's prefix and url
        mpath=$(echo $mpath | grep -E "(\S+)$" -o)
        murl=$(echo $murl | cut -d\= -f2 | xargs)
        mname=$(basename $mpath)
        # extract the referenced commit
        mcommit=$(git submodule status $mpath | grep -E "\S+" -o | head -1)

        echo name: $mname, path: $mpath url: $murl commit: $mcommit
        echo

        if [ -z "$mpath" ] || [ -z "$murl" ] || [ -z "$mcommit" ]; then
            CVT_FAILED+=("$mpath")
            echo Bad submodule $mpath
            continue
        fi
        local callback=$1
        $callback $mname $mpath $murl $mcommit
    done < .gitmodules
}

function add_remote() {
    local mname=$1
    local mpath=$2
    local murl=$3
    local mcommit=$4

    echo add remote for master branch: $mpath $murl
#    git remote remove $mname &> /dev/null
#    git remote remove $mpath &> /dev/null
    git remote add -t master $mpath $murl
}

function rm_subm_add_subt() {
    local mname=$1
    local mpath=$2
    local murl=$3
    local mcommit=$4

    if [[ " ${CVT_FAILED[@]} " =~ " ${mpath} " ]]; then
        return 1
    fi

    echo deinit and remove the module: $mpath $murl $mcommit
    git submodule deinit $mpath
    git rm -r --cached $mpath
    rm -rf $mpath
    git commit -m "Removed submodule $mpath at commit $mcommit"

    echo add the subtree
    git subtree add --prefix $mpath $mcommit --squash || \
        git subtree pull --prefix $mpath $murl master --squash

    echo
    echo
    echo
}


iterate_modules add_remote

git fetch --all --depth 1 --jobs 4 && \
    iterate_modules rm_subm_add_subt

if [ ${#CVT_FAILED[@]} -gt 0 ]; then
    echo "

#### IMPORTANT ####
The following submodules convert failed:
${CVT_FAILED[@]}

    "
else
    echo "

All submodules converted successfully.

    "
fi 

#git rm .gitmodules
#git commit -a -m "Removed .gitmodules"

