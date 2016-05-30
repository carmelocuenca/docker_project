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
