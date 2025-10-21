#!/bin/bash

MOUNTPOINT={{ mountpoint }}

die() {
	echo "$*"
	exit 1
}

kinit -k -t /etc/krb5.keytab || die "failed to kinit"

set -o pipefail

for i in {1..5}; do
	users=$(ldapsearch -b "{{ nfscephfs_homes_groupdn }}" "(objectClass=groupOfNames)" 2>/dev/null | grep member | sed -E -e 's/.*uid=(.*)/\1/' | cut -d , -f 1)
	if [ "$?" = "0" ]; then
		break
	fi
	sleep 1
done

for user in $users ; do
	if [ ! -d "${MOUNTPOINT}/${user}" ] ; then
		install -d -o $user -g $user -m 700 ${MOUNTPOINT}/${user} || die "failed to create user $user home"
	fi
{% for link in nfscephfs_homes_links %}
	if [ ! -L "${MOUNTPOINT}/${user}/{{ link.dest }}" ] ; then
		src=$(echo "{{ link.src }}" | sed -e "s/{user}/${user}/g")
		ln -sf "${src}" "${MOUNTPOINT}/${user}/{{ link.dest }}"
		chown ${user}:${user} "${MOUNTPOINT}/${user}/{{ link.dest }}"
	fi
{% endfor %}
done

exit 0
