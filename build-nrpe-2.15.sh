#!/bin/bash
#@(#)Build EIS Configuration Management

pkgname=op5-nrpe
pkgdescription="op5 nrpe"
prefix=/opt/op5
PKGDIR=/tmp/op5
build=$PKGDIR/src
SANDBOX=$PKGDIR/sandbox-nrpe
scriptname=${0##*/}
scriptdir=${0%/*}

packagerel=4
nrpe_user=op5nrpe
nrpe_user_solaris=op5nrpe
nrpe_uid=95118
nrpe_group=nfsnobody
nrpe_group_solaris=nogroup
nrpe_gid=65534
nrpe_home=/opt/op5/data

nrpe_version=2.15
nrpe_source="http://sourceforge.net/projects/nagios/files/nrpe-2.x/nrpe-2.15/nrpe-2.15.tar.gz/download"

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

               ./configure --prefix=$prefix/nrpe --with-nrpe-user=$nrpe_user_solaris --with-nrpe-group=$nrpe_group_solaris --with-nagios-user=$nrpe_user_solaris --with-nagios-group=$nrpe_group_solaris --enable-ssl --enable-command-args --with-ssl-lib=/opt/csw/lib/32 --with-ssl=/opt/csw

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

               ./configure --prefix=$prefix/nrpe --with-nrpe-user=$nrpe_user_solaris --with-nrpe-group=$nrpe_group_solaris --with-nagios-user=$nrpe_user_solaris --with-nagios-group=$nrpe_group_solaris --enable-ssl --enable-command-args --with-ssl-lib=/opt/csw/lib/32 --with-ssl=/opt/csw

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
               ./configure --prefix=$prefix/nrpe --with-nrpe-user=$nrpe_user_solaris --with-nrpe-group=$nrpe_group_solaris --with-nagios-user=$nrpe_user_solaris --with-nagios-group=$nrpe_group_solaris --enable-ssl --enable-command-args --with-ssl-lib=/usr/sfw/lib --with-ssl-inc=/usr/sfw/include --with-ssl=/usr/sfw

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
         chown -R $nrpe_user_solaris:$nrpe_group_solaris $prefix/data $prefix/scripts $prefix/plugins-contrib $prefix/etc/init.d
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

%pre
/usr/bin/getent group $nrpe_group > /dev/null || /usr/sbin/groupadd -r -o -g $nrpe_gid $nrpe_group
/usr/bin/getent passwd $nrpe_user > /dev/null || /usr/sbin/useradd -r -u $nrpe_uid -g $nrpe_gid -d $nrpe_home -s /bin/false $nrpe_user

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
rm -rf $prefix/etc/init.d/
rmdir --ignore-fail-on-non-empty $prefix/etc
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
   typeset PRE=$SANDBOX/DEBIAN/preinst
   typeset POSTINST=$SANDBOX/DEBIAN/postinst
   typeset PRERM=$SANDBOX/DEBIAN/prerm
   typeset POSTRM=$SANDBOX/DEBIAN/postrm
   mkdir -p $SANDBOX/DEBIAN

cat << EOSPEC > $CTRL
Package: ${pkgname}
Version: ${nrpe_version}-${packagerel}
Architecture: $architecture
Priority: optional
Section: base
Maintainer: Ericsson internal <root@ericsson.se>
Description: This is nrpe installed in $prefix
EOSPEC

cat << EOSPEC > $PRE
getent group $nrpe_group > /dev/null || groupadd -r -o -g $nrpe_gid $nrpe_group
getent passwd $nrpe_user > /dev/null || useradd -r -u $nrpe_uid -g $nrpe_gid -d $nrpe_home -s /bin/false $nrpe_user
EOSPEC

cat << EOSPEC > $POSTINST
rm -f /etc/init.d/nrpe
ln -s $prefix/etc/init.d/nrpe /etc/init.d/nrpe
update-rc.d nrpe defaults
mkdir -p /var/run/op5
chmod 0766 /var/run/op5
chown $nrpe_user /var/run/op5
cat << EOCONF > /opt/op5/etc/nrpe.cfg
allowed_hosts=127.0.0.1
command_timeout=60
connection_timeout=300
debug=0
dont_blame_nrpe=0
include_dir=/opt/op5/etc/nrpe.d/
log_facility=daemon
nrpe_group=$nrpe_group
nrpe_user=$nrpe_user
pid_file=/var/run/op5/nrpe.pid
server_port=5666
EOCONF
service nrpe start
EOSPEC

cat << EOSPEC > $PRERM
service nrpe stop
EOSPEC

cat << EOSPEC > $POSTRM
update-rc.d -f nrpe remove
rm -rf /var/run/op5
rm -rf $prefix/nrpe
rm -rf $prefix/etc/init.d/
rmdir --ignore-fail-on-non-empty $prefix/etc
EOSPEC

   chmod 755 $PRE $POSTINST $PRERM $POSTRM
   cd $SANDBOX/..
   dpkg-deb --build $(basename $SANDBOX)
   echo Wrote /var/tmp/${pkgname}-${nrpe_version}-${packagerel}${DISTVER#debian}.`uname -i`.deb
   mv $(basename $SANDBOX).deb /var/tmp/${pkgname}-${nrpe_version}-${packagerel}${DISTVER#debian}.`uname -i`.deb
}


#-----------------------------------------------
# Build Solaris IPS Package
#-----------------------------------------------

nrpe_ips_pkg () {
   typeset PKGROOT=/var/tmp/${pkgname}
   typeset PROTO=${PKGROOT}.proto
   mkdir $PKGROOT $PROTO 2>/dev/null

   # Install SMF manifest
   mkdir -p ${PROTO}/system/volatile/op5 ${PROTO}/lib/svc/manifest/site 2>/dev/null
   /usr/bin/chown $nrpe_user_solaris ${PROTO}/system/volatile/op5
   /usr/bin/chmod 755 ${PROTO}/system/volatile/op5
   /usr/bin/chgrp sys ${PROTO}/lib/svc/manifest/site
   /usr/bin/svcbundle -o ${PROTO}/lib/svc/manifest/site/nrpe.xml -s service-name=site/nrpe -s model=daemon -s start-method="$prefix/etc/init.d/nrpe start" -s stop-method="$prefix/etc/init.d/nrpe stop" -s refresh-method="$prefix/etc/init.d/nrpe restart"

   # Copy nrpe to proto
   rsync -aR $prefix $PROTO

   # Metadata
cat << EOP >> ${PKGROOT}/${pkgname}.mog
set name=pkg.fmri value=${pkgname}@${nrpe_version}-${packagerel}
set name=pkg.summary value=${pkgname}
set name=pkg.description value="${pkgdescription}"
set name=variant.arch value=\$(ARCH)
set name=info.classification value="org.opensolaris.category.2008:Applications/System Utilities"
group groupname=${nrpe_group_solaris} gid=${nrpe_gid}
user username=${nrpe_user_solaris} uid=${nrpe_uid} group=${nrpe_group_solaris} gcos-field=${nrpe_user_solaris} login-shell=/bin/false home-dir=${nrpe_home}
<transform dir path=opt$ -> drop>
<transform dir path=system$ -> drop>
<transform dir path=system/volatile$ -> drop>
<transform dir path=lib$ -> drop>
<transform dir path=lib/svc$ -> drop>
<transform dir path=lib/svc/manifest$ -> drop>
<transform dir path=lib/svc/manifest/site$ -> drop>
<transform file path=lib/svc/manifest/.*\.xml$ -> default restart_fmri svc:/system/manifest-import:default>
EOP

   # Generate
   cd $PROTO
   gfind . -type d -not -name .                                -printf "dir mode=%m owner=%u group=%g path=%p \n"     >> ${PKGROOT}/${pkgname}.p5m.gen
   gfind . -type f -not -name LICENSE -and -not -name MANIFEST -printf "file %p mode=%m owner=%u group=%g path=%p \n" >> ${PKGROOT}/${pkgname}.p5m.gen
   gfind . -type l -not -name LICENSE -and -not -name MANIFEST -printf "link path=%h/%f target=%l \n"                 >> ${PKGROOT}/${pkgname}.p5m.gen

   # Content
   pkgmogrify -DARCH=`uname -p` ${PKGROOT}/${pkgname}.p5m.gen ${PKGROOT}/${pkgname}.mog | pkgfmt > ${PKGROOT}/${pkgname}.p5m.mog
   pkgdepend generate -md ${PKGROOT}.proto ${PKGROOT}/${pkgname}.p5m.mog | pkgfmt > ${PKGROOT}/${pkgname}.p5m.dep
   pkgdepend resolve -m ${PKGROOT}/${pkgname}.p5m.dep

   mv $PKGROOT/${pkgname}.p5m.dep.res /var/tmp/
   echo "Note: if you have done any changes in the code please also do: pkglint -c /var/tmp/lint-cache -r http://pkg.oracle.com/solaris/release /var/tmp/${pkgname}.p5m.dep.res"
   echo "Publish to local repo: pkgsend publish -s http://localhost:82 -d $PROTO /var/tmp/${pkgname}.p5m.dep.res"
   echo "Wrote /var/tmp/${pkgname}.p5m.dep.res and Proto $PROTO"

   if [ -n "$PKGROOT" ] ; then
      rm -rf $PKGROOT
   fi
}

#-----------------------------------------------
# Build Solaris SVR4 Package
#-----------------------------------------------

nrpe_svr4_pkg () {
   typeset PKGROOT=/var/tmp/nrpe-pkgroot

   mkdir $PKGROOT
   cd /
   find $prefix | cpio -pmd ${PKGROOT}
   platform=`uname -p`
   find ${PKGROOT} | sed s,${PKGROOT},,| pkgproto > ${PKGROOT}/cm.proto

cat << EOP >> ${PKGROOT}/cm.proto
i checkinstall
i pkginfo
i preinstall
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
   solaris_preinstall > ${PKGROOT}/preinstall
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
         case `uname -r` in
            '5.11')
               ${what}_ips_pkg
            ;;
            *)
               ${what}_svr4_pkg
            ;;
         esac
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

if [ `uname -s` == 'SunOS' ]; then
  if [ $? != 0 ]; then
    getent passwd $nrpe_user_solaris > /dev/null
    echo "User $nrpe_user_solaris does not exist"
    exit
  fi
  if [ $? != 0 ]; then
    getent group $nrpe_group_solaris > /dev/null
    echo "Group $nrpe_group_solaris does not exist"
    exit
  fi
  PATH=/usr/sbin:/usr/bin:/usr/sfw/bin:/usr/ccs/bin:/opt/csw/bin
  export PATH
else
  getent passwd $nrpe_user > /dev/null
  if [ $? != 0 ]; then
    echo "User $nrpe_user does not exist"
    exit
  fi
  getent group $nrpe_group > /dev/null
  if [ $? != 0 ]; then
    echo "Group $nrpe_group does not exist"
    exit
  fi

fi

test -d "$prefix" || mkdir -p $prefix
test -d "$build" || mkdir -p $build

cd $build
get_source nrpe
. $scriptdir/nrpe-initscript.sh
build_nrpe
make_pkg nrpe


