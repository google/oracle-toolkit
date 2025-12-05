# Oracle Toolkit for Google Cloud - Disaster Recovery Configurations

This Oracle Toolkit for Google Cloud document will support Disaster Recovery (DR) through the provisioning of Oracle Data Guard configurations, with a [physical standby](https://docs.oracle.com/en/database/oracle/oracle-database/26/sbydb/introduction-to-oracle-data-guard-concepts.html#GUID-C49AC6F4-C89B-4487-BC18-428D65865B9A) using the [Data Guard Broker](https://docs.oracle.com/en/database/oracle/oracle-database/26/sbydb/introduction-to-oracle-data-guard-concepts.html#GUID-538B9DDD-1553-479D-8E1D-0B5C6848403E).

Implementation involves two similar steps:

1. Deployment of a Data Guard **primary** database instance via the normal toolkit deployment steps (for details on this see the [main toolkit user guide](user-guide.md) or the [Compute Engine deployment user guide](compute-vm-user-guide.md)).
2. Deployment of a Data Guard physical **standby** instance via a similar toolkit command, with additional parameters: `--cluster-type DG`, `--primary_ip_addr [IP ADDRESS]`, and `--ora-db-dg-name [UNIQUE NAME]`.

You can provision multiple Data Guard instances in a star topology by repeating step #2.
Once provisioned, more advanced Oracle Data Guard High Availability (HA) and Disaster Recovery (DR) configurations can then be manually added. 
This includes [cascading](https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/oracle-data-guard-redo-transport-services.html#SBYDB-GUID-34BCB162-D996-4678-97F1-497805764950) or [far sync](https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/creating-oracle-data-guard-far-sync-instance.html) topologies. Also, [Fast-Start Failover](https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/using-data-guard-broker-to-manage-switchovers-failovers.html#DGBKR-GUID-995CED84-BEA1-4675-9C68-B37CB996924F) can be enabled in the broker to support automatic failover.

## Example Toolkit Invocations

The following examples show the provisioning of a primary Oracle Database using this toolkit. In the second command, an Oracle Data Guard physical standby will be provisioned by including the two additional options `--cluster-type` and `--primary-ip-addr`.

<a name="create-data-guard-primary"></a>Create the Data Guard primary instance:

```bash
export PRIMARY_IP_ADDR=10.0.10.101

./install-oracle.sh \
  --instance-ip-addr ${PRIMARY_IP_ADDR} \
  --instance-hostname primary-server-19c \
  --ora-version 19 \
  --ora-swlib-bucket gs://[BUCKET_NAME] \
  --ora-data-mounts-json '[{"purpose":"software","blk_device":"/dev/disk/by-id/google-oracle-disk-1","name":"u01","fstype":"xfs","mount_point":"/u01","mount_opts":"nofail"}]' \
  --ora-asm-disks-json '[{"diskgroup":"DATA","disks":[{"blk_device":"/dev/disk/by-id/google-oracle-asm-1","name":"DATA1"}]},{"diskgroup":"RECO","disks":[{"blk_device":"/dev/disk/by-id/google-oracle-asm-2","name":"RECO1"}]}]' \
  --backup-dest "+RECO"
```

<a name="create-data-guard-standby"></a>Create the Data Guard standby instance:

```bash
export STANDBY_IP_ADDR=10.0.10.102

./install-oracle.sh \
  --instance-ip-addr ${STANDBY_IP_ADDR} \
  --instance-hostname standby-server-19c \
  --ora-version 19 \
  --ora-swlib-bucket gs://[BUCKET_NAME] \
  --ora-data-mounts-json '[{"purpose":"software","blk_device":"/dev/disk/by-id/google-oracle-disk-1","name":"u01","fstype":"xfs","mount_point":"/u01","mount_opts":"nofail"}]' \
  --ora-asm-disks-json '[{"diskgroup":"DATA","disks":[{"blk_device":"/dev/disk/by-id/google-oracle-asm-1","name":"DATA1"}]},{"diskgroup":"RECO","disks":[{"blk_device":"/dev/disk/by-id/google-oracle-asm-2","name":"RECO1"}]}]' \
  --backup-dest "+RECO" \
  --primary-ip-addr ${PRIMARY_IP_ADDR} \
  --cluster-type DG
```

The above toolkit invocations are examples only. Customize your actual commands as required.

## Networking and Firewall Requirements

The Data Guard primary and standby VM instances don't need to be in the same Google Cloud region or zone. To provide robust protection in the case of a regional outage, place your standby instance in a different region than your primary instance.

While the Oracle Data Guard primary and standby instances can be on different networks/subnets, in different regions, and even in different Google Cloud VPCs or projects, it is mandatory that your Ansible Control Node can communicate with each database server and that database servers can communicate with each other.

Specifically:

- The Ansible Control Node, where the toolkit is run, must be capable of communicating with both the primary and standby instances. Ansible communicates using ssh (normally configured for TCP ingress on port `22` on the target server). The toolkit will verify this connectivity as an initial step when launched.

- The Oracle Database primary and standby instances must be able to communicate with each other via Oracle Net Services, commonly known as Oracle Net or SQL\*Net. Oracle Net Services will ingress to the Oracle Listener port, which by default uses TCP to port `1521`. However, this can be changed or customized during toolkit execution, or post-deployment.

If the instances are on different VPCs, then Google Cloud [VPC Network Peering](https://cloud.google.com/vpc/docs/vpc-peering) will be required.

Additionally, [VPC firewall rules](https://cloud.google.com/firewall/docs/firewalls) will likely need to be created, or existing rules adjusted, to permit Oracle Net Services (SQL\*Net) connectivity, **in both-directions**, between the primary and standby instances.

The exact VPC firewall rules adjustments required are site-specific. However, generally a [Google Cloud CLI](https://cloud.google.com/cli) (**gcloud**) command such as the following can be used:

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

Once the Google Cloud VPC firewall is configured to allow the required connectivity, if further networking performance measurements or diagnostics are required, refer to the Oracle support document [Assessing and Tuning Network Performance for Data Guard and RMAN (Doc ID 2064368.1)](https://support.oracle.com/epmos/faces/DocContentDisplay?id=2064368.1).

## Data Guard Protection Modes

Oracle Data Guard is capable of providing three main "protection modes": maximum performance, maximum availability, and maximum protection. The Oracle documentation [Oracle Data Guard Protection Modes](https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/oracle-data-guard-protection-modes.html) provides a comprehensive description of these modes.

By default, the toolkit configures a physical standby database in maximum availability mode and with the real-time apply option enabled (for additional details on "real-time apply" see the Oracle documentation [Apply Services](https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/oracle-data-guard-redo-apply-services.html)).

If required, change the protection mode the toolkit deploys by editing the `roles/dg-config/defaults/main.yml` file and adjusting the `data_guard_protection_mode` and `real_time_apply` parameters before running.

Once deployed, the protection mode and real-time apply settings can be changed. You can do this manually using the Data Guard broker, or leverage this toolkit by modifying the Ansible parameters and re-running the standby installation with `--tags dg-mode`.

For detailed instructions on running the toolkit with tags, see the main user guide section: [Using tags to run or skip specific parts of the toolkit](user-guide.md#using-tags-to-run-or-skip-specific-parts-of-the-toolkit).

Re-running with `--tags dg-mode` only modifies the Data Guard configuration. It does not re-create any other database or Data Guard components, and you can safely run it while both the primary and standby databases are open and operational.

> **NOTE:** As per the Oracle documentation [Scenario 4: Setting the Configuration Protection Mode](https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/examples-using-data-guard-broker-DGMGRL-utility.html#GUID-82319941-58E8-4672-8609-7CC496D3DC29) moving from maximum performance mode directly to maximum protection mode isn't possible. Instead, move from maximum performance mode to maximum availability mode and then, in a second execution, to maximum protection mode. The toolkit supports such a change by running it twice with the `--tags dg-mode` option, changing the Ansible `data_guard_protection_mode` parameter in the `roles/dg-config/defaults/main.yml` file each time.

## Switchover and Failover Scenarios

To properly manage an Oracle Database DR environment using Data Guard, it is important to recognize and understand the difference between a "**switchover**" and a "**failover**":

- A **switchover** is a graceful role reversal, usually performed proactively in a controlled scenario. When a switchover is initiated, Data Guard ensures the physical standby is fully synchronized with the primary and then manages the change of roles. The end result is that both databases are still part of the configuration, and physical replication between the two is maintained. Consequently, the DR protection is maintained. The difference is that the roles are reversed and the former-standby is now the new-primary, ready for application and user connections.

- A **failover** is typically implemented in an emergency situation when the primary database becomes unavailable or unusable. In such a situation, the existing physical standby database is promoted to become the new primary database and starts accepting application and user connections. Replication back to the former-primary database is not automatically re-established after a failover and consequently the DR protection is compromised. You must manually re-instantiate the former-primary database and the Data Guard replication after a failover.

Additional details on switchover and failover operations are provided in the Oracle documentation: [Switchover and Failover Operations](https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/using-data-guard-broker-to-manage-switchovers-failovers.html). Specific Data Guard broker commands can be found in sections [Scenario 9: Performing a Switchover Operation](https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/examples-using-data-guard-broker-DGMGRL-utility.html#GUID-1403D1C3-8944-42D0-8BDA-21D695C7958A) and [Scenario 10: Performing a Manual Failover Operation](https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/examples-using-data-guard-broker-DGMGRL-utility.html#GUID-D46A9644-136B-4149-8C74-BF4E845B3DE3).

## General Data Guard Recommendations

Customize the Oracle databases and Data Guard configurations provisioned using this toolkit to meet your specific needs. However, when implementing Oracle Database DR configurations using Data Guard, the following recommendations should be considered:

1. <a name="create-the-data-guard-configuration-environment-early"></a>**Create the Data Guard configuration environment early in your database's lifecycle**

   - While the physical standby database and the Data Guard configuration can be added at any time, provisioning the standby database involves using RMAN and the "active duplicate" option to clone the primary database. Performing this provisioning early on, while the primary database is small and without application data, will allow this step to complete quickly and efficiently. This is especially relevant if your primary and standby databases are in different regions, which will potentially result in slower data transfer between the two instances.

2. <a name="decide-on-locations-before-running"></a>**Decide on your required separation and instance locations before running the toolkit**

   - Data Guard member databases can exist anywhere as long as the two servers are properly networked. Decide on your requirements, choosing to either deploy between two machines in different zones within the same region or in two different regions early on, before using the toolkit.

3. <a name="use-the-same-oracle-versions"></a>**Use the same Oracle Database versions during deployment**

   - When initially provisioning and implementing the Data Guard configuration using this toolkit, ensure both the primary and standby are deployed using the same Oracle version and patch level.

4. <a name="use-maximum-availability-with-rta"></a>**Use the maximum availability protection mode with the real-time apply option**

   - The toolkit implements these settings by default. However, they are optional and can be adjusted pre- or post-deployment, if required. The maximum availability protection mode, combined with the real-time apply option is generally considered the sweet spot that allows the standby database to be as up-to-date as possible (minimal lag) without risking the availability of the primary database in the case of intermittent and temporary network disruptions. Maximum performance mode risks more potential data loss in the event of a failure as not all transactions may be written to disk by the standby database. And maximum protection mode risks primary database shutdown to ensure zero data loss, if the standby becomes unavailable.

5. <a name="use-the-data-guard-broker"></a>**Use the Data Guard Broker**

   - The Data Guard broker, an optional component implemented by this toolkit, simplifies management by offering a command-line utility, simplified commands, and unified monitoring of the Data Guard configuration, treating its various members as an integrated unit. As of Oracle 12cR2, the broker also supports advanced topologies such as cascading standbys. For additional details, refer to the Oracle documentation [Oracle Data Guard Broker Concepts](https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/oracle-data-guard-broker-concepts.html).

6. <a name="use-flashback-database"></a>**Use the Flashback Database feature**

   - This toolkit enables the [Flashback Database](https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/FLASHBACK-DATABASE.html) feature on both the primary and standby database. This can be beneficial for re-instantiation of the old primary after a failover as it allows the failed-primary to be "rewound" to a specific and known state (SCN). Flashing backwards can be significantly faster than the alternative of restoring from a physical backup, and rolling forward. If your environment and available disk space cannot support flashback redo logs, disable the flashback database feature (on either or both databases) post-deployment.

7. <a name="ensure-operational-stability-before-expanding"></a>**Implement advanced Data Guard topologies once the initial cluster is stable**

   - Use this toolkit to implement a Data Guard physical standby and ensure its operational stability, including resilience to reboots of either instance. Then, proceed incrementally to more complex topologies, such as adding additional standbys or a Fast-Start Failover observer, if greater configuration protection is desired. Always balance the benefits with the costs and risks, such as an inadvertent Fast-Start Failover during planned maintenance.

8. <a name="test-switchover-and-failover"></a>**Test the Switchover and Failover scenarios**

   - Ensuring the implemented Data Guard configuration remains operable is critical for providing business continuity and database DR. Performing database DR exercises by switching over and/or failing over the database Data Guard DR configuration (and usually reverting back) is typically performed proactively on a regular cadence such as quarterly or semi-annually.

## Troubleshooting Overview

With proper network connectivity and all other prerequisite requirements (see the toolkit main user guide [Requirements and Prerequisites](user-guide.md#requirements-and-prerequisites) section for additional details on toolkit requirements) in place, the toolkit can properly deploy both a Data Guard primary and physical standby database (for Oracle Database 12cR2 and higher versions). Should the deployment fail, the infrastructure can be re-provisioned or re-initialized and the process re-run until it completes successfully. However, post-deployment Data Guard issues remain possible.

Troubleshooting an Oracle Data Guard configuration can be complex and problems may arise due to Data Guard settings (mis-configurations), database status (i.e. missing redo or a database not being in the expected state), or network and connectivity interruptions. The Oracle documentation [Troubleshooting Oracle Data Guard](https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/troubleshooting-oracle-data-guard-broker.html) provides some initial troubleshooting advice and suggestions.

Further issues may require additional steps and support. However, some preliminary diagnostic steps and commands are provided below. Troubleshooting an Oracle Data Guard configuration is usually performed by running various commands using the Data Guard broker utility `dgmgrl` and by inspecting log files.

### Troubleshooting Using the Data Guard Broker

To start troubleshooting an Oracle Data Guard configuration, connect to the Data Guard broker on either the primary or standby instances using the broker command line tool. For troubleshooting purposes, an implicitly privileged connection (from the `oracle` OS user which has `dgdba` OS group membership) is sufficient - an explicit credential that has been granted the `SYSDG` administrative privilege can also optionally be used.

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

If the configuration is experiencing an error/issue, the show configuration command will show some indicator of the problem. For example:

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

Or, the problem error messages can be summarized using the `show database [database member name] statusreport` command :

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

The log file locations required for additional troubleshooting are in the standard Oracle Automatic Diagnostic Repository (ADR) trace file locations. However, for user convenience, their fully qualified file name are provided in the output of the `show database verbose [database member name]` command.

For example:

```bash
$ dgmgrl / "show database verbose orcl" | grep -i 'log '
  Log file locations:
    Alert log               : /u01/app/oracle/diag/rdbms/orcl/ORCL/trace/alert_ORCL.log
    Data Guard Broker log   : /u01/app/oracle/diag/rdbms/orcl/ORCL/trace/drcORCL.log
```

To investigate the problem further, inspect the Data Guard broker log file. Additionally, check the database's alert log.

If the cause of the problem is not apparent from the details in one or both of these log files, searching for an explanation of, and solution to, the problem on the [My Oracle Support](https://support.oracle.com) website may be required. And, in some cases, opening of a support case with Oracle support may be necessary.
