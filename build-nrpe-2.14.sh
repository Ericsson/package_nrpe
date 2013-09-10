#!/bin/bash
#@(#)Build EIS Configuration Management

pkgname=op5-nrpe
prefix=/opt/op5
PKGDIR=/tmp/op5
build=$PKGDIR/src
SANDBOX=$PKGDIR/sandbox-nrpe
scriptname=${0##*/}
scriptdir=${0%/*}

packagerel=1
nrpe_user=op5nrpe          # uid=95118
nrpe_group=nfsnobody       # gid=65534
nrpe_group_solaris=nogroup # gid=65534

nrpe_version=2.14
nrpe_source="http://downloads.sourceforge.net/project/nagios/nrpe-2.x/nrpe-2.14/nrpe-2.14.tar.gz?r=&ts=1358498785&use_mirror=heanet"

#-----------------------------------------------
# Linux Dist
#-----------------------------------------------

linux_dist () {
   if [ -f /etc/redhat-release ] ; then
      typeset dist="rhel"
      typeset ver=$(sed 's/^[^0-9]*\([0-9]*\).*$/\1/' /etc/redhat-release)
   else if [ -f /etc/SuSE-release ] ; then
      typeset dist="suse"
      typeset ver=$(sed -n '1s/^[^0-9]*\([0-9]*\).*$/\1/p' /etc/SuSE-release)
   else if [ -f /etc/debian_version ] ; then
      typeset dist="debian_"
      typeset ver=$(sed -n '1s/^\([^\/]*\)\(\/sid\)*/\1/p' /etc/debian_version)
   fi ; fi ; fi


   if [ -z "$dist" -o -z "$ver" ] ; then
      echo Unsupported linux dist $dist $ver 1>&2
      exit 1
   fi
   echo $dist$ver
   return
}


#-----------------------------------------------
# RootDo
#-----------------------------------------------

rootdo () {
   if [ $UID = 0 ] ; then
      $*
   else
      sudo $*
   fi
}


#-----------------------------------------------
# Get Source
#-----------------------------------------------

get_source () {
   typeset sw=$1
   typeset srcdir=`eval echo ${sw}-'$'${sw}_version`
   typeset url=`eval echo '$'${sw}_source`
   test -d $srcdir && return
   test -s $srcdir.tar.gz || rm -f $srcdir.tar.gz
   test -f $srcdir.tar.gz || wget -O $srcdir.tar.gz $url
   gzip -dc $srcdir.tar.gz | tar xf -
}


#-----------------------------------------------
# Build NRPE
#-----------------------------------------------

build_nrpe() {
   echo Building nrpe
   cd $build
   cd nrpe-$nrpe_version
   make clean
   case `uname -s` in
      'SunOS')
         hasfiles=`find $prefix -type f`
         if [ -n "$hasfiles" ] ; then
            echo "ERROR: target dir $prefix already exists. Remove it"
            exit 1
         fi
         #LDFLAGS=-L/lib -L/app/gcc/4.4.3/lib -static-libgcc
         #LDFLAGS=-static-libgcc
         export LDFLAGS

         case `uname -r` in
            #
            # Solaris 8
            #
            '5.8')
               PATH=/app/gcc/4.1.2/bin:$PATH
               export PATH

               LD_RUN_PATH=/app/gcc/4.1.2/lib/sparcv9:/app/gcc/4.1.2/lib
               LOADEDMODULES=gcc/4.1.2
               _LMFILES_=/env/common/modules/gcc/4.1.2
               export LD_RUN_PATH LOADEDMODULES _LMFILES_

               cp src/acl.c src/acl.c.orig

patch src/acl.c <<EOF
46a47,51
> #ifndef isblank
> #define isblank(c)((c) == ' ' || (c) == '\t')
> #endif
>
>
EOF

               ./configure --prefix=$prefix/nrpe --with-nrpe-user=$nrpe_user --with-nrpe-group=$nrpe_group_solaris --with-nagios-user=$nrpe_user --with-nagios-group=$nrpe_group_solaris --enable-ssl --enable-command-args --with-ssl-lib=/opt/csw/lib/32 --with-ssl=/opt/csw

               cp src/Makefile src/Makefile.ORG

patch -e src/Makefile <<EOF
15d
EOF

patch src/Makefile <<EOF
15a16,17
> LDFLAGS=-L/opt/csw/lib/32 /opt/csw/lib/sparcv8plus+vis/libssl.a /opt/csw/lib/sparcv8plus+vis/libcrypto.a -ldl
>
EOF

               make && make install
            ;;
            #
            # Solaris 9
            #
            '5.9')
               PATH=/app/gcc/4.1.2/bin:$PATH
               export PATH

               LD_RUN_PATH=/app/gcc/4.1.2/lib/sparcv9:/app/gcc/4.1.2/lib
               LOADEDMODULES=gcc/4.1.2
               _LMFILES_=/env/common/modules/gcc/4.1.2
               export LD_RUN_PATH LOADEDMODULES _LMFILES_


               cp src/acl.c src/acl.c.orig

patch src/acl.c <<EOF
46a47,51
> #ifndef isblank
> #define isblank(c)((c) == ' ' || (c) == '\t')
> #endif
>
>
EOF

               ./configure --prefix=$prefix/nrpe --with-nrpe-user=$nrpe_user --with-nrpe-group=$nrpe_group_solaris --with-nagios-user=$nrpe_user --with-nagios-group=$nrpe_group_solaris --enable-ssl --enable-command-args --with-ssl-lib=/opt/csw/lib/32 --with-ssl=/opt/csw

               cp src/Makefile src/Makefile.ORG

patch -e src/Makefile <<EOF
15d
EOF

patch src/Makefile <<EOF
15a16,17
> LDFLAGS=-L/opt/csw/lib/32 /opt/csw/lib/sparcv8/libssl.a /opt/csw/lib/sparcv8/libcrypto.a -ldl
>
EOF
               make && make install
            ;;
            #
            # Solaris 10 <
            #
            *)
               ./configure --prefix=$prefix/nrpe --with-nrpe-user=$nrpe_user --with-nrpe-group=$nrpe_group_solaris --with-nagios-user=$nrpe_user --with-nagios-group=$nrpe_group_solaris --enable-ssl --enable-command-args --with-ssl-lib=/usr/sfw/lib --with-ssl-inc=/usr/sfw/include --with-ssl=/usr/sfw

               # needed for nrpe-2.12
               #cp src/nrpe.c src/nrpe.c.orig
               #sed -e 's/LOG_AUTHPRIV;/LOG_AUTH;/' -e 's/LOG_FTP;/LOG_DAEMON;/' src/nrpe.c.orig > src/nrpe.c
               gmake && gmake install
            ;;
         esac

         if [ '!' -x $prefix/nrpe/bin/nrpe ] ; then
            echo Nrpe did not build correctly
            exit 1
         fi
         mkdir -p $prefix/scripts $prefix/plugins-contrib $prefix/etc/init.d $prefix/data
         chown -R $nrpe_user:$nrpe_group_solaris $prefix/data $prefix/scripts $prefix/plugins-contrib $prefix/etc/init.d
         nrpe_initscript solaris > $prefix/etc/init.d/nrpe
         chmod 755 $prefix/etc/init.d/nrpe
      ;;
      'HP-UX')
         CC=/usr/local/bin/gcc
         export CC
         #CFLAGS="-O2 -g -pthread -mlp64 -w -pipe -Wall"
         ./configure --prefix=$prefix
         export CFLAGS
         make && make install
         break
      ;;
      'Linux')
         DISTVER=`linux_dist`
         if [ "${DISTVER#debian}" != "$DISTVER" ] ; then
            SSL_LIB='--with-ssl-lib=/usr/lib/x86_64-linux-gnu'
         fi

         ./configure --prefix=$prefix/nrpe --with-nrpe-user=$nrpe_user --with-nrpe-group=$nrpe_group --with-nagios-user=$nrpe_user --with-nagios-group=$nrpe_group --enable-ssl $SSL_LIB --enable-command-args
         make && rootdo make install
         make install DESTDIR=$SANDBOX
         if [ '!' -x $SANDBOX/$prefix/nrpe/bin/nrpe ] ; then
            echo Nrpe did not build correctly
            exit 1
         fi
         mkdir -p $SANDBOX/$prefix/scripts $SANDBOX/$prefix/plugins-contrib $SANDBOX/$prefix/data $SANDBOX/$prefix/etc/init.d
         chown -R $nrpe_user:$nrpe_group $SANDBOX/$prefix/data $SANDBOX/$prefix/scripts $SANDBOX/$prefix/plugins-contrib $SANDBOX/$prefix/etc/init.d
         nrpe_initscript $DISTVER > $SANDBOX/$prefix/etc/init.d/nrpe
         chmod 755 $SANDBOX/$prefix/etc/init.d/nrpe
      ;;
      *)
         echo Unsupported OS `uname -s`
         exit 1
         break
      ;;
   esac
}


#-----------------------------------------------
# Build rpm package (RedHat & SuSE)
#-----------------------------------------------

nrpe_rpm () {
   typeset SPEC=/var/tmp/nrpe.spec
   rm -f $SPEC

cat << EOSPEC >> $SPEC
Name: ${pkgname}
URL: https://wiki.lmera.ericsson.se/wiki/ITTE/OP5_Operations_Guide
Summary: NRPE agent installed in $prefix
Version: ${nrpe_version}
Release: ${packagerel}_$DISTVER
License: GPL
Group: Applications/System
Buildroot: $SANDBOX
AutoReqProv: no

%description
NRPE agent installed in $prefix

%post
rm -f /etc/init.d/nrpe
ln -s $prefix/etc/init.d/nrpe /etc/init.d/nrpe
mkdir -p /var/run/op5
chmod 0766 /var/run/op5

if [ -x /sbin/insserv ]; then
   /sbin/insserv /etc/init.d/nrpe &> /dev/null
elif [ -x /sbin/chkconfig ]; then
   /sbin/chkconfig nrpe on
else
   echo "No chkconfig found! Could not make autostart links. Exiting!"
   exit 4;
fi
if [ -f $prefix/etc/nrpe.cfg ] ; then
   pkill -x nrpe
   /etc/init.d/nrpe start
fi

%files
%(cd $SANDBOX; find opt '!' -type d | xargs stat --format "%%%attr(%a,%U,$nrpe_group) %n" | sed s,${prefix#/},$prefix,)
%attr(755,$nrpe_user,$nrpe_group) $prefix/data
%attr(755,$nrpe_user,$nrpe_group) $prefix/scripts
%attr(755,$nrpe_user,$nrpe_group) $prefix/plugins-contrib

%preun
chkconfig nrpe off
service nrpe stop

%postun
rm -f /etc/init.d/nrpe
rm -rf /var/run/op5
rm -rf $prefix/nrpe
EOSPEC

   rpmbuild --define "_rpmdir $PKGDIR"  --buildroot=$SANDBOX -bb $SPEC
   mv ${PKGDIR}/`uname -i`/${pkgname}-${nrpe_version}-${packagerel}_${DISTVER}.`uname -i`.rpm /var/tmp/ && echo wrote /var/tmp/${pkgname}-${nrpe_version}-${packagerel}_${DISTVER}.`uname -i`.rpm

   rm -rf $SPEC ${PKGDIR}/`uname -i`

}


#-----------------------------------------------
# Build Debian Package (Ubuntu)
#-----------------------------------------------

nrpe_deb () {
   typeset CTRL=$SANDBOX/DEBIAN/control
   typeset POSTINST=$SANDBOX/DEBIAN/postinst
   mkdir -p $SANDBOX/DEBIAN

cat << EOSPEC > $CTRL
Package: ${pkgname}
Version: ${nrpe_version}-${nagiosplugins_version}-${packagerel}
Architecture: $architecture
Priority: optional
Section: base
Maintainer: Ericsson internal <root@ericsson.se>
Description: This is nrpe installed in $prefix
EOSPEC

cat << EOSPEC > $POSTINST
rm -f /etc/init.d/nrpe
ln -s $prefix/etc/init.d/nrpe /etc/init.d/nrpe
update-rc.d nrpe defaults
mkdir -p /var/run/op5
chmod 0766 /var/run/op5
EOSPEC

   chmod 755 $POSTINST
   cd $SANDBOX/..
   dpkg-deb --build $(basename $SANDBOX)
   echo Wrote /var/tmp/${pkgname}-${nrpe_version}-${packagerel}${DISTVER#debian}.`uname -i`.deb
   mv $(basename $SANDBOX).deb /var/tmp/${pkgname}-${nrpe_version}-${packagerel}${DISTVER#debian}.`uname -i`.deb
}


#-----------------------------------------------
# Build Solaris Package
#-----------------------------------------------

nrpe_pkg () {
   typeset PKGROOT=/var/tmp/nrpe-pkgroot

   mkdir $PKGROOT
   cd /
   find $prefix | cpio -pmd ${PKGROOT}
   platform=`uname -p`
   find ${PKGROOT} | sed s,${PKGROOT},,| pkgproto > ${PKGROOT}/cm.proto

cat << EOP >> ${PKGROOT}/cm.proto
i checkinstall
i pkginfo
i postinstall
i preremove
EOP

cat << EOT > $PKGROOT/checkinstall
#!/bin/sh

expected_platform="$platform"
platform=`uname -p`
if [ \${platform} != \${expected_platform} ]; then
        echo "This package must be installed on \${expected_platform}"
        exit
fi
exit 0
EOT

cat << EOT2 > ${PKGROOT}/pkginfo
PKG="EIS${pkgname}"
NAME="nrpe"
VERSION="$nrpe_version"
ARCH="$platform"
CLASSES="none"
CATEGORY="tools"
VENDOR="EIS"
PSTAMP="21thAug2013"
EMAIL="anders.k.lindgren@ericsson.com"
ISTATES="S s 1 2 3"
RSTATES="S s 1 2 3"
BASEDIR="/"
SUNW_PKG_ALLZONES="false"
SUNW_PKG_HOLLOW="false"
SUNW_PKG_THISZONE="true"
EOT2

   . $scriptdir/solaris-postinstall.sh
   solaris_postinstall > ${PKGROOT}/postinstall
   solaris_preremove > ${PKGROOT}/preremove
   cd ${PKGROOT}
   solvers=$(uname -r)
   solvers=${solvers#5.}
   pkgfile=${pkgname}-$nrpe_version-sol$solvers-$platform
   mkdir /var/tmp/eis 2>/dev/null
   pkgmk -o -r / -d /var/tmp/eis -f cm.proto
   cd /var/tmp/eis
   pkgtrans -s `pwd` /var/tmp/$pkgfile "EIS${pkgname}"
   echo Wrote /var/tmp/$pkgfile
   rm -rf /var/tmp/eis/$pkgname
   rmdir /var/tmp/eis 2>/dev/null

   if [ -n "$PKGROOT" ] ; then
      rm -rf $PKGROOT
   fi
}


#-----------------------------------------------
# Build Package
#-----------------------------------------------

make_pkg () {
   typeset what=$1
   case `uname -s` in
      'SunOS')
         ${what}_pkg
      ;;
      'HP-UX')
         echo To be implemented
         exit 1
      ;;
      'Linux')
         architecture=`uname -i`
         if [ `uname -s` = 'Linux' ] ; then
            DISTVER=`linux_dist`
         fi
         if [ "${DISTVER#debian}" != "$DISTVER" ] ; then
            if [ "$architecture" = x86_64 ] ; then
               architecture=amd64
            fi
	    ${what}_deb
         else if [ "${DISTVER#suse}" != "$DISTVER" -o "${DISTVER#rhel}" != "$DISTVER" ] ; then
            ${what}_rpm
         else
            echo do not know how to package for $DISTVER
             exit 1
         fi ; fi
      ;;
      *)
         echo To be implemented
         exit 1
      ;;
   esac
}

#-----------------------------------------------
# Main
#-----------------------------------------------

if [ -z "$scriptdir" ] ; then
  scriptdir=`pwd`
else
  # handle ../ and ./
  cd $scriptdir
  scriptdir=`pwd`
  cd -
fi

case `uname -s` in
   'SunOS')
      PATH=/usr/sbin:/usr/bin:/usr/sfw/bin:/usr/ccs/bin:/opt/csw/bin
      export PATH
   ;;
esac

test -d "$prefix" || mkdir -p $prefix
test -d "$build" || mkdir -p $build

cd $build
get_source nrpe
. $scriptdir/nrpe-initscript.sh
build_nrpe
make_pkg nrpe


