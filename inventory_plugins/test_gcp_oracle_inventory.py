import unittest
from unittest.mock import patch
import os
import json

from gcp_oracle_inventory import InventoryModule
from ansible.errors import AnsibleParserError
from ansible.inventory.manager import InventoryManager
from ansible.parsing.dataloader import DataLoader

class TestGcpOracleInventory(unittest.TestCase):

    def setUp(self):
        self.inventory_module = InventoryModule()
        self.loader = DataLoader()
        self.testdata_path = os.path.join(os.path.dirname(__file__), 'testdata')
        self.maxDiff = None


    def _get_inventory_as_dict(self, inventory):
        """
        Converts an Ansible inventory object to a dictionary format
        similar to `ansible-inventory --list`.
        """
        result = {
            "_meta": {
                "hostvars": {}
            }
        }
        groupvars = {}

        for group_name, group in inventory.groups.items():
            result[group_name] = {
                "hosts": sorted([h.name for h in group.get_hosts()]),
            }
            children = sorted([g.name for g in group.child_groups])
            if children:
                result[group_name]["children"] = children
            
            g_vars = group.get_vars()
            if g_vars:
                if group_name not in groupvars:
                    groupvars[group_name] = {}
                groupvars[group_name].update(g_vars)

        for host_name, host in inventory.hosts.items():
            result["_meta"]["hostvars"][host_name] = host.get_vars()
        
        if groupvars:
            result["_meta"]["groupvars"] = groupvars

        # Remove implicit variables that change between environments
        for host in result["_meta"]["hostvars"].values():
            host.pop('inventory_file', None)
            host.pop('inventory_dir', None)

        return result

    def _run_test_case(self, config_name):
        """
        Runs a test case by parsing an inventory config and comparing
        the result to an expected JSON output file.
        """
        # Each test run needs a fresh inventory object
        inventory = InventoryManager(loader=self.loader, sources=[])
        self.inventory_module.inventory = inventory

        config_file = os.path.join(self.testdata_path, 'inputs', f'{config_name}.yml')
        expected_json_file = os.path.join(self.testdata_path, 'snapshots', f'{config_name}.json')

        self.inventory_module.parse(inventory, self.loader, config_file)
        
        generated_inventory = self._get_inventory_as_dict(inventory)
        
        with open(expected_json_file, 'r') as f:
            expected_inventory = json.load(f)

        self.assertDictEqual(generated_inventory, expected_inventory)

    @patch('ansible.plugins.inventory.BaseInventoryPlugin.verify_file')
    @patch('os.path.basename')
    def test_verify_file(self, mock_basename, mock_super_verify_file):
        mock_super_verify_file.return_value = True
        mock_basename.return_value = 'gcp_oracle.yml'
        self.assertTrue(self.inventory_module.verify_file('/some/path/gcp_oracle.yml'))

        mock_basename.return_value = 'not_gcp_oracle.yml'
        self.assertFalse(self.inventory_module.verify_file('/some/path/not_gcp_oracle.yml'))

    def test_single_instance_inventory(self):
        self._run_test_case('single_instance')

    def test_data_guard_primary_inventory(self):
        self._run_test_case('data_guard_primary')

    def test_data_guard_standby_inventory(self):
        self._run_test_case('data_guard_standby')

    def test_rac_inventory(self):
        self._run_test_case('rac')

    def test_data_guard_inventory_variable_separation(self):
        """
        Tests that for a Data Guard setup, the primary host does not get
        standby-specific variables incorrectly copied to it.
        """
        inventory = InventoryManager(loader=self.loader, sources=[])
        self.inventory_module.inventory = inventory
        config_file = os.path.join(self.testdata_path, 'inputs', 'data_guard_standby.yml')

        self.inventory_module.parse(inventory, self.loader, config_file)

        # Get the populated hosts
        primary_host = inventory.get_host('primary1')
        standby_host = inventory.get_host('standby-1')

        self.assertIsNotNone(primary_host, "Primary host 'primary1' should exist")
        self.assertIsNotNone(standby_host, "Standby host 'standby-1' should exist")

        primary_vars = primary_host.get_vars()
        standby_vars = standby_host.get_vars()

        # 1. Verify Primary Host
        # It should have its own SSH host IP
        self.assertEqual(primary_vars.get('ansible_ssh_host'), '10.0.0.1')
        # It should have connection details
        self.assertEqual(primary_vars.get('ansible_ssh_user'), 'ansible')
        # It should NOT have standby-specific variables
        self.assertNotIn('instance_ip_addr', primary_vars)
        self.assertNotIn('instance_hostname', primary_vars)
        self.assertNotIn('ora_swlib_bucket', primary_vars)
        self.assertNotIn('is_standby_node', primary_vars)
        self.assertTrue(primary_vars.get('is_primary_node'))


        # 2. Verify Standby Host
        # It should have its own SSH host IP
        self.assertEqual(standby_vars.get('ansible_ssh_host'), '10.0.0.2')
        # It should have all the variables from the config file
        self.assertEqual(standby_vars.get('instance_ip_addr'), '10.0.0.2')
        self.assertEqual(standby_vars.get('primary_ip_addr'), '10.0.0.1')
        self.assertEqual(standby_vars.get('ora_swlib_bucket'), 'gs://my-swlib-bucket')
        self.assertTrue(standby_vars.get('is_standby_node'))
        self.assertNotIn('is_primary_node', standby_vars)

    def test_malformed_yaml_raises_error(self):
        inventory = InventoryManager(loader=self.loader, sources=[])
        self.inventory_module.inventory = inventory
        config_file = os.path.join(self.testdata_path, 'inputs', 'malformed.yml')
        with self.assertRaises(AnsibleParserError) as cm:
            self.inventory_module.parse(inventory, self.loader, config_file)
        self.assertIn('Invalid YAML configuration: Expected a dictionary but got', str(cm.exception))

    def test_missing_si_vars_raises_error(self):
        inventory = InventoryManager(loader=self.loader, sources=[])
        self.inventory_module.inventory = inventory
        self.inventory_module.config_data = {'ora_cluster_type': 'SI', 'instance_ip_addr': '1.1.1.1'}
        with self.assertRaises(AnsibleParserError) as cm:
            self.inventory_module._validate_config_data()
        self.assertIn("Missing required variable 'instance_hostname'", str(cm.exception))

    def test_missing_dg_vars_raises_error(self):
        inventory = InventoryManager(loader=self.loader, sources=[])
        self.inventory_module.inventory = inventory
        self.inventory_module.config_data = {'ora_cluster_type': 'DG', 'instance_hostname': 'test', 'instance_ip_addr': '1.1.1.1'}
        with self.assertRaises(AnsibleParserError) as cm:
            self.inventory_module._validate_config_data()
        self.assertIn("Missing required variable 'primary_ip_addr'", str(cm.exception))

    def test_missing_rac_vars_raises_error(self):
        inventory = InventoryManager(loader=self.loader, sources=[])
        self.inventory_module.inventory = inventory
        self.inventory_module.config_data = {'ora_cluster_type': 'RAC'}
        with self.assertRaises(AnsibleParserError) as cm:
            self.inventory_module._validate_config_data()
        self.assertIn("Missing required variable 'cluster_config_json'", str(cm.exception))
