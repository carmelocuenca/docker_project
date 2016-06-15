#!/bin/bash

eval $(docker-machine env etcd-machine)
ETCD=$(docker-machine ip etcd-machine)
# check etcd service
curl -s http://$ETCD:2379/v2/members
curl -s http://$ETCD:3379/v2/members
curl -s http://$ETCD:4379/v2/members
curl -s http://$ETCD:8080/v2/members

eval $(docker-machine env postgres-machine)
export POSTGRES_USER=${POSTGRES_USER:-postgres}
export POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-mysecretpassword}
export POSTGRES=$(docker-machine ip postgres-machine)
PGPASSWORD="$POSTGRES_PASSWORD" psql -h $POSTGRES -p 5432 -U "$POSTGRES_USER" -c "\l"


curl http://$(docker-machine ip ruby-machine):8080
