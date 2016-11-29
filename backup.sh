#!/bin/sh

# Constants.
RANCHER_METADATA_URL="http://rancher-metadata.rancher.internal/2015-12-19"
RANCHER_CONTAINER_URL="$RANCHER_METADATA_URL/self/container"
RANCHER_BACKUP_URL="$RANCHER_METADATA_URL/self/service/metadata/backup"

# Some networks are slow.
sleep 5

# Some variables are mandatory.
if [ -z "$BACKUP_HOME" ]; then
    echo "BACKUP_HOME must be set!"
    exit
fi

curl_it() {
    local __retval=$1
    local result=""
    if [ -z "$2" ]; then
        echo "need one argument -- URL"
    else
        local url="$2"
        # NB: second argument is optional, defaults to ""
        local default="$3"
        
        local result=$(curl -s $url)
        if [ "$result" == "Not found" ]; then
            local result="$default"
        fi
    fi
    eval $__retval="'$result'"
}

values() {
    local __retval=$1
    local value_list=""
    if [ -z "$2" ]; then
        echo "need one argument -- URL"
    else
        local url="$2"
        # NB: second argument is optional, defaults to ""
        local tag="$3"
        
        curl_it keys $url
        for key in $keys
        do
            curl_it new_value "$url/$key"
            if [ "$new_value" == "" ]; then
                echo "$url/$key returned 'Not found'"
            else
                if [ "$value_list" == "" ]; then
                    local value_list="$tag$new_value"
                else
                    local value_list="$value_list $tag$new_value"
                fi
            fi
        done
    fi
    eval $__retval="'$value_list'"
}

backup_dir() {
    local __retval=$1
    local backup_dir=""
    # TODO: check for good values
    # TODO: use parent of sidekick!
    curl_it stack_name "$RANCHER_CONTAINER_URL/stack_name"
    curl_it service_name "$RANCHER_CONTAINER_URL/service_name"
    local backup_dir="$BACKUP_HOME/$stack_name/$service_name"
    # TODO: check for writability
    if [ ! -e $backup_dir ]; then
        echo "Directory not found, creating..."
        mkdir -p $backup_dir
    fi
    eval $__retval="'$backup_dir'"
}

basename_dirs() {
    local __retval=$1
    local basename_dirs
    curl_it basename_dirs "$RANCHER_BACKUP_URL"
    if [ "$basename_dirs" == "" ]; then
        echo "backup metadata not found!"
    fi
    eval $__retval="'$(echo $basename_dirs | sed -e "s|/||g" | xargs echo)'"
}

rotate_files() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "need two arguments -- basename and dir"
    else
        basename="$1"
        dir="$2"
        curl_it keep "$RANCHER_BACKUP_URL/$basename/keep" 1
        steps=$(seq $(expr $keep - 1) -1 1)
        for step in $steps
        do
            old="$dir/$basename.$step.tar.gz"
            new="$dir/$basename.$(expr $step + 1).tar.gz"
            if [ -e $old ]; then
                mv $old $new
            fi
        done
    fi
}

run_tar() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "need two arguments -- basename and dir"
    else
        basename="$1"
        dir="$2"
        values include_list "$RANCHER_BACKUP_URL/$basename/include"
        values exclude_list "$RANCHER_BACKUP_URL/$basename/exclude" "--exclude="
        tar_cmd="tar zcf $dir/$basename.1.tar.gz $include_list $exclude_list"
        tar_out=$($tar_cmd)
        if [ $? != 0 ]; then
            echo "tar command returned errors: $tar_out"
        fi
    fi
}

main() {
    backup_dir dir
    basename_dirs basenames
    for basename in $basenames
    do
        rotate_files $basename $dir
        run_tar $basename $dir
    done
}

main
