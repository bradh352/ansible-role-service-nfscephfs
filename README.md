# NFS-Ganesha using CephFS Ansible role

Author: Brad House<br/>
License: MIT<br/>
Original Repository: https://github.com/bradh352/ansible-role-service-nfscephfs

## Overview

This role exports a CephFS subdirectory over NFS.  It is built with the
assumption that FreeIPA is in use, deployed by using the
[ansible-role-service-freeipa](https://github.com/bradh352/ansible-role-service-nfscephfs)
playbook (svc_admin keytab on system and service_accounts group are the
dependencies, which could be removed if needed).

The NFS server deployed by this role will enforce Kerberos authentication
with the option of encryption and signing.

It also requires a dedicated Ceph Pool for it to store its Rados Recovery
Backend data.

## Required setup done outside of this role.

1. If not using the root of the filesystem, create the subdirectory that will
   be used for thise mount point.  It is recommended to use a subdirectory
   since creating additional CephFS mounts requires additional MDS servers.
   These steps should be performed on a ceph host with a ceph configuration and
   key capable of mounting the filesystem.
```
mkdir -p /mnt/cephfs
mount -t ceph admin@.{{ cephfs_name }}=/ /mnt/cephfs
mkdir /mnt/cephfs/{{ subdirectory }}
umount /mnt/cephfs
```
  * replace `{{ cephfs_name }}` and `{{ subdirectory }}` as appropriate
2. Generate a Ceph pool to use for the Rados Recovery KV store used by NFS
   Ganesha, dedicated for this purpose:
```
ceph osd pool create {{ nfs-ganesha-pool }}
ceph osd pool application enable {{ nfs-ganesha-pool }} rbd
```
  * replace `{{ nfs-ganesha-pool }}` as appropriate
3. Create a user/key as necessary to access the created pool and cephfs subdirectory
```
ceph auth get-or-create client.{{ username }} mon 'allow r' osd 'allow rw pool={{ nfs-ganesha-pool }}, allow rw tag cephfs data={{ cephfs_name  }}' mds 'allow rw fsname={{ cephfs_name }} path=/{{ subdirectory }}'
```
  * replace `{{ username }}`, `{{ nfs-ganesha-pool }}`, `{{ cephfs_name }}`, and `{{ subdirectory }}` as appropriate
  * Save the output key from this command as it will be used as an input variable.

## Variables

- `nfscephfs_username`: Username to authenticate as to cephfs
- `nfscephfs_key`: Key associated with username to authenticate as.
- `nfscephfs_subdirectory`: Subdirectory within cephfs to mount
- `nfscephfs_fsname`: Name of CephFS filesystem
- `nfscephfs_pool`: Pool name to use for Rados Recovery KV
- `nfscephfs_fsid`: UUID for ceph cluster
- `nfscephfs_mons`: List of Monitor IP addresses
- `nfscephfs_homes`: Optional.  A subdirectory name. If set, it creates the
  specified subdirectory in the cephfs tree to use for user homes.  It also sets
  up an automated home creation script that will pre-create home directories for
  new users belonging to the `ipausers` group.
- `nfscephfs_hostname`: Optional.  If not specified, will use `inventory_hostname`.
  Used to generate a host+service keytab when clients are connecting to a virtual
  ip or load balancer.

# minimal ceph.conf for 82136e90-c2cb-434a-9c3c-4ee61c6d72b7

## Ansible Groups used by this role
- `freeipa_servers`.  Will log into the server to:
  - Will log in to generate service keytab.
  - If using `nfscephfs_homes`, will also generate a service keytab for
    user enumeration.
