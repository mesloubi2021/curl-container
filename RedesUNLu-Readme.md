# RedesUNLu Readme

Work in Progress. 

This is only customized to build a dev debian image with curl + http3 enabled:

```commandline
$ make branch_or_ref=master release_tag=master build_debian
[... build process...]

# Docker login to the docker hub
$ docker login -u docentetyr

# Push local image to docker hub
$ buildah push localhost/curl-dev-debian:master docentetyr/curl-dev-debian-http3:latest
```