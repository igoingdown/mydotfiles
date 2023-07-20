#!/bin/bash

# set envs to mock devbox on mac
set_devbox_env_var() {
    export CONSUL_HTTP_PORT=2280
    export CONSUL_HTTP_HOST=10.227.19.33
    export RUNTIME_IDC_NAME=boe
}

unset_devbox_env_var() {
    unset CONSUL_HTTP_PORT
    unset CONSUL_HTTP_HOST
    unset RUNTIME_IDC_NAME
}

local_test() {
    source $HOME/github/mydotfiles/my_shell_config.sh
    go test -count=1 -v -coverprofile cover.out
    go tool cover -html=cover.out -o cover.html
    open cover.html
}

