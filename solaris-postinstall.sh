solaris_preinstall () {
cat << EOT
#!/bin/sh
/usr/bin/getent group $nrpe_group_solaris > /dev/null || /usr/sbin/groupadd -o -g $nrpe_gid $nrpe_group_solaris
/usr/bin/getent passwd $nrpe_user_solaris > /dev/null || /usr/sbin/useradd -o -u $nrpe_uid -g $nrpe_gid -d $nrpe_home $nrpe_user_solaris
EOT
}

solaris_postinstall () {
if [ `uname -r` = 5.11 ] ; then

cat << EOT
#!/bin/sh
mkdir -p /var/run/op5
/usr/bin/chown $nrpe_user_solaris /var/run/op5
/usr/bin/chmod 755 /var/run/op5
/usr/bin/svcbundle -i -s service-name=site/nrpe -s model=daemon -s start-method="$prefix/etc/init.d/nrpe start" -s stop-method="$prefix/etc/init.d/nrpe stop" -s refresh-method="$prefix/etc/init.d/nrpe restart"
EOT

elif [ `uname -r` = 5.10 ] ; then

cat << EOT
#!/bin/sh
mkdir -p /var/run/op5
/usr/bin/chown $nrpe_user_solaris /var/run/op5
/usr/bin/chmod 755 /var/run/op5

cat << EOXML > /var/svc/manifest/site/nrpe.xml
<?xml version="1.0"?>
<!DOCTYPE service_bundle SYSTEM "/usr/share/lib/xml/dtd/service_bundle.dtd.1">
<!--
        Copyright 2004 Sun Microsystems, Inc.  All rights reserved.
        Use is subject to license terms.

        ident   "@(#)ssh.xml    1.7     04/12/09 SMI"

        NOTE:  This service manifest is not editable; its contents will
        be overwritten by package or patch operations, including
        operating system upgrade.  Make customizations in a different
        file.

        Modified ssh manifest for the Op5 nrpe daemon - by qrausva
-->

<service_bundle type='manifest' name='EIS-op5nrpe:nrpe'>

<service
        name='site/nrpe'
        type='service'
        version='1'>

        <create_default_instance enabled='false' />

        <single_instance />

        <dependency name='fs-local'
                grouping='require_all'
                restart_on='none'
                type='service'>
                <service_fmri
                        value='svc:/system/filesystem/local' />
        </dependency>

        <exec_method
                type='method'
                name='start'
                exec='$prefix/etc/init.d/nrpe start'
                timeout_seconds='60'/>

        <exec_method
                type='method'
                name='stop'
                exec='$prefix/etc/init.d/nrpe stop'
                timeout_seconds='60' />

        <exec_method
                type='method'
                name='restart'
                exec='$prefix/etc/init.d/nrpe restart'
                timeout_seconds='60' />

        <property_group name='startd'
                type='framework'>
                <!-- sub-process core dumps shouldn't restart session -->
                <propval name='ignore_error'
                    type='astring' value='core,signal' />
        </property_group>

        <stability value='Unstable' />

        <template>
                <common_name>
                        <loctext xml:lang='C'>
                        Nrpe daemon
                        </loctext>
                </common_name>
        </template>

</service>

</service_bundle>
EOXML
/usr/bin/svcs -a | grep -w site/nrpe >/dev/null 2>&1
if [ \$? = 1 ]
then

        if [ -f /var/svc/manifest/site/nrpe.xml ]
        then
                echo "Importing manifest for nrpe."
                /usr/sbin/svccfg import /var/svc/manifest/site/nrpe.xml
                sleep 2
                echo "Starting nrpe"
                /usr/sbin/svcadm enable nrpe
        else
                echo "Could not find manifest file for nrpe.xml"
        fi
fi
exit 0

EOT
elif [ `uname -r` = 5.9 -o `uname -r` = 5.8 ] ; then

cat << EOT2
ln -sf $prefix/etc/init.d/nrpe /etc/init.d/nrpe
ln -sf /etc/init.d/nrpe /etc/rc3.d/S90nrpe
/usr/bin/mkdir -p /var/run/op5
/usr/bin/chown $nrpe_user_solaris /var/run/op5
/usr/bin/chmod 755 /var/run/op5
/etc/init.d/nrpe start
EOT2

else
  echo "I do not know about solaris "`uname -r`
  exit 1
fi 
}

solaris_preremove () {
if [ `uname -r` = 5.11 ] ; then

cat << EOT
#!/bin/sh
/usr/bin/svcs -a | grep -w site/nrpe >/dev/null 2>&1
if [ \$? = 0 ]; then
        /usr/sbin/svcadm disable -s site/nrpe 2>&1
        echo "Removing Manifest for nrpe."
        rm -f /lib/svc/manifest/site/nrpe.xml
        /usr/sbin/svcadm restart manifest-import
fi
sleep 4
rm -rf /var/run/op5
exit 0
EOT

elif [ `uname -r` = 5.10 ] ; then

cat << EOT
#!/bin/sh
/usr/bin/svcs -a | grep -w site/nrpe >/dev/null 2>&1
if [ \$? = 0 ]; then
        /usr/sbin/svcadm disable -s site/nrpe 2>&1
        echo "Removing Manifest for nrpe."
        /usr/sbin/svccfg delete site/nrpe
fi
sleep 4
rm -rf /var/run/op5
exit 0
EOT

elif [ `uname -r` = 5.9 -o `uname -r` = 5.8 ] ; then

cat << EOT2
#!/bin/sh
echo "Stoppng site/nrpe"
/etc/init.d/nrpe stop
sleep 4
/usr/bin/rm -rf /etc/init.d/nrpe /etc/rc3.d/S90nrpe
rm -rf /var/run/op5
EOT2

else
  echo "I do not know about solaris "`uname -r`
  exit 1
fi 
}
