# Ansible inventory plugin

This directory contains a dynamic Ansible inventory plugin designed to generate an inventory for various Oracle deployment topologies on Google Cloud.

## How it works

The plugin (`gcp_oracle_inventory.py`) does not use a static inventory file. Instead, it dynamically constructs an in-memory inventory by parsing a YAML configuration file. The `install-oracle.sh` script automatically generates this YAML file (e.g., `gcp_oracle.yml.XXXXXX`) based on the command-line arguments provided.

The plugin is automatically activated by Ansible when the inventory source (`-i`) is a file whose name begins with `gcp_oracle.yml`.

+ ## Python dependencies

This plugin relies on the `PyYAML` library for parsing YAML configuration files. When installing `ansible-core` via `pip install ansible-core` `PyYAML` is typically included as a dependency, so no separate installation should be required in most Ansible environments.

### Interaction with `group_vars/all.yml`

A critical aspect of this system is the merging of variables. The dynamic inventory plugin sets host-specific variables based on the generated YAML file (e.g., IP addresses, database name).

However, a large number of default values, complex Jinja2 templates, and derived variables are defined in `group_vars/all.yml`. Ansible automatically loads these variables and merges them with the host variables from the dynamic inventory. This creates the final, complete set of variables that the playbooks use during execution.

To inspect the final, merged inventory, you can run a command similar to this (assuming `gcp_oracle.yml.yJ5W0I` is a generated inventory file):

```bash
ansible-inventory -i gcp_oracle.yml.yJ5W0I --list
```

## Deployment scenarios and inventory structure

The structure of the generated inventory depends on the `--cluster-type` argument passed to `install-oracle.sh`.

### Single Instance (`--cluster-type NONE`)

This is the most straightforward topology, used for standalone Oracle databases.

*   **Generated Groups:** A single group named `dbasm`.
*   **Hosts:** The `dbasm` group contains a single host. The name of the host is taken from the `instance_hostname` variable.
*   **Variables:** All variables from the generated YAML file and `group_vars/all.yml` are applied to this single host.

### RAC (`--cluster-type RAC`)

This topology is for multi-node, active-active Oracle database clusters.

*   **Generated Groups:** A single group named `dbasm`.
*   **Hosts:** The `dbasm` group contains multiple hosts, one for each node defined in the `cluster_config_json` variable provided to the `install-oracle.sh` script.
*   **Variables:**
    *   Node-specific variables from the JSON configuration (e.g., `vip_name`, `vip_ip`) are set as host variables for each respective node.
    *   Cluster-wide parameters from the JSON configuration, including network details like `public_net` and `scan_ip`s, are set as group variables for the `dbasm` group for compatibility with the existing playbooks as they reference these variables by group name.
    *   Variables from `group_vars/all.yml` are merged for all hosts.

### Data Guard (`--cluster-type DG`)

This topology provides a primary database and a standby database for disaster recovery. The deployment is a two-step process:

1.  **Primary Node Setup:** First, `install-oracle.sh` is run with `--cluster-type NONE` on the primary machine to install a standalone database.
2.  **Standby Node Setup:** Second, `install-oracle.sh` is run with `--cluster-type DG --primary-ip-addr <ip_address_of_primary_node>`. The inventory described below is generated during this second step.

#### Inventory structure for standby deployment

*   **Generated Groups:**
    *   `dbasm`: Contains the standby node.
    *   `primary`: Contains the primary node.
*   **Rationale for Structure:** During the standby setup, the primary database is already fully configured. The inventory's purpose is not to re-configure the primary, but to include it as a remote target for specific tasks (e.g., enabling force logging, configuring the Data Guard broker).
*   **Variable Assignment:**
    *   The standby host in the `dbasm` group receives the full set of configuration variables from the YAML file and `group_vars/all.yml`.
    *   The primary host in the `primary` group is intentionally assigned only the necessary SSH connection parameters (`ansible_ssh_host`, `ansible_ssh_user`, etc.). This is to prevent bugs where a standby-specific variable could be accidentally used during a task delegated to the primary host.

#### Example `gcp_oracle.yml` for standby deployment

```yaml

ora_cluster_type: DG
# Standby's IP and Hostname
instance_ip_addr: 10.0.0.2
instance_hostname: standby-1
# Primary's IP
primary_ip_addr: 10.0.0.1
# Common SSH credentials
instance_ssh_user: ansible
instance_ssh_key: /home/ansible/.ssh/id_rsa
# Other Oracle configuration parameters...
ora_swlib_bucket: gs://my-swlib-bucket
db_password_secret: projects/my-project/secrets/db-password/versions/1
ora_version: 19
db_name: ORCL
```



## Unit tests

Unit tests for the `gcp_oracle_inventory.py` plugin are located in `test_gcp_oracle_inventory.py` within this directory. These tests ensure the plugin correctly parses configuration files and generates the expected Ansible inventory structure for various deployment types.

### What the tests do

*   The tests compare the dynamically generated inventory against pre-defined JSON snapshot files (located in `testdata/snapshots`). These snapshots capture the expected inventory structure, including host groups, hosts, and the key variables explicitly assigned by the plugin.

### How to run tests

To run all unit tests, navigate to the project root directory and execute the following command:

```bash

pytest inventory_plugins/

```

### Manually inspecting generated inventory

It is also possible to manually inspect how Ansible renders the inventory for the input test YAML files. Since the plugin expects its configuration file to begin with `gcp_oracle.yml`, you can copy one of the test input files to a temporary name and then run `ansible-inventory`:

```bash

cp inventory_plugins/testdata/inputs/data_guard.yml gcp_oracle.yml.tmp

ansible-inventory -i gcp_oracle.yml.tmp --list
```

Note that the output inventory will contain a large set of variables, including those explicitly defined in the input `gcp_oracle.yml.tmp` file and those merged from `group_vars/all.yml` (which provides internal variables and default values). The input files in `testdata/inputs/` contain only a small subset of these variables.

### Using a custom inventory file

The `install-oracle.sh` script provides a `--inventory-file` flag that allows you to bypass the dynamic inventory plugin and use your own static inventory file. When this flag is used, you become responsible for defining the entire inventory structure, including host groups and all necessary variables.

This is particularly critical for Data Guard deployments, which rely on a specific structure and a special variable (`is_standby_node`) to function correctly.

#### Custom inventory for Data Guard

To successfully deploy a Data Guard standby node using a custom inventory, your file must adhere to the following structure:

1.  **Groups:** You must define two groups: `dbasm` (for the standby node) and `primary` (for the primary node).
2.  **Primary hostname:** The primary host in your inventory must be named `primary1`, as playbooks rely on this hardcoded hostname for delegation and targeting.
3.  **Hosts:** The standby machine must be placed in the `dbasm` group, and the primary machine must be in the `primary` group.
4.  **`is_standby_node` variable:** You must set the variable `is_standby_node=true` for the standby host. This is the flag that tells the `config-db.yml` playbook to run the standby creation tasks (`db-copy`) instead of the primary creation tasks.
5.  **Host-specific variables:** You must define variables that are unique to each host, such as `ansible_ssh_host`, directly in the inventory. Most other configuration variables will be automatically applied from `group_vars/all.yml`.

**Example `inventory.ini` for Data Guard:**

```ini
# Custom static inventory for a Data Guard deployment

[dbasm]
# The host in this group is the STANDBY node.
# 'is_standby_node=true' is mandatory.
standby-1 ansible_ssh_host=10.0.0.2 is_standby_node=true primary_ip_addr=10.0.0.1 instance_ip_addr=10.0.0.2

[primary]
# The host in this group is the PRIMARY node.
primary1 ansible_ssh_host=10.0.0.1

[all:vars]
# Common variables can be defined here
ansible_ssh_user=ansible
ansible_ssh_private_key_file=/home/ansible/.ssh/id_rsa
```
