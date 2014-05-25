## Description
This repository houses the sources and build system for custom packages used in Tunapanda Edubuntu. 

The goal is to make it extremely easy to create simple packages that just do things like install documentation, update configuration files, etc. 

### Warning!
These packages and the build system are still very primitive. Don't expect much yet!

## Dependencies 
* The build script uses Jordan Dissel's awesome ["effing package management" (FPM) tool](https://www.github.com/jordandissel/fpm/)

## How packages are built:
Each package has its own directory
* Package dirs *must* have:
 * an fs/ subdir, which contains all files provided by the package, as if fs/ was the / directory on the target system
 * A build_overrides file, which *must* define:
  * DESCRIPTION (short description of the package)
 * ...and *may* define:
  * NAME 	(defaults to directory name)
  * VERSION 	(defaults to 1.0)
  * ARCH 	(defaults to 'all')
  * OUTPUT_DIR	(defaults to a Packages/ subdir of wherever build.sh lives)
* Package dirs *may* have...
 * A scripts/ subdir, containing any combination of pre-install.sh, post-install.sh, pre-remove.sh, post-remove.sh


Once the package direcory(ies) have everything you want, you can build them with:

```
./build.sh PACKAGE_DIR...
```
