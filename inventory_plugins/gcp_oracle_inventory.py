DOCUMENTATION = r'''
    name: gcp_oracle_inventory
    plugin_type: inventory
    short_description: Returns Ansible inventory from a YAML configuration file
    description: Returns Ansible inventory from a YAML configuration file
    options:
      plugin:
          description: Name of the plugin
          required: true
          choices: ['gcp_oracle_inventory']
      config_file:
        description: Path to the YAML configuration file
        required: true
'''

from ansible.plugins.inventory import BaseInventoryPlugin
from ansible.errors import AnsibleParserError
import yaml
import os

DEFAULT_HOSTGROUP_NAME = 'dbasm'

class InventoryModule(BaseInventoryPlugin):
    NAME = 'gcp_oracle_inventory'

    def verify_file(self, path):
        '''Return true/false if this is possibly a valid file for this plugin to consume'''
        valid = False
        if super(InventoryModule, self).verify_file(path):
            if os.path.basename(path).startswith('gcp_oracle.yml'):
                valid = True
        return valid

    def parse(self, inventory, loader, path, cache=True):
        '''Return dynamic inventory from parsing the YAML file'''
        super(InventoryModule, self).parse(inventory, loader, path, cache)

        self._read_config_data(path)
        self._validate_config_data()
        self._populate_inventory()

    def _read_config_data(self, path):
        '''Read the YAML configuration file'''
        try:
            with open(path, 'r') as f:
                self.config_data = yaml.safe_load(f)
            if not isinstance(self.config_data, dict):
                raise AnsibleParserError('Invalid YAML configuration: Expected a dictionary but got %s' % type(self.config_data))
        except Exception as e:
            raise AnsibleParserError('Error reading YAML configuration file: %s' % e)

    def _validate_config_data(self):
        '''Validate that all required configuration variables are present'''
        cluster_type = self.config_data.get('ora_cluster_type')

        if cluster_type == 'RAC':
            if 'cluster_config_json' not in self.config_data:
                raise AnsibleParserError("Missing required variable 'cluster_config_json' for RAC installation.")
            cluster_config = self.config_data['cluster_config_json']
            if not isinstance(cluster_config, list) or not cluster_config:
                raise AnsibleParserError("'cluster_config_json' must be a non-empty list for RAC installation.")
            for i, cluster in enumerate(cluster_config):
                if 'nodes' not in cluster or not isinstance(cluster['nodes'], list) or not cluster['nodes']:
                    raise AnsibleParserError("Each cluster in 'cluster_config_json' must have a non-empty 'nodes' list. Check cluster #%d." % (i+1))
                for j, node in enumerate(cluster['nodes']):
                    if 'node_name' not in node:
                        raise AnsibleParserError("Missing 'node_name' for node #%d in cluster #%d." % (j+1, i+1))
                    if 'host_ip' not in node:
                        raise AnsibleParserError("Missing 'host_ip' for node #%d in cluster #%d." % (j+1, i+1))

        elif cluster_type == 'DG':
            required_vars = ['instance_hostname', 'instance_ip_addr', 'primary_ip_addr']
            for var in required_vars:
                if var not in self.config_data:
                    raise AnsibleParserError("Missing required variable '%s' for Data Guard installation." % var)
        else: # Single Instance
            required_vars = ['instance_hostname', 'instance_ip_addr']
            for var in required_vars:
                if var not in self.config_data:
                    raise AnsibleParserError("Missing required variable '%s' for Single Instance installation." % var)

    def _populate_inventory(self):
        '''Populate the inventory based on the user-provided cluster-type'''
        if self.config_data.get('ora_cluster_type') == 'RAC':
            self._populate_rac_inventory()
        elif self.config_data.get('ora_cluster_type') == 'DG':
            self._populate_dg_inventory()
        else:
            self._populate_si_inventory()

    def _populate_si_inventory(self):
        '''Populate a single instance inventory'''
        self.inventory.add_group(DEFAULT_HOSTGROUP_NAME)
        hostname = self.config_data.get('instance_hostname')
        ssh_host = self.config_data.get('instance_ip_addr')
        self.inventory.add_host(hostname, group=DEFAULT_HOSTGROUP_NAME)
        host = self.inventory.get_host(hostname)
        host.set_variable('ansible_ssh_host', ssh_host)
        self._set_common_variables(hostname)

    def _populate_dg_inventory(self):
        '''Populate a Data Guard inventory'''
        # Standby host (uses instance_hostname and instance_ip_addr from gcp_oracle.yml)
        self.inventory.add_group(DEFAULT_HOSTGROUP_NAME)
        standby_hostname = self.config_data.get('instance_hostname')
        standby_ssh_host = self.config_data.get('instance_ip_addr')
        self.inventory.add_host(standby_hostname, group=DEFAULT_HOSTGROUP_NAME)
        standby_host = self.inventory.get_host(standby_hostname)
        standby_host.set_variable('ansible_ssh_host', standby_ssh_host)
        standby_host.set_variable('is_standby_node', True)
        self._set_common_variables(standby_hostname)

        # Primary host (hardcoded as 'primary1', uses primary_ip_addr from gcp_oracle.yml)
        self.inventory.add_group('primary')
        primary_ssh_host = self.config_data.get('primary_ip_addr')
        self.inventory.add_host('primary1', group='primary')
        primary_host = self.inventory.get_host('primary1')
        primary_host.set_variable('ansible_ssh_host', primary_ssh_host)
        primary_host.set_variable('is_primary_node', True)

        # Explicitly set connection vars for both hosts
        ssh_user = self.config_data.get('instance_ssh_user')
        ssh_key = self.config_data.get('instance_ssh_key')
        if ssh_user:
            standby_host.set_variable('ansible_ssh_user', ssh_user)
            primary_host.set_variable('ansible_ssh_user', ssh_user)
        if ssh_key:
            standby_host.set_variable('ansible_ssh_private_key_file', ssh_key)
            primary_host.set_variable('ansible_ssh_private_key_file', ssh_key)


    def _populate_rac_inventory(self):
        '''Populate a RAC inventory'''
        self.inventory.add_group(DEFAULT_HOSTGROUP_NAME)
        cluster_config = self.config_data.get('cluster_config_json', [])

        # Remove the large cluster_config_json from each host
        common_vars = {k: v for k, v in self.config_data.items() if k != 'cluster_config_json'}

        for cluster in cluster_config:
            for node in cluster.get('nodes', []):
                hostname = node.get('node_name')
                ssh_host = node.get('host_ip')
                self.inventory.add_host(hostname, group=DEFAULT_HOSTGROUP_NAME)
                host = self.inventory.get_host(hostname)

                # Set node-specific vars from the cluster config
                host.set_variable('ansible_ssh_host', ssh_host)
                host.set_variable('vip_name', node.get('vip_name'))
                host.set_variable('vip_ip', node.get('vip_ip'))

                # Set common vars from the top-level config
                for key, value in common_vars.items():
                    host.set_variable(key, value)

            # Set cluster-wide parameters as group variables for the 'dbasm' group
            for key, value in cluster.items():
                if key != 'nodes':
                    self.inventory.groups[DEFAULT_HOSTGROUP_NAME].set_variable(key, value)

    def _set_common_variables(self, hostname):
        '''Set common variables for a host'''
        host = self.inventory.get_host(hostname)
        if host:
            # Set all config values as host variables
            for key, value in self.config_data.items():
                host.set_variable(key, value)
