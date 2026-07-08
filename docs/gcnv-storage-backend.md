# GCNV Storage Backend

Google Cloud NetApp Volumes (GCNV) iSCSI storage backs Oracle's `u01`
(binaries) and DATA/RECO storage. Enable it with one Terraform variable:

```hcl
storage_backend = "gcnv"
```

Deployment is a **single `terraform apply`** — the same workflow and the
same toolkit entrypoints (`install-oracle.sh`, `prep-host.yml`) you'd
otherwise use, with no separate provisioning step and no provisioning
control node.

## What GCNV backs

* **`u01` (Oracle binaries) and DATA/RECO** (ASM disk groups, or `/u02`,
  `/u03` in FS mode) are served by GCNV iSCSI LUNs.
* **Boot disk and swap always stay on standard Compute Engine disk**,
  regardless of this setting — the OS must already be up to reach an iSCSI
  LUN, and swapping over the network is unsafe.
* **No restriction on Oracle version.** For `ora_disk_mgmt`, **`ASMUDEV`**
  is the supported mode.

## How to enable

* **Base setup:** follow [`docs/terraform.md`](terraform.md) for the
  service accounts, state bucket, and toolkit source bucket.
* **IAM:** the deployer's `roles/compute.networkAdmin` and
  `roles/netapp.admin` roles are already covered in
  [deployer principal permissions](terraform.md#5-deployer-principal-permissions).
  GCNV adds one more: grant `roles/netapp.admin` to
  **`control_node_service_account`** as well, so the `gcnv-provision`
  Ansible role can update each Host Group with the VM's real IQN during
  host prep.
  * *If missed:* `terraform apply` still succeeds, but the Host Group is
    left on its placeholder IQN and the DB VM never sees its
    `/dev/mapper/*` devices.
* **Variables:** create `terraform/terraform.tfvars` — start from
  `terraform/ora121-gcnv.template` or `terraform/ora26-gcnv.template` for a
  working example — and set:

  ```hcl
  storage_backend = "gcnv"
  ora_disk_mgmt   = "ASMUDEV"  # not ASMLIB — see Known limitations below
  ```

* **Deploy:**

  ```bash
  cd terraform && terraform apply
  terraform output control_node_log_url  # follow the Ansible logs
  ```

## Verifying GCNV provisioning

* **Check the OS/iSCSI layer:**

  ```bash
  sudo iscsiadm -m session
  ls -l /dev/mapper/<DEPLOY>_oracle_home /dev/mapper/<DEPLOY>_data /dev/mapper/<DEPLOY>_reco
  ```

  * *Success indicator:* one or more iSCSI sessions listed, and all three
    `/dev/mapper/<DEPLOY>_*` aliases exist and resolve (not dangling).

* **Check the Host Group directly:**

  ```bash
  gcloud netapp host-groups describe <host-group> --location=<REGION>
  ```

  * *Success indicator:* `hosts` shows the VM's real initiator IQN, not
    `iqn.1994-05.com.redhat:dummy`.

## Failure / recovery

* If `gcnv-provision` fails, or a VM is replaced, re-run that role to
  re-discover the IQN and reconcile the Host Group, then re-run
  `iscsi-multipath`:

  ```bash
  ansible-playbook -i <inventory> prep-host.yml --tags gcnv-provision,iscsi-multipath
  ```

## Troubleshooting (common)

* **Host Group still shows the placeholder IQN**
  (`iqn.1994-05.com.redhat:dummy`)
  → `gcnv-provision` didn't run or failed. Check that the control node
  service account has `roles/netapp.admin`, then re-run the fix from
  [Failure / recovery](#failure--recovery) above.

* **No iSCSI sessions** (`iscsiadm -m session` is empty)
  → The LUN isn't authorized yet (see previous point), or the VM can't
  reach the GCNV pool's network path — check PSA peering / firewall rules
  between the VM's subnet and the pool.

* **`/dev/mapper/<DEPLOY>_*` aliases missing** despite active iSCSI sessions
  → `iscsi-multipath` hasn't run yet, or ran before authorization
  completed — re-run `prep-host.yml --tags gcnv-provision,iscsi-multipath`.

* **ASM doesn't discover the DATA/RECO disks** despite `/dev/mapper` aliases
  existing
  → With `ASMUDEV`, ASM discovers disks via `/dev/asmdisks/*` udev
  symlinks, not `/dev/mapper/*` directly. Check that the udev rule created
  the symlink for each mapper device before assuming ASM itself is
  misconfigured.

## Known limitations

* Only `ora_disk_mgmt = ASMUDEV` is supported with GCNV today.
* Supports single-instance and Data Guard primary/standby topologies only —
  no RAC support (no shared LUNs across nodes; each node gets its own
  private Host Group and LUN set).
* Single zonal Flex pool in `zone1`/`gcnv_pool_location` (dual-zone
  per-DG-node pools are a future enhancement).

## Behind the scenes: how it works

* A GCNV Host Group must authorize a host's initiator IQN, but a Linux host
  only generates that IQN after it boots — so it can't be known at
  `terraform apply` time.
* To keep the whole deployment in one Terraform run, each Host Group is
  created with a placeholder IQN, with its LUNs attached to it immediately.
* During host prep, before `iscsi-multipath` logs in, the `gcnv-provision`
  Ansible role discovers the VM's real IQN and updates the Host Group in
  place — so authorization always completes before anything tries to use
  the LUNs, with no separate provisioning pass or control node required.
* Each database node gets its own private Host Group and LUN set; this is
  why the backend supports single-instance and Data Guard primary/standby
  today, but not RAC (which needs shared LUNs across nodes).
