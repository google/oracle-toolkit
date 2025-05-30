# Oracle Toolkit for Google Cloud - Disaster Recovery Configurations

The Oracle Toolkit for Google Cloud supports Disaster Recovery (DR) through the provisioning of Oracle Data Guard configurations with a **physical standby** using the Data Guard Broker. Applicable with both Google Bare Metal Solution (BMS) and Compute Engine environments.

At a high level, implementation involves two similar steps:

1. Deployment of a Data Guard **primary** database instance via the normal toolkit deployment steps. For details on this see the [main toolkit user guide](user-guide.md) or the [Compute Engine deployment user guide](compute-vm-user-guide.md).
2. Deployment of a Data Guard physical **standby** instance via a similar toolkit command, but with two additional parameters: the `-cluster-type DG` and `-primary_ip_addr [IP ADDRESS]`.

Once provisioned, more advanced Oracle Data Guard High Availability (HA) and Disaster Recovery (DR) configurations can be manually added. Including having multiple standby database (in any location) in cascading, star, or far-sync topologies or any combination thereof. And/or implementation of a "fast-start failover observer".

## Example Toolkit Invocations

The following examples provision a primary Oracle Database using this toolkit's typical options, and then in a second execution of the toolkit, an Oracle Data Guard physical standby by including the two additional options `-cluster-type` and `-primary-ip-addr`:

```bash
export INSTANCE_IP_ADDR=10.0.10.101

./install-oracle.sh \
  --instance-ip-addr ${INSTANCE_IP_ADDR} \
  --instance-hostname primary-server-19c \
  --ora-version 19 \
  --ora-swlib-bucket gs://[BUCKET_NAME] \
  --ora-data-mounts-json '[{"purpose":"software","blk_device":"/dev/disk/by-id/google-oracle-disk-1","name":"u01","fstype":"xfs","mount_point":"/u01","mount_opts":"nofail"}]' \
  --ora-asm-disks-json '[{"diskgroup":"DATA","disks":[{"blk_device":"/dev/disk/by-id/google-oracle-asm-1","name":"DATA1"}]},{"diskgroup":"RECO","disks":[{"blk_device":"/dev/disk/by-id/google-oracle-asm-2","name":"RECO1"}]}]' \
  --backup-dest "+RECO"

export PRIMARY_IP_ADDR=${INSTANCE_IP_ADDR}
export INSTANCE_IP_ADDR=10.0.10.102

./install-oracle.sh \
  --instance-ip-addr ${INSTANCE_IP_ADDR} \
  --instance-hostname standby-server-19c \
  --ora-version 19 \
  --ora-swlib-bucket gs://[BUCKET_NAME] \
  --ora-data-mounts-json '[{"purpose":"software","blk_device":"/dev/disk/by-id/google-oracle-disk-1","name":"u01","fstype":"xfs","mount_point":"/u01","mount_opts":"nofail"}]' \
  --ora-asm-disks-json '[{"diskgroup":"DATA","disks":[{"blk_device":"/dev/disk/by-id/google-oracle-asm-1","name":"DATA1"}]},{"diskgroup":"RECO","disks":[{"blk_device":"/dev/disk/by-id/google-oracle-asm-2","name":"RECO1"}]}]' \
  --backup-dest "+RECO" \
  --primary-ip-addr ${PRIMARY_IP_ADDR} \
  --cluster-type DG
```

These toolkit invocations are examples only. Customize your actual commands as required.

If desired, all steps can alternatively be implemented using Terraform. For specifics on how to deploy both the primary and standby databases in the Data Guard configuration using Terraform, refer to the [Terraform Infrastructure Provisioning for Oracle Toolkit for GCP Deployments](terraform.md) document.

## Networking and Firewall Requirements

The Data Guard primary and standby VM instances do not need to be in the same region or zone. And for proper geographic DR protection, should usually be in different Google Cloud regions.

While the Oracle Data Guard primary and standby instances can be on different networks/subnets, in different regions, and even in different Google Cloud VPCs or projects, it is mandatory that there network routes between your Ansible Control Node and each database server, and between each database server.

Specifically:

- The Ansible Control Node where the toolkit is run must be able to communicate with both the primary and standby instances. Ansible communicates using ssh (normally configured for TCP ingress on port `22` on the target server). The toolkit verifies this connectivity as an initial step when launched.

- The Oracle Database primary and standby instances must be able to communicate with each other via Oracle Net Services, commonly known as Oracle Net or SQL\*Net. Oracle Net Services will ingress to the Oracle Listener port, which by default uses TCP to port `1521` but which can be changed or customized during Toolkit execution, or post-deployment.

If the instances are on different VPCs, then Google Cloud [VPC Network Peering](https://cloud.google.com/vpc/docs/vpc-peering) will be required.

Additionally, [VPC firewall rules](https://cloud.google.com/firewall/docs/firewalls) will likely need to be created, or existing rules adjusted, to permit Oracle Net Services (SQL\*Net) connectivity, **in both-directions**, between the primary and standby instances.

The exact VPC firewall rules adjustments required is site specific. But generally a [Google Cloud CLI](https://cloud.google.com/cli) (**gcloud**) command such as the following can be used:

```plaintext
gcloud compute firewall-rules create oracle-data-guard \
  --description="Networking for Oracle Data Guard configuration members" \
  --network=[NETWORK_NAME] \
  --direction=INGRESS \
  --priority=1000 \
  --allow=tcp:1521 \
  --source-ranges='[SUBNET_NAME]' \
  --target-tags=[TAGS]
```

Once the Google Cloud VPC firewall is configured to allow the required connectivity, if further networking performance measurement or diagnostics is required, refer to the Oracle support document [Assessing and Tuning Network Performance for Data Guard and RMAN (Doc ID 2064368.1)](https://support.oracle.com/epmos/faces/DocContentDisplay?id=2064368.1).

## Data Guard Protection Modes

Oracle Data Guard provides three main "protection modes": maximum performance, maximum availability, and maximum protection. For a comprehensive description of these modes, see the Oracle Documentation [Oracle Data Guard Protection Modes](https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/oracle-data-guard-protection-modes.html).

By default, the toolkit configures a physical standby database in "Maximum Availability" mode and with the "Real-Time Apply" option enabled. (For additional details on real-time apply see the Oracle Documentation [Apply Services](https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/oracle-data-guard-redo-apply-services.html)).

If required, change the protection mode that the toolkit deploys by adjusting the `roles/dg-config/defaults/main.yml` file and specifically the `data_guard_protection_mode` and `real_time_apply` parameters. This can be done before using the toolkit or even post deployment by re-running the standby installation with the `--tags dg-mode` option. (For details on running the toolkit using tags see the main user guide section [Using tags to run or skip specific parts of the toolkit
](user-guide.md#using-tags-to-run-or-skip-specific-parts-of-the-toolkit).)

Changing the protection mode by re-running and including the `--tags dg-mode` option will only adjust the data guard configuration - it does not re-create any other aspects of the database or Data Guard configuration and it can be safely run while both the primary and standby databases are open and operational.

> **IMPORTANT:** As per the Oracle documentation [Scenario 4: Setting the Configuration Protection Mode](https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/examples-using-data-guard-broker-DGMGRL-utility.html#GUID-82319941-58E8-4672-8609-7CC496D3DC29) moving from Maximum Performance mode directly to Maximum Protection mode is not possible. Instead, first move from Maximum Performance mode to Maximum Availability mode and then in a second execution, to Maximum Protection mode. The toolkit supports such a change by running it twice with the `--tags dg-mode` option, changing the Ansible `data_guard_protection_mode` parameter in the `roles/dg-config/defaults/main.yml` file each time.

## Switchover and Failover Scenarios

To properly manage an Oracle Database DR environment using Data Guard, it is important to recognize and understand the difference between a "**switchover**" and a "**failover**":

- A **switchover** is a graceful role reversal. Usually performed proactively in a controlled scenario. When the switchover is initiated, Data Guard ensures that the physical standby is fully synchronized with the primary and then manages the change of roles. The end result is that both databases are still part of the configuration and physical replication between the two remains. And consequently, the DR protection is maintained. The difference is obviously that the roles are reversed and the former-standby is now the new-primary ready for application and user connections.

- A **failover** is usually implemented in an emergency situation when the primary database becomes unavailable or unusable for some reason. In such a situation, the existing physical standby database is promoted to become the new primary database and starts accepting application and user connections. Replication back to the former-primary database is not automatically re-established after a failover and consequently the DR protection is compromised. The DBA must manually re-instantiate the former-primary database and the Data Guard replication after a failover.

Additional details on switchover and failover operations are provided in the Oracle documentation: [Switchover and Failover Operations](https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/using-data-guard-broker-to-manage-switchovers-failovers.html) and more specific Data Guard broker commands in the sections [Scenario 9: Performing a Switchover Operation](https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/examples-using-data-guard-broker-DGMGRL-utility.html#GUID-1403D1C3-8944-42D0-8BDA-21D695C7958A) and [Scenario 10: Performing a Manual Failover Operation](https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/examples-using-data-guard-broker-DGMGRL-utility.html#GUID-D46A9644-136B-4149-8C74-BF4E845B3DE3).

## General Data Guard Recommendations (Best-practices)

Customize the Oracle databases and Data Guard configurations provisioned using this toolkit to meet your specific needs. However, when implementing Oracle Database disaster recovery configurations using Data Guard, the following recommendations (or best-practices) should be considered:

1. Create the Data Guard configuration environment early in your database's lifecycle:

   - While technically the physical standby database and the Data Guard configuration can be added at any time, provisioning the standby database involves using RMAN and the "active duplicate" option to clone the primary database. Performing this early, while the primary database is small and without application data will allow this step to complete quickly and efficiently. This is especially relevant if your primary and standby databases are in different regions meaning that data transfer between the two instances may be slower.

2. Decide on your required separation and instance locations before running the toolkit:

   - Data Guard member databases can exist anywhere as long as the two servers are properly networked. Decide on your requirements between deploying between two machines in different zones within the same region or in two different regions early and before using the toolkit.

3. Use the same Oracle Database versions during deployment:

   - When initially provisioning and implementing the Data Guard configuration using this toolkit, ensure that both the primary and standby are deployed using the same Oracle version and patch level. In some circumstances (such as rolling patching) differing software versions are possible. However these are advanced configuration scenarios to be implemented by experienced DBAs.

4. Use the Maximum Availability protection mode with the Real-Time Apply option:

   - These settings are implemented by the toolkit by default but are optional and can be adjusted pre or post-deployment if required. However, the Maximum Availability protection mode, combined with the Real-Time Apply option is generally considered the sweet spot allowing the standby database to be as up-to-date as possible (minimal lag) without risking the availability of the primary database in the case of intermittent and temporary network disruptions.

5. Use the Data Guard Broker:

   - The broker is an optional component of Data Guard, but is highly recommended, and is implemented by this toolkit. The broker provides a command line utility, simplified commands, and monitoring of the Data Guard configuration with the various members grouped as an integrated unit known as a "configuration". As of Oracle 12cR2, the broker supports advanced topologies such as cascading standbys. For additional details refer to the Oracle documentation [Oracle Data Guard Broker Concepts](https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/oracle-data-guard-broker-concepts.html).

6. Use the Flashback Database feature:

   - This toolkit enables [flashback database](https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/FLASHBACK-DATABASE.html) on both the primary and standby. This can be beneficial for re-instantiation of the old primary after a failover as it allows the failed-primary to be "rewound" to a specific and known state (SCN). If your environment and available disk space cannot support flashback redo logs, then disable the flashback database option (on either or both instances) post deployment.

7. Implement advanced Data Guard topologies once the initial cluster is stable:

   - Use this toolkit to implement a Data Guard physical standby pair and ensure that it is operating stably. Including through reboots or either instance. Only then, and if required, create a more complex topology such as adding additional standbys or a fast-start failover observer.

8. Test the Switchover and Failover Scenarios:

   - Ensuring that the implemented Data Guard configuration remains operable is critical for providing business continuity and database DR. Performing database DR exercises by switching-over and/or failing-over the database Data Guard DR configuration (and usually reverting back) is typically performed proactively on a regular cadence such as quarterly or semi-annually.

## Troubleshooting Overview

With proper network connectivity and all other prerequisite requirements (see the Toolkit main user guide [Requirements and Prerequisites](user-guide.md#requirements-and-prerequisites) section for additional details on toolkit requirements) in place, the toolkit can properly deploy both a Data Guard primary and physical standby database. (For Oracle Database 12cR2 and higher versions.) Should the deployment fail, the infrastructure can be re-provisioned or re-initialized and the process re-run until it completes successfully. However, post-deployment Data Guard issues are always possible.

Troubleshooting an Oracle Data Guard configuration can be complex and problems may arise due to Data Guard settings (mis-configurations), database status (i.e. missing redo or a database not being is the expected state), or network and connectivity interruptions or problems. The Oracle documentation provides some initial troubleshooting advice and suggestions, see: [Troubleshooting Oracle Data Guard](https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/troubleshooting-oracle-data-guard-broker.html).

Further troubleshooting or issues and problems may require additional steps and support. However, some preliminary diagnostic steps and commands are provided below. Troubleshooting an Oracle Data Guard configuration is usually performed by running various commands using the Data Guard Broker utility `dgmgrl` and by inspecting log files.

### Troubleshooting Using the Data Guard Broker

To start troubleshooting an Oracle Data Guard configuration, connect to the Data Guard Broker on either the primary or standby instances using the broker command line tool. For troubleshooting purposes, an implicitly privileged connection (from the `oracle` OS user which has `dgdba` OS group membership) is sufficient - an explicit credential that has been granted the `SYSDG` administrative privilege can also optionally be used.

Example:

```plaintext
$ dgmgrl /
DGMGRL for Linux: Release 19.0.0.0.0 - Production on Tue May 6 10:58:32 2025
Version 19.3.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

Welcome to DGMGRL, type "help" for information.
Connected to "ORCL"
Connected as SYSDG.
DGMGRL>
```

Use the `show configuration` or `show configuration verbose` commands to see the current state of the cluster.

Example showing a healthy configuration:

```plaintext
DGMGRL> show configuration verbose

Configuration - dg_orcl

  Protection Mode: MaxAvailability
  Members:
  orcl   - Primary database
    orcl_s - Physical standby database

  Properties:
    FastStartFailoverThreshold      = '30'
    OperationTimeout                = '30'
    TraceLevel                      = 'USER'
    FastStartFailoverLagLimit       = '0'
    CommunicationTimeout            = '180'
    ObserverReconnect               = '0'
    FastStartFailoverAutoReinstate  = 'TRUE'
    FastStartFailoverPmyShutdown    = 'TRUE'
    BystandersFollowRoleChange      = 'ALL'
    ObserverOverride                = 'FALSE'
    ExternalDestination1            = ''
    ExternalDestination2            = ''
    PrimaryLostWriteAction          = 'CONTINUE'
    ConfigurationWideServiceName    = 'ORCL_CFG'

Fast-Start Failover:  Disabled

Configuration Status:
SUCCESS

DGMGRL>
```

If the configuration is experiencing an error/issue then the show configuration command will show some indicator of the problem. For example:

```plaintext
DGMGRL> show configuration

Configuration - dg_orcl

  Protection Mode: MaxAvailability
  Members:
  orcl   - Primary database
    Error: ORA-16810: multiple errors or warnings detected for the member

    orcl_s - Physical standby database
      Warning: ORA-16857: member disconnected from redo source for longer than specified threshold

Fast-Start Failover:  Disabled

Configuration Status:
ERROR   (status updated 195 seconds ago)

DGMGRL>
```

When warnings and/or errors are reported for a specific configuration member, additional details on the problem can be obtained by using the `show database verbose [database member name]` command:

```plaintext
DGMGRL> show database verbose orcl

Database - orcl

  Role:               PRIMARY
  Intended State:     TRANSPORT-ON
  Instance(s):
    ORCL
      Error: ORA-16737: the redo transport service for member "orcl_s" has an error

  Database Warning(s):
    ORA-16629: database reports a different protection level from the protection mode

  Properties:
    DGConnectIdentifier             = '//10.2.80.42:1521/ORCL'
    ObserverConnectIdentifier       = ''
    FastStartFailoverTarget         = ''
    PreferredObserverHosts          = ''
    LogShipping                     = 'ON'
    RedoRoutes                      = ''
    LogXptMode                      = 'SYNC'
    DelayMins                       = '0'
    Binding                         = 'optional'
    MaxFailure                      = '0'
    ReopenSecs                      = '300'
    NetTimeout                      = '30'
    RedoCompression                 = 'DISABLE'

...
< output truncated for brevity>
...

  Log file locations:
    Alert log               : /u01/app/oracle/diag/rdbms/orcl/ORCL/trace/alert_ORCL.log
    Data Guard Broker log   : /u01/app/oracle/diag/rdbms/orcl/ORCL/trace/drcORCL.log

Database Status:
ERROR

DGMGRL>
```

Or the problem error messages can be summarized using the `show database [database member name] statusreport` command :

```plaintext
DGMGRL> show database orcl statusreport
STATUS REPORT
       INSTANCE_NAME   SEVERITY ERROR_TEXT
                   *    WARNING ORA-16629: database reports a different protection level from the protection mode
                ORCL      ERROR ORA-16737: the redo transport service for member "orcl_s" has an error

DGMGRL>
```

If the cause of the problem and the required resolution is not apparent from the output of these commands, inspecting the Data Guard broker and database alert logs is likely required.

### Troubleshooting by Inspecting Log Files

The log file locations required for additional troubleshooting are in the standard Oracle Automatic Diagnostic Repository (ADR) trace file locations. However, for user convenience, their fully qualified full names are provided in the output of the `show database verbose [database member name]` command.

For example:

```bash
$ dgmgrl / "show database verbose orcl" | grep -i 'log '
  Log file locations:
    Alert log               : /u01/app/oracle/diag/rdbms/orcl/ORCL/trace/alert_ORCL.log
    Data Guard Broker log   : /u01/app/oracle/diag/rdbms/orcl/ORCL/trace/drcORCL.log
```

To investigate the problem further, first inspect the Data Guard broker log file. Additionally, check the database's alert log.

If the cause of the problem is not apparent from the details in one of both of these log files, searching for an explanation of, and solution to, the problem on the [My Oracle Support](https://support.oracle.com) website may be required. And in some cases, opening of a support case with Oracle support may be required.
