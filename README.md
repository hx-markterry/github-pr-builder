github-pr-builder
=================

Build github projects when pull requests are made.

Requirements
------------

* Carton
* Local::lib

If your system is not setup to use these already, run:

    script/perl_setup.sh

Installation
------------

    carton install

Usage
-----

1. Copy the example config file `root/config_example.json` to `root/config.json` and edit with your settings.
1. Make sure the build directory exists.
1. Run script/builder.pl

The time of the last check will be written to `.lastrun`, the next check will use this time when checking for new pull requests,
ensuring that a pull request is not processed twice.

If no last run file is present the last hour will be used as a default.

Notes
-----

Using a system temp directory as a build directory can cause problems when running xcode commands on OSX.