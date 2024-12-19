# snpit_docker_env

A fledgling/proposed dockerized environment for the SN PIT, currently maintained by Rob Knop (raknop@lbl.gov).

This is currently in very early development, so expect things to change.

Thus far, this docker environment has been used with Lauren Aldoroty's difference imaging lightcurve package phrosty (https://github.com/Roman-Supernova-PIT/phrosty).  For these purposes, Rob maintains two images of this environment, a "production" version, and a much more bloated "dev" version.  (Alas, even the production version is already a distressingly large 6.5GB (as of this writing); the dev image is 13.2 GB.)  Ideally, the "production" environment includes everything you need to run code.  The "dev" image includes code necessary for building and compiling (gcc, make, dev libraries including CUDA dev libraries), as well as some profiling tools (valgrind, NVIDIA nsight-systems and nsight-compute).

They images stored in a couple of different places\

* Production image:
  * `registry.nersc.gov/m4385/rknop/roman-snpit:<tag>`
  * `docker.io/rknop/roman-snpit:<tag>`

* Dev image:
  * `registry.nersc.gov/m4385/rknop/roman-snpit-dev:<tag>`
  * `docker.io/rknop/roman-snpit-dev:<tag>`

For `<tag>`, various different things will be there.  There will always be a `latest` tag, but that may not be what you want.  There will be other tags that have to do with specific experiments that Rob and those he's working with are using.  There will also be tags for "releases" of the image, named 'vx.y.z' where `x`, `y`, and `z` follow usual semantic verisoning conventions.  If all is well, those releases will correspond to commits with the same tag in this git archive.

### Currently available releases

As of this writing:

* v0.0.1

(It's early days.)


## Building

You can build the dev image with:

```
DOCKER_BUILDKIT=1 docker build --target dev-runtime -t <imagename> .
```

where `<imagename>` is whatever you want the image to be called, including the place you expect to push it if you plan on doing so.

You can build the production image with:

```
DOCKER_BUILDKIT=1 docker build --target runtime -t <imagename> .
```
