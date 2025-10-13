# NFS-Ganesha using CephFS Ansible role

Author: Brad House<br/>
License: MIT<br/>
Original Repository: https://github.com/bradh352/ansible-role-service-nfscephfs

## Overview

This role exports a CephFS subdirectory over NFS.  It is built with the
assumption that FreeIPA is in use, deployed by using the
[ansible-role-service-freeipa](https://github.com/bradh352/ansible-role-service-freeipa)
playbook (svc_admin keytab on system and service_accounts group are the
dependencies, which could be removed if needed).

The NFS server deployed by this role will enforce Kerberos authentication
with the option of encryption and signing.

It also requires a dedicated Ceph Pool for it to store its Rados Recovery
Backend data.

## Variables

- `nfscephfs_cephfs_username`: Username to authenticate as to cephfs
- `nfscephfs_cephfs_key`: Key associated with username to authenticate as.
- `nfscephfs_cephfs_subdirectory`: Subdirectory within cephfs to mount
- `nfscephfs_cephfs_name`: Name of CephFS filesystem
- `nfscephfs_rbd_pool`: Dedicated pool name to use for Rados Recovery KV
- `nfscephfs_fsid`: UUID for ceph cluster
- `nfscephfs_mons`: List of Monitor IP addresses
- `nfscephfs_homes`: Optional.  A subdirectory name. If set, it creates the
  specified subdirectory in the cephfs tree to use for user homes.  It also sets
  up an automated home creation script that will pre-create home directories for
  new users belonging to the `ipausers` group.
- `nfscephfs_cron`: The cron schedule to run the create homes script when
  `nfscephfs_homes` is defined.  Defaults to `15 * * * *`.  Should be different
  for each server to prevent parallel execution.

- `nfscephfs_hostname`: Optional.  If not specified, will use `inventory_hostname`.
  Used to generate a host+service keytab when clients are connecting to a virtual
  ip or load balancer.

## Ansible Groups used by this role
- `freeipa_servers`.  Will log into the server to:
  - generate service keytab.

## Required setup done outside of this role.

1. If not using the root of the filesystem, create the subdirectory that will
   be used for thise mount point.  It is recommended to use a subdirectory
   since creating additional CephFS mounts requires additional MDS servers.
   These steps should be performed on a ceph host with a ceph configuration and
   key capable of mounting the filesystem.
```
mkdir -p /mnt/cephfs
mount -t ceph admin@.{{ nfscephfs_cephfs_name }}=/ /mnt/cephfs
mkdir /mnt/cephfs/{{ nfscephfs_cephfs_subdirectory }}
umount /mnt/cephfs
```
  * replace `{{ nfscephfs_cephfs_name }}` and `{{ nfscephfs_cephfs_subdirectory }}` as appropriate
2. Generate a Ceph pool to use for the Rados Recovery KV store used by NFS
   Ganesha, dedicated for this purpose:
```
ceph osd pool create {{ nfscephfs_rbd_pool }}
ceph osd pool application enable {{ nfscephfs_rbd_pool }} rbd
```
  * replace `{{ nfscephfs_rbd_pool }}` as appropriate
3. Create a user/key as necessary to access the created pool and cephfs subdirectory
```
ceph auth get-or-create client.{{ nfscephfs_cephfs_username }} mon 'allow r' osd 'allow rw pool={{ nfscephfs_rbd_pool }}, allow rw tag cephfs data={{ nfscephfs_cephfs_name  }}' mds 'allow rw fsname={{ nfscephfs_cephfs_name }} path=/{{ nfscephfs_cephfs_subdirectory }}'
```
  * replace `{{ nfscephfs_cephfs_username }}`, `{{ nfscephfs_rbd_pool }}`, `{{ nfscephfs_cephfs_name }}`, and `{{ nfscephfs_cephfs_subdirectory }}` as appropriate
  * Save the output key from this command as it will be used as an input variable.

