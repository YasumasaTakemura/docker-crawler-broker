#!/usr/bin/env bash

# set env
LOGGING="\"json-file\""
is_vm=false
ENV=dev

check_on_vm(){
    # exports variables  from .env if not GCE_DBUGGING is False
    is_vm=`cat /etc/hosts | grep "Added by Google"`
    if [ "$is_vm" ];then
        is_vm=true
        LOGGING="\"gcplogs\""
    fi
}

set_env(){
    export `cat ./env/.env | grep -v ^# | xargs`
}

gen_env_file(){
    # read params from .env
    if [ ! -f  "./env/.env" ]; then
        touch ./env/.env
    fi
}

cleanup_env(){
    unset SQLPROXY_IMG_VERSION
    unset DATABASE_ID
    unset NGINX_VERSION
}

# check args
while getopts e: OPT
do
    case $OPT in
        e)  ENV=$OPTARG
            ;;
        h)  usage_exit
            ;;
        \?) usage_exit
            ;;
    esac
done


# generate env file
gen_env_file

# are you on VM
check_on_vm

#decrypt env file and keys for ssl
bash ./bin/kms.sh d && set_env

# replace params
sed -e "s/SQLPROXY_IMG_VERSION/$SQLPROXY_IMG_VERSION/g" \
    -e "s/NGINX_VERSION/$NGINX_VERSION/g" \
    -e "s/SOURCE_IMAGE/$SOURCE_IMAGE/g" \
    -e "s/LOGGING/$LOGGING/g" \
    -e "s/ENV/$ENV/g" \
    ./template/docker-compose-template.yml  >  ./docker-compose.yml

gcloud docker -- pull gcr.io/$PROJECT_ID/$SOURCE_IMAGE:$ENV && \
docker tag gcr.io/$PROJECT_ID/$SOURCE_IMAGE:$ENV $SOURCE_IMAGE:$ENV && \
docker-compose build --no-cache
docker-compose up -d

# clean-up
if [ ! "$is_vm" ];then
    cleanup_env
fi
rm ./docker-compose.yml $PWD/env/.env
