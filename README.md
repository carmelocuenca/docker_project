# Instalación

## Prerrequisitos

- [VirtualBox](https://www.virtualbox.org/)
- [Docker](https://www.docker.com/) La guía de instalación de Docker está en https://docs.docker.com/engine/installation/
- [Docker Machine](https://docs.docker.com/machine/). La guía de instalación de Docker Machine está en https://docs.docker.com/machine/install-machine/

## Scripts para setup la infraestructura

Para levantar la infraestructura
```console
$ sh up.sh
```

Para probar la infraestructura
```console
$ sh check.sh
```

Para destruir la infraestructura
```console
$ sh down.sh
```

## Crea una máquina virtual
```console
$ docker-machine create --virtualbox-disk-size "32768"  -d virtualbox some-machine
```

No olvidar para establecer el entorno de trabajo en el *shell*

```console
$ eval $(docker-machine env some-machine)
```

### Sólo para máquinas físicas con ```/home```
Toda esta guerra es para montar $HOME en la máquina virtual que corre *Docker*-

- Crear un *shared folder* con VirtualBox en la máquina virtual.
Para ello hay que parar la MV.

```console
$ docker-machine stop $DOCKER_MACHINE_NAME
$ VBoxManage sharedfolder add $DOCKER_MACHINE_NAME --name $USER --hostpath $HOME
$ docker-machine start $DOCKER_MACHINE_NAME
```
- Restablecer las variables de entorno
```console
$ eval $(docker-machine env $DOCKER_MACHINE_NAME)
```


- Montar el *shared folder* en la máquina virtual, primero creamos el directorio para montar

```console
docker-machine ssh $DOCKER_MACHINE_NAME "mkdir -p $HOME"
docker-machine ssh $DOCKER_MACHINE_NAME "sudo ls $HOME"
docker-machine ssh $DOCKER_MACHINE_NAME "sudo mount -t vboxsf $USER $HOME"
docker-machine ssh $DOCKER_MACHINE_NAME "sudo ls $HOME"
```

- Comprobar que funciona, listando el contenido de ```$HOME```

## Componer la aplicación
```console
docker-machine ssh $DOCKER_MACHINE_NAME "sudo ls $HOME"
```

Declara un conjunto de variables de entorno para *PostgresSQL*, por ejemplo

```console
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=mysecretpassword
```

```console
$ git clone https://github.com/carmelocuenca/docker_project.git
$ cd docker_project
$ docker-compose up -d
```

## Prueba de la aplicación
```console
$ curl $(docker-machine ip some-machine):8080
```

# De aquí para abajo detalles de implementación
# Linux, NGINX, PostgreSQL y Rails (LEPR)

Proyecto de ejemplo para desplegar una aplicación primero en local, luego en *AWS*.

- Creación de un volumen de datos

```console
$ docker create --name some-data -v /usr/src/myapp -w /usr/src/myapp \
    debian:jessie /bin/true
```

- Clonación de la aplicación

```console
$ docker run --rm -it --volumes-from some-data -w /usr/src/myapp \
    buildpack-deps:jessie \
    git clone https://github.com/railstutorial/sample_app_rails_4.git
```

- Comprobación de la clonación

```console
$ docker run --rm -it --volumes-from some-data -w /usr/src/myapp \
    buildpack-deps:jessie \
    ls sample_app_rails_4
```

- El contenedor *Ruby*

```console
$ docker run --rm -it -p 3000:3000 --name some-ruby --volumes-from some-data \
    -w /usr/src/myapp/sample_app_rails_4 ruby:2.0 sh -c '\
      apt-get update && apt-get install -y nodejs && rm -rf /var/lib/apt/lists/* \
      && bundle install --without production \
      && cp config/database.yml.example config/database.yml \
      && rake db:drop \
      && rake db:migrate \
      && rake \
      && rake db:populate \
      && rails server'
```

- El contenedor *NGINX*

```console
$ docker run --name some-nginx --volumes-from some-data --link some-ruby:app \
    -v "$PWD"/default.conf:/etc/nginx/conf.d/default.conf:ro \
    -p 8080:80 -d nginx
```

- Prueba de los contenedores

```console
$ docker-machine ssh some-machine "curl -H 'Host: www.example.com' some-machine:8080"
```

# Contenedor PostgreSQL

El fichero ```.yml``` de composición incluye ahora un contenedor *PostgreSQL*.
Este enlace con el contenedor de *Ruby* mediante en link *db*.
El posible error de sincronización, el contenedor de *Ruby* inicie antes que el de *PostgreSQL* y la tarea aborte está resulta mediante el flag de ```restar: always```.

Antes de poner en marcha los contendeores, hay que establecer las credenciales en un fichero por ejemplo ```.credential```

```console
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=mysecretpassword
```

Para probar la conexión con el servicio de base de datos
```console
$ PGPASSWORD=$POSTGRES_PASSWORD psql -h $HOST1 -p 5432 -U $POSTGRES_USER -c "\q"
```

# Docker Compose
Para arrancar todos los contenedores (```-d``` para *background* )

```console
$ docker-compose up -d
```
también es útil la opción ```no-recreate```.

La dependencia especificada con la directiva ```depends_on``` no espera que el servicio esté *ready* sólo que se haya inicializado.
De ahí el bucle de espera en ```some-ruby``` para garantizar que el fichero ```config/database.yml``` está copiado.

# La guerra de las credenciales para *AWS*

En ```~/.aws/credentials```

```console
export AWS_SECRET_ACCESS_KEY=****************************************
export AWS_ACCESS_KEY_ID=AKIA****************
export AWS_VPC_ID=vpc-********
export AWS_DEFAULT_REGION=us-east-1
export AWS_ZONE=d
```
Para la obtención del vpc_id y de la aws_zone ver la url https://docs.docker.com/machine/drivers/aws/. Básicamente lo que hay que ir al *dashboard* de las vpc y ver el nombre. El grupo de seguridad lo crea sólo.


Para arrancar la MV en AWS


```console
$ docker-machine -D create --driver amazonec2 \
  --amazonec2-access-key $AWS_ACCESS_KEY_ID \
  --amazonec2-secret-key $AWS_SECRET_ACCESS_KEY \
  --amazonec2-vpc-id $AWS_VPC_ID \
  --amazonec2-region $AWS_DEFAULT_REGION \
  --amazonec2-zone $AWS_ZONE aws01
```
El flag ```-D``` habilita el modo *debug*.

Y una vez que esta *running* (tarda unos 6 minutos)

```console
$ eval $(docker-machine env aws01)
$ docker-compose up
```

Y una vez que esta *running* (tarda unos 10 minutos).
El error *502 Bad Gateway* en el navegador indica que el contenedor *NGINX* ha terminado, pero el *Ruby* anda en ello.
Y una vez que esta todo *OK*,
incluido el mensaje del puma está sirviendo (tarda unos 10 minutos)

Y después de un buen rato, localizar la ip en la consola web y acceder por el puerto 80.

Y para borrar la máquina

```console
$ docker-machine rm -f aws01
```

# Iniciación al descubrimiento. Solución con *Ambassador*

La solución descrita está basada en el patrón descrito en la url https://docs.docker.com/engine/admin/ambassador_pattern_linking/

Hasta aquí los tres contenedores corren en una máquina anfitrión.
La idea ahora es trabajar con dos máquinas mínimo.
El contenedor *PostgreSQL* funcionará en una máquina independiente comp primer pasao para el escalado (servidor de base de datos sólo puede haber una).

Haremos dos ficheros: docker-compose1 y docker-compose2; uno para cada máquina.
En la máquina1 irá el servidor de base de datos. En la dos *NGINX* y *Rails*.

## Creación 2 MV's

En un terminal

```console
$ docker-machine create --virtualbox-disk-size "32768"  -d virtualbox some-machine1
$ eval $(docker-machine env some-machine1)
```

En otro terminal

```console
$ docker-machine create --virtualbox-disk-size "32768"  -d virtualbox some-machine2
$ eval $(docker-machine env some-machine2)
```

En los dos terminales

```console
$ export HOST1=$(docker-machine ip some-machine1)
$ export HOST2=$(docker-machine ip some-machine2)

## Setup del servidor *PostgreSQL*

El fichero docker-compose1.yml contiene información relevante al contenedor *PostgreSQL*. Información del contenedor y un volumen de datos.


Las variables de *shell* ```HOST1```y ```HOST2``` son instanciadas para comodidad cuando usemos otros comandos.

Para levantar la infraestructura en ```some-machine1```

```console
# Postgres' credentials
$ . ~/.postgres/credentials
$ eval $(docker-machine env some-machine1)
$ docker-compose -f docker-compose1.yml up
```


## Infraestructura *PostgreSQL* con *Ambasador*

```console
# Postgres' credentials
$ docker-compose -f docker-compose1.yml up
```

Ver el truco en el fichero ```docker-compose1.yml``` para la redirección del puerto 5432.

## Infraestructura *NGINX*, *Rails* con *Ambasador*

```console
# Postgres' credentials

$ . ~/.postgres/credentials
$ docker-compose -f docker-compose2.yml up
```
## Comprobación funcionamiento local

```console
$ curl $HOST2:8080
```


## Despliegue en la nube AWS


```console
$ docker-machine -D create --driver amazonec2 \
  --amazonec2-access-key $AWS_ACCESS_KEY_ID \
  --amazonec2-secret-key $AWS_SECRET_ACCESS_KEY \
  --amazonec2-vpc-id $AWS_VPC_ID \
  --amazonec2-region $AWS_DEFAULT_REGION \
  --amazonec2-zone $AWS_ZONE aws01
```
El flag ```-D``` habilita el modo *debug*.

Y una vez que esta *running* (tarda unos 6 minutos)

```console
$ eval $(docker-machine env aws01)
$ docker-compose -f docker-compose1.yml up
```

Lo mismo para la otra MV

```console
$ docker-machine -D create --driver amazonec2 \
  --amazonec2-access-key $AWS_ACCESS_KEY_ID \
  --amazonec2-secret-key $AWS_SECRET_ACCESS_KEY \
  --amazonec2-vpc-id $AWS_VPC_ID \
  --amazonec2-region $AWS_DEFAULT_REGION \
  --amazonec2-zone $AWS_ZONE aws02
```
El flag ```-D``` habilita el modo *debug*.

Y una vez que esta *running* (tarda unos 6 minutos)

```console
$ eval $(docker-machine env aws02)
$ docker-compose -f docker-compose2.yml up
```


¿ Problemas ? La MV que corre *PostgreSQL* debe tener abierto el puerto 5432.
En dos sitios: en el grupo de seguridad haciéndolo accesible para la *VPC* y en la máquina con

```console
$ sudo ufw allow 5432
# sudo ufw allow proto tcp from aaa.bbb.ccc.ddd to any port 5432
```

(Realmente debería ser algo más elaborado)


## TravisCI
La aplicación *social_app* incluye ahora un fichero .travis.yml que una vez pasados los test, despliegue la imagen en *Docker Hub*.
Esa imagen es luego utilizada por *docker-compose* para componer la aplicaicón *Rails*.

# Trabajos pendientes

Las dos MVs tienen ip públicas, cuando realmente la de *PostgreSQL* debería tener una *IP* privada de la *VPC*. Cambiarla para que sea privada.

# Comandos útiles

```console
# Crea un MV para Docker
$ docker-machine -D create -d virtualbox some-machine

# Borra una MV
$ docker-machine rm some-machine

# Obtiene la ip de la MV
$ docker-machine ip some-machine

# Lista las MVs
$ docker-machine ls

# Establece el entrono para trabajar con la máquina virtual (puede haber varias)
$ eval $(docker-machine env some-machine)

# Bora todos los contenedores con vólumenes incluidos
$ docker rm -f -v $(docker ps -aq)
```
