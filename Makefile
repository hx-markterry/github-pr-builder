install:
  script/perl_setup.sh
  cpanm install Carton
  carton install

.PHONY: install