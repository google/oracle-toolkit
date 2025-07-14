import os
import shutil
import tempfile
import unittest
import yaml

from typing import Dict
from unittest.mock import patch, MagicMock

import inventory_generator


class TestAnsibleInventoryGenerator(unittest.TestCase):

    def setUp(self):
        """Set up a temporary directory for test output and clear environment variables."""
        self.temp_dir = tempfile.mkdtemp()
        os.environ.clear()

    def tearDown(self):
        """Clean up the temporary directory and environment variables after each test."""
        shutil.rmtree(self.temp_dir)
        os.environ.clear()

    def get_expected_single_instance_env_vars(self) -> Dict[str, str]:
        """Returns a dictionary of environment variables for a single instance setup."""
        return {
            'INSTANCE_SSH_USER': 'ansible',
            'INSTANCE_SSH_KEY': '/home/ansible/.ssh/ansible',
            'INSTANCE_SSH_EXTRA_ARGS': '-o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentityAgent=no',
            'INSTANCE_HOSTGROUP_NAME': 'gce',
            'INSTANCE_HOSTNAME': 'oracle-test-01',
            'INSTANCE_IP_ADDR': '192.168.0.1',
            'ORA_DB_NAME': 'test',
            'CLUSTER_TYPE': 'NONE'
        }

    def get_expected_rac_env_vars(self) -> Dict[str, str]:
        """Returns a dictionary of environment variables for a RAC setup."""
        return {
            'INSTANCE_SSH_USER': 'ansible',
            'INSTANCE_SSH_KEY': '/home/ansible/.ssh/ansible',
            'INSTANCE_SSH_EXTRA_ARGS': '-o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentityAgent=no',
            'INSTANCE_HOSTGROUP_NAME': 'gce',
            'INSTANCE_IP_ADDR': '192.168.0.1',
            'ORA_DB_NAME': 'test',
            'CLUSTER_TYPE': 'RAC',
            'CLUSTER_CONFIG_JSON': '[{"scan_name":"scan","scan_port":"1521","cluster_name":"ora-toolkit-testing","cluster_domain":"saoct.internal","public_net":"bond0.107@bond0","private_net":"bond1.146@bond1","scan_ip1":"192.168.0.111","scan_ip2":"192.168.0.112","scan_ip3":"192.168.0.113","dg_name":"DATA","nodes":[{"node_name":"server-s001","host_ip":"192.168.0.1","vip_name":"server-s001-vip","vip_ip":"192.168.0.101"}]}]',
            'PRIMARY_IP_ADDR': '192.168.0.1'
        }

    def get_expected_single_instance_inventory_dict(self) -> Dict:
        """Returns the expected dictionary structure for a single-instance inventory."""
        return {
            'gce': {
                'hosts': {
                    'oracle-test-01': {
                        'ansible_ssh_host': '192.168.0.1',
                        'ansible_ssh_user': 'ansible',
                        'ansible_ssh_private_key_file': '/home/ansible/.ssh/ansible',
                        'ansible_ssh_extra_args': [
                                '-o ServerAliveInterval=60',
                                '-o ServerAliveCountMax=3',
                                '-o StrictHostKeyChecking=no',
                                '-o UserKnownHostsFile=/dev/null',
                                '-o IdentityAgent=no'
                        ]
                    }
                }
            }
        }

    def get_expected_rac_inventory_dict(self) -> Dict:
        """Returns the expected dictionary structure for a RAC inventory."""
        return {
            'gce': {
                'hosts': {
                    'server-s001': {
                        'ansible_ssh_host': '192.168.0.1',
                        'vip_name': 'server-s001-vip',
                        'vip_ip': '192.168.0.101',
                        'ansible_ssh_user': 'ansible',
                        'ansible_ssh_private_key_file': '/home/ansible/.ssh/ansible',
                        'ansible_ssh_extra_args': [
                                '-o ServerAliveInterval=60',
                                '-o ServerAliveCountMax=3',
                                '-o StrictHostKeyChecking=no',
                                '-o UserKnownHostsFile=/dev/null',
                                '-o IdentityAgent=no'
                        ]
                    }
                },
                'vars': {
                    'scan_name': 'scan',
                    'scan_port': '1521',
                    'cluster_name': 'ora-toolkit-testing',
                    'cluster_domain': 'saoct.internal',
                    'public_net': 'bond0.107@bond0',
                    'private_net': 'bond1.146@bond1',
                    'scan_ip1': '192.168.0.111',
                    'scan_ip2': '192.168.0.112',
                    'scan_ip3': '192.168.0.113',
                    'dg_name': 'DATA'
                }
            }
        }

    @patch('builtins.print')
    def test_single_instance_inventory_generation(self, mock_print: MagicMock):
        """Test generating inventory for a single-instance Oracle DB deployment."""
        env_vars = self.get_expected_single_instance_env_vars()
        with patch.dict(os.environ, env_vars, clear=True):
            generator = inventory_generator.AnsibleInventoryGenerator()
            expected_filename = 'inventory_oracle-test-01_test.yml'
            filepath = os.path.join(self.temp_dir, expected_filename)
            
            success = generator.generate_inventory(output_dir=self.temp_dir)
            self.assertTrue(success, "Inventory generation should succeed for single instance.")
            self.assertTrue(os.path.exists(filepath), f"Expected file {filepath} should exist.")

            with open(filepath, 'r') as f:
                generated_yaml = yaml.safe_load(f)
            
            self.assertEqual(generated_yaml, self.get_expected_single_instance_inventory_dict(),
                             "Generated YAML content does not match expected result for single instance.")

    @patch('builtins.print')
    def test_rac_inventory_generation(self, mock_print: MagicMock):
        """Test generating inventory for an Oracle RAC cluster deployment."""
        env_vars = self.get_expected_rac_env_vars()
        with patch.dict(os.environ, env_vars, clear=True):
            generator = inventory_generator.AnsibleInventoryGenerator()
            expected_filename = 'inventory_test_RAC.yml'
            filepath = os.path.join(self.temp_dir, expected_filename)
            
            success = generator.generate_inventory(output_dir=self.temp_dir)
            self.assertTrue(success, "Inventory generation should succeed for RAC.")
            self.assertTrue(os.path.exists(filepath), f"Expected file {filepath} should exist.")

            with open(filepath, 'r') as f:
                generated_yaml = yaml.safe_load(f)
            
            self.assertEqual(generated_yaml, self.get_expected_rac_inventory_dict(),
                             "Generated YAML content does not match expected result for RAC.")

    @patch('builtins.print')
    def test_missing_single_instance_vars(self, mock_print: MagicMock):
        """Test single-instance validation fails when required variables are missing."""
        env_vars = {
            'INSTANCE_SSH_USER': 'ansible',
            'INSTANCE_SSH_KEY': '/home/ansible/.ssh/ansible',
            'INSTANCE_HOSTGROUP_NAME': 'gce',
            'CLUSTER_TYPE': 'NONE',
            'INSTANCE_SSH_EXTRA_ARGS': '-o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentityAgent=no',
        }
        with patch.dict(os.environ, env_vars, clear=True):
            generator = inventory_generator.AnsibleInventoryGenerator()
            success = generator.generate_inventory(output_dir=self.temp_dir)
            self.assertFalse(success, "Inventory generation should fail due to missing variables.")
            mock_print.assert_called_with(
                'Missing required environment variables for single-instance deployment: INSTANCE_IP_ADDR, ORA_DB_NAME, INSTANCE_HOSTNAME'
            )

    @patch('builtins.print')
    def test_missing_rac_vars(self, mock_print: MagicMock):
        """Test RAC validation fails when required variables are missing."""
        env_vars = {
            'CLUSTER_TYPE': 'RAC',
            'INSTANCE_SSH_USER': 'ansible',
            'INSTANCE_SSH_KEY': '/home/ansible/.ssh/ansible',
            'INSTANCE_SSH_EXTRA_ARGS': '-o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentityAgent=no',
        }
        with patch.dict(os.environ, env_vars, clear=True):
            generator = inventory_generator.AnsibleInventoryGenerator()
            success = generator.generate_inventory(output_dir=self.temp_dir)
            self.assertFalse(success, "Inventory generation should fail due to missing RAC variables.")
            mock_print.assert_called_with(
                'Missing required environment variables for RAC deployment: INSTANCE_HOSTGROUP_NAME, INSTANCE_IP_ADDR, ORA_DB_NAME, CLUSTER_CONFIG_JSON, PRIMARY_IP_ADDR'
            )

    @patch('builtins.print')
    def test_output_directory_creation(self, mock_print: MagicMock):
        """Test that the output directory is created by `generate_inventory` if it doesn't exist."""
        env_vars = self.get_expected_single_instance_env_vars()
        with patch.dict(os.environ, env_vars, clear=True):
            generator = inventory_generator.AnsibleInventoryGenerator()
            new_output_dir = os.path.join(self.temp_dir, 'new_inventories')
            
            self.assertFalse(os.path.exists(new_output_dir), "New output directory should not exist initially.")
            
            success = generator.generate_inventory(output_dir=new_output_dir)
            
            self.assertTrue(success, "Inventory generation with new directory should succeed.")
            self.assertTrue(os.path.exists(new_output_dir), "New output directory should be created.")
            self.assertTrue(os.path.isdir(new_output_dir), "Created path should be a directory.")
            
            filepath = os.path.join(new_output_dir, 'inventory_oracle-test-01_test.yml')
            self.assertTrue(os.path.exists(filepath), "Inventory file should be created inside the new directory.")


if __name__ == '__main__':
    unittest.main()
