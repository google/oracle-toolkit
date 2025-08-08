# Troubleshooting guide

Running into an error? Here are a few sample error messages and solutions.

## Table of Contents:

<!-- TOC depthFrom:1 depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 -->

- [Troubleshooting guide](#troubleshooting-guide)
  - [Table of Contents:](#table-of-contents)
  - [Missing `dg_name` in `cluster_config.json` file](#missing-dgname-in-clusterconfigjson-file)
  - [Invalid diskgroup name in `asm_disk_config.json`](#invalid-diskgroup-name-in-asmdiskconfigjson)
  - [Invalid network interface name in `cluster_config.json`](#invalid-network-interface-name-in-clusterconfigjson)
  - [ASM candidate disks having a header containing old DG data](#asm-candidate-disks-having-a-header-containing-old-dg-data)
  - [Existing ORACLE_HOME](#existing-oraclehome)
  - [First time connection errors to target host from cloud VM](#first-time-connection-errors-to-target-host-from-cloud-vm)
  - [Failing gcscopy step](#failing-gcscopy-step)
  - [Time offset between RAC cluster nodes](#time-offset-between-rac-cluster-nodes)
  - [Pass extra flags into ansible via `install-oracle.sh`:](#pass-extra-flags-into-ansible-via-install-oraclesh)

<!-- /TOC -->

## Missing `dg_name` in `cluster_config.json` file

- Error:

```
fatal: [racnode1.orcl]: FAILED! => {"msg": "'ansible.vars.hostvars.HostVarsVars object' has no attribute 'dg_name'"}
```

- Possible place to check will be `oracle-toolkit/cluster_config.json`:

```json
[
  {
    "scan_name": "dec-test-scan-cluster",
    "scan_port": "1521",
    "cluster_name": "dec-test-cluster",
    "cluster_domain": "dec-test-home",
    "public_net": "dec-test-public_interface",
    "private_net": "dec-test-private",
    "scan_ip1": "172.16.30.20",
    "scan_ip2": "172.16.30.21",
    "scan_ip3": "172.16.30.22",
    "dg_name": "DATA",<======================================== this parameter was missing in this file's this line
    "nodes": [
      {  "node_name": "racnode1.orcl",
         "host_ip": "172.16.30.1",
         "vip_name": "racnode1-vip.orcl",
         "vip_ip": "172.16.30.11"
      },
      {  "node_name": "racnode2.orcl",
         "host_ip": "172.16.30.2",
         "vip_name": "racnode2-vip.orcl",
         "vip_ip": "172.16.30.12"
      }
    ]
  }
]
```

## Invalid diskgroup name in `asm_disk_config.json`

- For following error:

```
TASK [rac-gi-setup : rac-gi-install | Get symlinks for devices] ************************************************************************************************
task path: /home/janedoe/git-clone-holder/oracle-toolkit/roles/rac-gi-setup/tasks/rac-gi-install.yml:127
File lookup using /home/janedoe/git-clone-holder/oracle-toolkit/asm_disk_config.json as file
fatal: [racnode1.orcl]: FAILED! => {
    "msg": "Invalid data passed to 'loop', it requires a list, got this instead: . Hint: If you passed a list/dict of just one element, try adding wantlist=True to your lookup invocation or use q/query instead of lookup."
}
```

- Check that: `dg_name=DATA` points to a valid diskgroup name.
- Rationale: the following expression in the [source code](https://github.com/google/oracle-toolkit/blob/master/roles/rac-gi-setup/tasks/rac-gi-install.yml#L133):

```
"{{ asm_disks | json_query('[?diskgroup==`' + hostvars[groups['dbasm'].0]['dg_name'] + '`].disks[*].blk_device') | list | join() }}"
```

... translates to something similar to the following:

```
"{{ asm_disks | json_query('[?diskgroup==`'DATA'`].disks[*].blk_device') | list | join() }}"
```

where the 'DATA' is the incorrect DG name supplied in `cluster_config.json` file's `"dg_name": "DATA"`

## Invalid network interface name in `cluster_config.json`

- Error:

```
TASK [rac-gi-setup : rac-gi-install | Create GI response file] *************************************************************************************************
fatal: [racnode1.orcl]: FAILED! => {"changed": false, "msg": "AnsibleUndefinedVariable: 'dict object' has no attribute u'dec-test-public_interface'"}
```

- Fix:
  Ensure that the entries for the n/w interfaces are correctly defined in `cluster_config.json`:

```json
[
  {
    "scan_name": "dec-test-scan-cluster",
    "scan_port": "1521",
    "cluster_name": "dec-test-cluster",
    "cluster_domain": "dec-test-home",
    "public_net": "dec-test-public_interface",   <==================== this and
    "private_net": "dec-test-private",           <==================== this should reflect the actual interfaces on the host
    "scan_ip1": "172.16.30.20",
    "scan_ip2": "172.16.30.21",
    "scan_ip3": "172.16.30.22",
    "dg_name": "DATA",
    "nodes": [
      {
        "node_name": "racnode1.orcl",
        "host_ip": "172.16.30.1",
        "vip_name": "racnode1-vip.orcl",
        "vip_ip": "172.16.30.11"
      },
      {
        "node_name": "racnode2.orcl",
        "host_ip": "172.16.30.2",
        "vip_name": "racnode2-vip.orcl",
        "vip_ip": "172.16.30.12"
      }
    ]
  }
]
```

The interface to be used for `public_net` is the interface that carries the network address for the `172.16.30.0` (in the example above) network.

- Example:

```bash
[root@racnode1 ~]# ifconfig -a bond0.111
bond0.111: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.16.30.1  netmask 255.255.255.0  broadcast 172.16.30.255
        inet6 fe80::3680:dff:fe59:7f1e  prefixlen 64  scopeid 0x20<link>
        ether 34:80:0d:59:7f:1e  txqueuelen 1000  (Ethernet)
        RX packets 1277524  bytes 13573540106 (12.6 GiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 1227353  bytes 621025389 (592.2 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```

The interface to be used for `private_net` is the one that carries the IP for the private interconnect which will be used exclusively for RAC traffic, for example `192.168.3.1` (in the example below):

```
[root@racnode1 ~]# ifconfig -a bond1.112
bond1.112: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.3.1  netmask 255.255.255.0  broadcast 192.168.3.255
        inet6 fe80::3680:dff:fe59:7f1f  prefixlen 64  scopeid 0x20<link>
        ether 34:80:0d:59:7f:1f  txqueuelen 1000  (Ethernet)
        RX packets 5664  bytes 260540 (254.4 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 5670  bytes 238460 (232.8 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```

## ASM candidate disks having a header containing old DG data

- Error:

```
SEVERE:  [Jan 20, 2021 7:42:09 AM] [FATAL] [INS-30530] Following specified disks have invalid header status:
[/dev/asmdisks/DATA_7539397476, /dev/asmdisks/DATA_7539397477, /dev/asmdisks/DATA_7539397478, /dev/asmdisks/DATA_7539397531]
```

This means that the disks that are listed in the `asm_disk_config.json` file carry existing ASM disk metadata, possibly from a prior failed installation attempt. Ideally disk headers input in the json file should be empty. Care should be taken to ensure that disk corruption or loss of data in a disk is not introduced.

- Fix: Possibly the last time `cleanup-oracle.sh` was run, it didn't go through till the end, as it zeroes out headers cleanly for you.

Following command can be used to check if the headers contain ASM metadata:

```bash
for i in /dev/asmdisks/DATA_7539397476, /dev/asmdisks/DATA_7539397477, /dev/asmdisks/DATA_7539397478, /dev/asmdisks/DATA_7539397531 ; \
do echo "checking disk $i";dd if=$i bs=128 count=1 | od -a ;echo; \
done
```

You will see something like this which shows that the disk headers are not empty and it has remnant DG information:

```
checking disk /dev/asmdisks/DATA_7539397476
1+0 records in
1+0 records out
128 bytes (128 B) copied, 0.000275708 s, 464 kB/s
0000000 soh stx soh soh nul nul nul nul nul nul nul nul   L   .  us can
0000020 nul nul nul nul nul nul nul nul nul nul nul nul nul nul nul nul
0000040   O   R   C   L   D   I   S   K nul nul nul nul nul nul nul nul
0000060 nul nul nul nul nul nul nul nul nul nul nul nul nul nul nul nul
0000100 nul nul etx dc3 nul nul soh etx   D   A   T   A   _   0   0   0
0000120   0 nul nul nul nul nul nul nul nul nul nul nul nul nul nul nul
0000140 nul nul nul nul nul nul nul nul   D   A   T   A nul nul nul nul
0000160 nul nul nul nul nul nul nul nul nul nul nul nul nul nul nul nul
0000200
```

- For cleanup, the `cleanup-oracle.sh` can be run again, or the following snippet if specific disks (that were listed in the ansible error messages) need to be cleaned out quickly to unblock the install quickly as:

```
 #First backup:
dd if=/dev/asmdisks/DATA_7539397476 of=dev_asmdisks_DATA_7539397476.txt bs=1048576 count=100

 #Then cleanup:
for i in /dev/asmdisks/DATA_7539397476 /dev/asmdisks/DATA_7539397477 /dev/asmdisks/DATA_7539397478 /dev/asmdisks/DATA_7539397531; \
do dd if=/dev/zero of=$i bs=1048576 count=100 ;echo Done blowing up header for disk $i; done
```

## Existing ORACLE_HOME

- Error:

```
"Launching Oracle Grid Infrastructure Setup Wizard...", "", "[WARNING] [INS-40109] The specified Oracle Base location is not empty on this server.", "   ACTION: Specify an empty location for Oracle Base.", "[WARNING] [INS-32047] The location (/u01/app/oraInventory) specified for the central inventory is not empty.", "   ACTION: It is recommended to provide an empty location for the inventory.", "[FATAL] [INS-13019] Some mandatory prerequisites are not met. These prerequisites cannot be ignored."
```

- Fix:
  Rerun `cleanup-oracle.sh` and ensure it finished successfully (it can fail at the part where it tries to umount the u01 mountpoint and exits at that point)

## First time connection errors to target host from cloud VM

- Make sure you have a user and appropriate authentication set up on the target host. By default it uses your own OS user id but can use `--instance-ssh-user` to use a different-user, and `--instance-ssh-key` to specify a SSH private key file to use.
- You will need to generate ssh public and private keys, store the public key under the home directory of the `ansible` OS user in the BM host and the private keys under their OS account in cloud VM.
- Sample connectivity error may be of the form similar to:

```
TASK [Test connectivity to target instance via ping] ***********************************************************************************************************
fatal: [racnode1.orcl]: UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host via ssh: Warning: Permanently added '172.16.30.1' (ECDSA) to the list of known hosts.\r\nno such identity: /home/janedoe/.ssh/id_rsa: No such file or directory\r\nPermission denied (publickey,gssapi-keyex,gssapi-with-mic,password).", "unreachable": true}
fatal: [racnode2.orcl]: UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host via ssh: Warning: Permanently added '172.16.30.2' (ECDSA) to the list of known hosts.\r\nno such identity: /home/janedoe/.ssh/id_rsa: No such file or directory\r\nPermission denied (publickey,gssapi-keyex,gssapi-with-mic,password).", "unreachable": true}
```

- Fix:
  Reason for the error is as follows:
- By, `--instance-ssh-user ansible --instance-ssh-key ~/.ssh/id_rsa` typically provided in the command line to `install-oracle.sh`, we are asking Ansible to connect:
  - from the current jump host/VM as the user (say) `janedoe`
  - to the Google Cloud server host as the OS user called `ansible`
  - using the SSH key file in the jump host under the current users home directory's: `~/.ssh/id_rsa`

As noted in the [oracle-toolkit documentation](user-guide.md#command-quick-reference-for-rac-deployments):

we want to ensure we can connect to the backend nodes with ssh and sudo to the account we want ansible to escalate to:

```bash
ssh ${INSTANCE_SSH_USER:-`whoami`}@${INSTANCE_IP_ADDR_NODE_1} sudo -u root hostname
ssh ${INSTANCE_SSH_USER:-`whoami`}@${INSTANCE_IP_ADDR_NODE_2} sudo -u root hostname
```

Some references for enabling this can be found [here](https://docs.ansible.com/ansible/latest/reference_appendices/faq.html#how-do-i-configure-a-jump-host-to-access-servers-that-i-have-no-direct-access-to) and [here](https://blog.scottlowe.org/2015/12/24/running-ansible-through-ssh-bastion-host/)

Summarizing into handy commands from the references, to enable password-less ssh connectivity and to set up that connection manually, following actions may be performed:

- Generate a public/private key pair:

```bash
[janedoe@control-host-cloudvm .ssh]$ which ssh-keygen
/usr/bin/ssh-keygen

[janedoe@control-host-cloudvm .ssh]$ ssh-keygen -t rsa -b 4096
Generating public/private rsa key pair.
Enter file in which to save the key (/home/janedoe/.ssh/id_rsa):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /home/janedoe/.ssh/id_rsa.
Your public key has been saved in /home/janedoe/.ssh/id_rsa.pub.
The key fingerprint is:
SHA256:<string> janedoe@control-host-cloudvm
The key's randomart image is:
+---[RSA 4096]----+
|.                |
|.. o  o .        |
| .+..* +         |
|..........some   |
| random stuff    |
|ascii characters |
|   = + +o. o .   |
|o + O + o   .    |
|.=.+ *o. .       |
+----[SHA256]-----+

[janedoe@control-host-cloudvm .ssh]$ ls -alrt
total 20
-r--------. 1 janedoe janedoe  419 Nov 20 20:52 id_ed25519
-r--------. 1 janedoe janedoe  105 Nov 20 20:52 id_ed25519.pub
-rwxr-xr-x. 1 janedoe janedoe  578 Dec 15 18:52 known_hosts
drwx------. 9 janedoe janedoe  237 Dec 15 19:06 ..
-rw-r--r--. 1 janedoe janedoe  751 Dec 16 15:39 id_rsa.pub <======== Transfer to the database server under the Ansible user's home directory: ${home}/.ssh/authorized_keys
-rw-------. 1 janedoe janedoe 3243 Dec 16 15:39 id_rsa.  <======= Should be protected
drwxrwxr-x. 2 janedoe janedoe   97 Dec 16 15:39 .
```

- and post the public key on to the `ansible` users HOME/.ssh/authorized_keys file using one of 2 options:
  - if you know the password of the ansible user:

```bash
[janedoe@control-host-cloudvm .ssh]$ ssh-copy-id ansible@172.16.30.1
```

- if that's unknown, then simply copy the contents of the public key and append it into the `authorized_keys` file:

```bash
[ansible@racnode1 .ssh]$ cat >> authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC<more crypto> janedoe@control-host-cloudvm
```

## Failing gcscopy step

- The following failure may be encountered during running `gcscopy.yml` playbook:

```bash
failed: [racnode1.orcl] (item={u'files': [u'V982068-01.zip'], u'version': u'19.3.0.0.0', u'name': u'19c_gi', u'sha256sum': [u'D668002664D9399CF61EB03C0D1E3687121FC890B1DDD50B35DCBE13C5307D2E']}) => {"ansible_loop_var": "item", "changed": false, "item": {"files": ["V982068-01.zip"], "name": "19c_gi", "sha256sum": ["D668002664D9399CF61EB03C0D1E3687121FC890B1DDD50B35DCBE13C5307D2E"], "version": "19.3.0.0.0"}, "module_stderr": "sudo: a password is required\n", "module_stdout": "", "msg": "MODULE FAILURE\nSee stdout/stderr for the exact error", "rc": 1}
```

- Fix:
  - This means that the current OS user executing the toolkit from the cloud VM is lacking sudo privileges
  - Add the OS user in the cloud VM to the OS user group wheel that has appropriate sudo privileges.

## Time offset between RAC cluster nodes

- Ansible error:

```bash
"[FATAL] [INS-13019] Some mandatory prerequisites are not met. These prerequisites cannot be ignored.",
"   CAUSE: The following prerequisites are mandatory and cannot be ignored: ", "- Time offset between nodes", "
```

- Fix:

  - RAC nodes need an NTP server to synchronize time.
  - It is recommended to have a time server
  - In the case that there are no existing NTP servers, it is recommended to use the time.google.com, if the host has internet access.
  - The following flag may be used with `install-oracle.sh` to provide the name of the NTP server that needs to be used:`--ntp-pref`

  - The above will mimic following manual fix:

```
[root@control-host-cloudvm ~]# #Add this longer line in cloud VM host:
[root@control-host-cloudvm ~]# diff  /etc/ntp.conf /etc/ntp.conf.bk.jc.01.21.2021
62c62
< restrict 192.16.0.0 mask 255.255.0.0 nomodify notrap
---
> restrict 192.16.0.0 mask 255.255.0.0
```

```
[root@control-host-cloudvm ~]# #restart ntpd:
[root@control-host-cloudvm ~]# systemctl restart ntpd
```

```
[root@racnode1 ~]# #Add this in both RAC nodes to instruct the OS to reach out to the VM jump host as a NTP server:
[root@racnode1 ~]# diff /etc/ntp.conf /etc/ntp.conf.bk.jc.01.21.2021
21d20
< server 10.210.1.7 prefer
```

After the fix:

```
[janedoe@control-host-cloudvm ~]$ date ; ssh 172.16.30.1 date ; ssh 172.16.30.2 date
Thu Jan 21 22:40:29 UTC 2021
Thu Jan 21 22:40:31 UTC 2021
Thu Jan 21 22:40:34 UTC 2021
```

## Pass extra flags into ansible via `install-oracle.sh`

- There may arise situations where we may want to pass extra flags to ansible and this may be done as follows (taking an example of passing the debug flag):

```bash
 ~/git-clone-holder/oracle-toolkit [master L|✚ 3…2]
23:17 $ ./install-oracle.sh \
--ora-swlib-bucket gs://bmaas-testing-oracle-software \
--instance-ssh-user ansible \
--instance-ssh-key ~/.ssh/id_rsa \
--backup-dest /u01/backups \
--ora-swlib-path /u01/oracle_install \
--ora-version 19 \
--ora-swlib-type gcs \
--ora-asm-disks asm_disk_config.json \
--ora-data-mounts data_mounts_config.json \
--cluster-type RAC \
--cluster-config cluster_config.json \
--ora-data-destination DATA \
--ora-reco-destination RECO \
--ora-db-name orcl \
--ora-db-container false >> ~/git-clone-holder/oracle-toolkit/logs/sydney-1.out \
-- -vvvv 2>&1   <-----------------------------------------------------------------------------
```

- `-- -vvvv` will be sent by the wrapper install-oracle.sh into Ansible as:

```bash
Ansible params: -vvvv
Found Ansible at /usr/bin/ansible-playbook

Running Ansible playbook: /usr/bin/ansible-playbook -i ./inventory_files/inventory_orcl_RAC  -vvvv check-instance.yml
```

- Debug tip: if you are testing a **specific functionality** of a playbook by extracting snippets of the playbook into your local ansible setup, don't turn off the `gather_facts` (by inadvertently having the setting `gather_facts: False` in your test playbook).

## Conditional check failure on AnsibleUnsafeText

- A playbook may report a missing attribute on an AnsibleUnsafeText object:

```
  TASK [host-storage : Partition Oracle user mount devices] **************************************************************************************************************************************************************************************************************************************************************
  fatal: [racnode1.orcl]: FAILED! => {"msg": "The conditional check ''mapper' not in item.blk_device' failed. The error was: error while evaluating conditional ('mapper' not in item.blk_device): 'ansible.utils.unsafe_proxy.AnsibleUnsafeText object' has no attribute 'blk_device'\n\nThe error appears to be in '/home/mfielding/git/opatch/roles/host-storage/tasks/main.yml': line 16, column 3, but may\nbe elsewhere in the file depending on the exact syntax problem.\n\nThe offending line appears to be:\n\n---\n- name: Partition Oracle user mount devices\n  ^ here\n"}
```

- Fix:
  - Ansible is not able to parse an input JSON file. Identify the input file involved, and validate. Is there a blank line, perhaps?
