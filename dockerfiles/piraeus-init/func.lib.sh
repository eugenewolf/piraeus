#!/bin/bash
_linstor_node_list() {
    [[ -z $1 ]] || NODE_NAME="?nodes=$1"
    curl -Ss --connect-timeout 2 \
         -X GET "${CONTROLLER_ENDPOINT}/v1/nodes${NODE_NAME}" \
         -H "Content-Type: application/json" \
        | jq '.'
}

_linstor_has_node() {
    [[ $( _linstor_node_list $1 | jq '.[0]' ) != 'null' ]]
}

_linstor_has_node_ip() {
    [ ! -z $( _linstor_node_list | jq -r ".[] .net_interfaces[] | select(.address == \"$1\" )" ) ]
}

_linstor_node_create() {
    cat > /init/conf/.create_node.json <<EOF
{
    "name": "$1",
    "type": "SATELLITE",
    "net_interfaces": [
        {
            "name": "$2",
            "address": "$3",
            "satellite_port": "$4",
            "satellite_encryption_type": "$5",
            "is_active": "$6"
        }
    ]
}
EOF

    DATA=$( cat /init/conf/.create_node.json | awk -v ORS= -v OFS= '{$1=$1}1' )

    curl -Ss --connect-timeout 2 \
         -X POST "${CONTROLLER_ENDPOINT}/v1/nodes" \
         -H "accept: application/json" \
         -H "Content-Type: application/json" \
         -d "${DATA}" \
        | jq '.'
}


_linstor_node_interface_create() {
    cat > /init/conf/.create_node_interface.json <<EOF
{
    "name": "$2",
    "address": "$3",
    "satellite_encryption_type": "$4"
}
EOF

    DATA=$( cat /init/conf/.create_node_interface.json | awk -v ORS= -v OFS= '{$1=$1}1' )

    curl -Ss --connect-timeout 2 \
         -X POST "${CONTROLLER_ENDPOINT}/v1/nodes/$1/net-interfaces" \
         -H "accept: application/json" \
         -H "Content-Type: application/json" \
         -d "${DATA}" \
        | jq '.'
}

_linstor_node_delete() {
    curl -Ss --connect-timeout 2
         -X DELETE "${CONTROLLER_ENDPOINT}/v1/nodes/k8s-node-1" \
         -H "Content-Type: application/json" \
        | jq '.'
}

_linstor_storage_pool_list() {
    curl -Ss --connect-timeout 2 \
         -X GET "${CONTROLLER_ENDPOINT}/v1/nodes/${NODE_NAME}/storage-pools" \
         -H "Content-Type: application/json" \
        | jq '.'
}

linstor_node_is_online() {
    [[ "$( linstor --machine node list --node $1 \
            | jq '.[0].nodes[0].connection_status' )" == '2' ]]
}

linstor_has_storage_pool() {
    [[ "$( linstor --machine storage-pool list --node $1 --storage-pools $2 \
        | jq '.[0].stor_pools[0]' )" != 'null' ]]
}

_curl_docker() {
    curl -Ss --connect-timeout 2 \
         --unix-socket /var/run/docker.sock \
         -H "Content-Type: application/json" \
         $@
}

_docker_images() {
    _curl_docker \
        -X GET "http://localhost/images/json" \
        | jq '.'
}

_docker_image_inspect() {
    _curl_docker \
        -X GET "http://localhost/images/$1/json" \
        | jq '.'
}

_docker_login() {
    :
}

_docker_pull() {
    _curl_docker \
        -X POST "http://localhost/images/create?fromImage=$1" \
        | jq '.'
}

_docker_start() {
    _curl_docker \
        -X POST "http://localhost/containers/$1/start" \
        | jq '.'
}

_docker_logs() {
    _curl_docker \
        -X GET "http://localhost/containers/$1/logs?stderr=1&stdout=1&follow=1"
}

_docker_run() {
    cat > /init/conf/.create_container.json <<EOF
{
    "Image": "$1",
    "Env": [
        "LB_INSTALL=yes"
    ],
    "HostConfig": {
        "Binds": [
            "/lib/modules:/lib/modules",
            "/usr/src:/usr/src:ro"
        ],
        "Privileged": true
    }
}
EOF

    DATA=$( cat /init/conf/.create_container.json | awk -v ORS= -v OFS= '{$1=$1}1' )
    if [[ ! -z $2 ]]; then
        DATA=$( echo ${DATA} | jq ".HostConfig.Binds += [\"$2\"]" )
    fi

    ID=$( _curl_docker \
            -X POST "http://localhost/containers/create" \
            -d "${DATA}" \
            | jq -r '.Id' )

    if [[ ! -z ${ID} ]]; then
        _docker_start ${ID}
        _docker_logs ${ID}
    else
        echo ERROR: Failed to create container
    fi
}

_get_ip_by_if() {
    ip -f inet address | grep -w $1 | awk '/inet / {print $2}' | sed 's#/.*##'
}

_get_if_by_ip() {
    ip -f inet address | grep -B1 "inet $1" | head -1 | awk '{print $2}' | sed 's/://g'
}






