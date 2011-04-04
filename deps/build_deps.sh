#!/bin/bash

#wget http://ftp.mozilla.org/pub/mozilla.org/js/js-1.7.0.tar.gz
#tar -xzvf js-1.7.0.tar.gz

rm js-1.8.0-rc1.tar.gz
rm -rf js/

wget http://ftp.mozilla.org/pub/mozilla.org/js/js-1.8.0-rc1.tar.gz
tar -xzvf js-1.8.0-rc1.tar.gz

cd js/src
make -f Makefile.ref
cd ../..

cd JavaScript-SpiderMonkey-0.19-patched
perl Makefile.PL
make
make test && make install
cd ..


#sudo cpan Log::Log4perl
