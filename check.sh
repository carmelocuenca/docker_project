#!/bin/bash

eval $(docker-machine env consul-machine)
curl $(docker-machine ip consul-machine)):8500/v1/catalog/services

eval $(docker-machine env postgres-machine)
export POSTGRES_USER=${POSTGRES_USER:-postgres}
export POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-mysecretpassword}
export POSTGRES=$(docker-machine ip postgres-machine)
PGPASSWORD="$POSTGRES_PASSWORD" psql -h $POSTGRES -p 5432 -U "$POSTGRES_USER" -c "\l"


curl http://$(docker-machine ip ruby-machine):8080
