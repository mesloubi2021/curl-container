# RedesUNLu Readme

## Building Curl with HTTP3-enabled debian-dev images
This repo is only customized to build a dev debian image with curl + http3 enabled.

## Tools needed and notes
 - An recent and updated Linux distribution capable to run [buildah](https://buildah.io/)
 - Check out the [Buildah install page](https://github.com/containers/buildah/blob/main/install.md) for your Linux distro
 - To build a cross-architecture image, you must install the `qemu-user-static` package.
 - You may omit scanning the images with ClamAV, it's not necessary to install it in that case.
 - TL;DR: Installing all the dependencies: 
```commandline
$ sudo apt-get update
$ sudo apt-get -y install buildah less git make podman qemu qemu-user-static clamav clamav-freshclam
```

# Single-platform image build

## To start the building process, you have to run:
```commandline
$ make branch_or_ref=master release_tag=master build_debian
[... build process...]
```
Done. Now, skip to the 'Pushing the image to the docker hub' step.

## Pushing the single-platform image to the docker hub
```commandline
# Login to docker
$ docker login -u docentetyr
[...]
Login Succeeded

# Push local image to docker hub
$ buildah push localhost/curl-dev-debian:master docentetyr/curl-dev-debian-http3:latest
[... upload process... ]
```

# Multi-platform image build
If you want to build for multiple architectures, like `linux/amd64` and `linux/arm64` and push them into the same image, you must first build the images and then create a manifest with the image list.

## 1. Building the images
The `branch_or_ref` parameter refers to [the branch](https://github.com/curl/curl/branches) [or tag](https://github.com/curl/curl/tags) from [the curl git repository](https://github.com/curl/curl) (this means, basically, the curl source code version).  If you use `master`, you'll build the latest curl development version.

The `release_tag` is only the tag of the docker image being generated, you can choose whatever versioning you want, as long as you follow the same convention through the whole document.
```commandline
# Build for amd64
$ make branch_or_ref="curl-8_7_1" release_tag="8.7.1" arch="linux/amd64" build_debian
[... build process...]

# Build for arm64
$ make branch_or_ref="curl-8_7_1" release_tag="8.7.1" arch="linux/arm64" build_debian
[... build process...]
```

## 2. Creating the Image Manifest

### Creating the image manifest
```commandline
$ buildah manifest create curl-dev-debian-http3-multi:8.7.1
088a948a702b4452e055ebe0e785908624e84ae380d642f47209b806c09bf647
```

### Adding `linux/amd64` and `linux/arm64` images to the manifest
```commandline
$ buildah manifest add curl-dev-debian-http3-multi:8.7.1 localhost/curl-dev-debian-linux-amd64:8.7.1
69fb357a803fee5699d5285f6cf23644295a0d943210836671a7fc33c2bfa2d8: sha256:3855d728102338ecd1d6c941d3a9421e3808bf4a9c974798bc99fe41f3dcc8a7

$ buildah manifest add curl-dev-debian-http3-multi:8.7.1 localhost/curl-dev-debian-linux-arm64:8.7.1
69fb357a803fee5699d5285f6cf23644295a0d943210836671a7fc33c2bfa2d8: sha256:4700188bfc90b23eff1ecae263411b0cce16e37290eb76d425171fd901a3a5d7
```

### Checking the manifest
```commandline
$ buildah manifest inspect localhost/curl-dev-debian-http3-multi:8.7.1                               
{
    "schemaVersion": 2,
    "mediaType": "application/vnd.docker.distribution.manifest.list.v2+json",
    "manifests": [
        {
            "mediaType": "application/vnd.oci.image.manifest.v1+json",
            "size": 758,
            "digest": "sha256:3855d728102338ecd1d6c941d3a9421e3808bf4a9c974798bc99fe41f3dcc8a7",
            "platform": {
                "architecture": "amd64",
                "os": "linux"
            }
        },
        {
            "mediaType": "application/vnd.oci.image.manifest.v1+json",
            "size": 758,
            "digest": "sha256:4700188bfc90b23eff1ecae263411b0cce16e37290eb76d425171fd901a3a5d7",
            "platform": {
                "architecture": "arm64",
                "os": "linux",
                "variant": "v8"
            }
        }
    ]
}
```

### Checking the buildah repository images
The manifest list occupies 1.05 KB in size here:
```commandline
$ buildah images                                                       
REPOSITORY                              TAG      IMAGE ID       CREATED          SIZE
localhost/curl-dev-debian-http3-multi   8.7.1    69fb357a803f   10 minutes ago   1.05 KB
localhost/curl-dev-debian-linux-arm64   8.7.1    a84a02def7ce   31 minutes ago   1.01 GB
localhost/curl-dev-debian-linux-amd64   8.7.1    2e85cf9b27a4   2 hours ago      997 MB
<none>                                  <none>   441394253d3e   33 hours ago     1.01 GB
docker.io/library/debian                latest   5c2e61c12a03   12 days ago      144 MB
```

# Pushing the multiple-platform manifest image list + images to the docker hub
```commandline
# Login to docker
$ docker login -u docentetyr
[...]
Login Succeeded

# Push the manifest, uploading all the images at the same time
$ buildah manifest push --format v2s2 --all localhost/curl-dev-debian-http3-multi:8.7.1 "docker://docker.io/docentetyr/curl-dev-debian-http3:latest"
Getting image list signatures
Copying 2 of 2 images in list
Copying image sha256:3855d728102338ecd1d6c941d3a9421e3808bf4a9c974798bc99fe41f3dcc8a7 (1/2)
[...]
Copying image sha256:4700188bfc90b23eff1ecae263411b0cce16e37290eb76d425171fd901a3a5d7 (2/2)
[...]
```
Done!