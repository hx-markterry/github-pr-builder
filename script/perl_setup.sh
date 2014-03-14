#!/bin/bash
#sets up carton, cpan minus and local::lib
set -e
curl -L http://cpanmin.us | perl - -l ~/perl5 App::cpanminus local::lib
echo 'eval `perl -I ~/perl5/lib/perl5 -Mlocal::lib`' >> ~/.bash_profile
echo 'export PATH=~/perl5/bin:$PATH' >> ~/.bash_profile
. ~/.bash_profile
cpanm Carton