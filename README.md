# Instalación

## Prerrequisitos

- [VirtualBox](https://www.virtualbox.org/)
- [Docker](https://www.docker.com/) La guía de instalación de Docker está en https://docs.docker.com/engine/installation/
- [Docker Machine](https://docs.docker.com/machine/). La guía de instalación de Docker Machine está en https://docs.docker.com/machine/install-machine/


## Crea una máquina virtual
```console
$ docker-machine create -d virtualbox some-machine
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
docker-machine ssh $DOCKER_MACHINE_NAME "sudo ls $HOME"
```

- Comprobar que funciona, listando el contenido de ```$HOME```

## Componer la aplicación


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
