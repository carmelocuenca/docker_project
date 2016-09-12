#!/bin/bash

#
# Up machines
#
# docker-machine create -d virtualbox etcd-machine
docker-machine create -d virtualbox postgres-machine
docker-machine create -d virtualbox ruby-machine

#
# Up services
#
# up etcd service, variables $ETCD, $CLUSTER,$INITIAL_CLUSTER_TOKEN must be set
eval $(docker-machine env etcd-machine)
export ETCD=$(docker-machine ip etcd-machine)
export CLUSTER="etcd1=http://$ETCD:2380,etcd2=http://$ETCD:3380,etcd3=http://$ETCD:4380"
export INITIAL_CLUSTER_TOKEN=initial-cluster-token
docker-compose -f docker-compose-etcd.yml up &

# up postgresql service, $POSTGRES_USER, $POSTGRES_PASSWORD must be set
eval $(docker-machine env postgres-machine)
export POSTGRES_USER=${POSTGRES_USER:-postgres}
export POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-mysecretpassword}
export POSTGRES=$(docker-machine ip postgres-machine)
docker-compose -f docker-compose-postgres.yml up &

eval $(docker-machine env ruby-machine)
docker-compose -f docker-compose-ruby.yml up &
