#!/bin/bash

MOUNTPOINT={{ mountpoint }}

die() {
	echo "$*"
	exit 1
}

kinit -k -t /etc/krb5.keytab || die "failed to kinit"

users=`ldapsearch "(objectClass=posixAccount)" uid 2>&1 | grep uid: | awk '{ print $2 };' | sort | uniq`
if [ "$?" != "0" ] ; then
	die "ldapsearch failed"
fi

for user in $users ; do
	if [ ! -d "${MOUNTPOINT}/${user}" ] ; then
		install -d -o $user -g $user -m 700 ${MOUNTPOINT}/${user} || die "failed to create user $user home"
		find /etc/skel/ -type f -exec install -o $user -g $user -vDm 755 {} ${MOUNTPOINT}/${user}/{} \; || die "failed to create user $user skeleton"
	fi
done

exit 0
