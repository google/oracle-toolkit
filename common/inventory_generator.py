#!/usr/bin/env python3
"""
Ansible YAML Inventory Generator for Oracle Database Deployments

This script generates Ansible inventory files based on environment variables for two Oracle deployment scenarios:
1. Single-instance Oracle Database
2. Multi-instance Oracle RAC

The script reads configuration from environment variables and generates
inventory file in YAML format based on the deployment type.

The script relies on the following environment variables being set before it is called.

Environment Variables (Input):
  - CLUSTER_TYPE:           The type of cluster ("RAC", "NONE" or "DG").
  - INSTANCE_SSH_USER:      SSH user for Ansible connections.
  - INSTANCE_SSH_KEY:       Path to the SSH private key for Ansible.
  - INSTANCE_SSH_EXTRA_ARGS: Extra arguments for the SSH connection.
  - INVENTORY_FILE:         Base name for the inventory file. The function appends suffixes.
  - ORA_DB_NAME:            Oracle database name, used for naming the inventory file.
  - INSTANCE_HOSTGROUP_NAME: The name of the host group in the inventory file (e.g., [db]).
  - CLUSTER_CONFIG:         Path to the JSON cluster configuration file (for RAC).
  - CLUSTER_CONFIG_JSON:    A string containing the JSON cluster configuration (alternative to CLUSTER_CONFIG).
  - INSTANCE_HOSTNAME:      Optional hostname for the target server. Defaults to value of INSTANCE_IP_ADDR.
  - INSTANCE_IP_ADDR:       The IP address of the target server to host the Oracle software and database (for single instance installations).
  - PRIMARY_IP_ADDR:        The IP address of the primary server to use as source of primary database for Data Guard configuration (for single instance installations).
Output:
  - Creates an inventory file in the current directory.
  - On success, it prints the full path of the created inventory file to standard output.
  - On failure, it prints an error message to standard error and exits the script with a non-zero status code.
"""

import argparse
import json
import os
import shlex
import sys
import yaml
from typing import Dict, Optional


DEFAULT_SSH_EXTRA_ARGS = '-o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentityAgent=no'

class AnsibleInventoryGenerator:
    """Generates Ansible inventory files in YAML format for Oracle database deployments."""
    
    def __init__(self, env_file: Optional[str] = None):
        """Initialize the generator with environment variables.
        
        Args:
            env_file: Optional path to environment file to load variables from
        """
        if env_file:
            self.load_env_file(env_file)
        
        self.ssh_user = os.getenv('INSTANCE_SSH_USER')
        self.ssh_key = os.getenv('INSTANCE_SSH_KEY')
        ssh_extra_args = os.getenv('INSTANCE_SSH_EXTRA_ARGS', DEFAULT_SSH_EXTRA_ARGS)
        # Split SSH extra args into list and reformat as -o <arg> entries
        ssh_extra_args_list = ssh_extra_args.split()
        self.ssh_extra_args = [
            f"-o {ssh_extra_args_list[i+1]}"
            for i in range(0, len(ssh_extra_args_list), 2)
            if ssh_extra_args_list[i] == '-o'
        ]
        self.hostgroup_name = os.getenv('INSTANCE_HOSTGROUP_NAME')
        self.hostname = os.getenv('INSTANCE_HOSTNAME')
        self.ip_addr = os.getenv('INSTANCE_IP_ADDR')
        self.db_name = os.getenv('ORA_DB_NAME')
        self.cluster_type = os.getenv('CLUSTER_TYPE')
        self.cluster_config_json = os.getenv('CLUSTER_CONFIG_JSON')
        self.primary_ip_addr = os.getenv('PRIMARY_IP_ADDR')
        self.inventory_file = ""
        
    def load_env_file(self, env_file: str) -> None:
        """Load environment variables from a file.
        
        Supports the following formats:
        KEY=VALUE
        KEY='VALUE'
        KEY="VALUE"
        
        Args:
            env_file: Path to the environment file
        """
        if not os.path.exists(env_file):
            print(f"Environment file '{env_file}' not found")
            sys.exit(1)

        try:
            with open(env_file, 'r') as f:
                for line_num, line in enumerate(f, start=1):
                    line = line.strip()
                    if not line or line.startswith('#'):
                        continue
                    if '=' not in line:
                        print(f"Invalid format on line {line_num} in {f}: {line}")
                        continue
                    key, value = line.split('=', 1)
                     # Remove surrounding single or double quotes if present
                    os.environ[key.strip()] = shlex.split(value.strip())[0]
        except IOError as e:
            print(f"Error reading environment file '{env_file}': {e}")
            sys.exit(1)
    
    def validate_single_instance_vars(self) -> bool:
        """Validate environment variables for single-instance deployment."""
        required_vars = [
            ('INSTANCE_SSH_USER', self.ssh_user),
            ('INSTANCE_SSH_KEY', self.ssh_key),
            ('INSTANCE_HOSTGROUP_NAME', self.hostgroup_name),
            ('INSTANCE_IP_ADDR', self.ip_addr),
            ('ORA_DB_NAME', self.db_name),
            ('INSTANCE_HOSTNAME', self.hostname),
        ]
        
        missing_vars = [name for name, value in required_vars if not value]
        
        if missing_vars:
            print(f"Missing required environment variables for single-instance deployment: {', '.join(missing_vars)}")
            return False
        
        return True

    def validate_rac_vars(self) -> bool:
        """Validate environment variables for RAC deployment."""
        required_vars = [
            ('INSTANCE_SSH_USER', self.ssh_user),
            ('INSTANCE_SSH_KEY', self.ssh_key),
            ('INSTANCE_HOSTGROUP_NAME', self.hostgroup_name),
            ('INSTANCE_IP_ADDR', self.ip_addr),
            ('ORA_DB_NAME', self.db_name),
            ('CLUSTER_CONFIG_JSON', self.cluster_config_json),
            ('PRIMARY_IP_ADDR', self.primary_ip_addr)
        ]
        
        missing_vars = [name for name, value in required_vars if not value]
        
        if missing_vars:
            print(f"Missing required environment variables for RAC deployment: {', '.join(missing_vars)}")
            return False
        
        return True
    
    
    def generate_single_instance_inventory(self) -> Dict:
        """Generate YAML inventory structure for single-instance Oracle database."""
        inventory = {
            self.hostgroup_name: {
                'hosts': {
                    self.hostname: {
                        'ansible_ssh_host': self.ip_addr,
                        'ansible_ssh_user': self.ssh_user,
                        'ansible_ssh_private_key_file': self.ssh_key,
                        'ansible_ssh_extra_args': self.ssh_extra_args
                    }
                }
            }
        }
        
        return inventory
    
    def generate_rac_inventory(self) -> Dict:
        """Generate YAML inventory structure for Oracle RAC cluster."""
        cluster_config = json.loads(self.cluster_config_json)[0]
        
        hosts = {}
        for node in cluster_config['nodes']:
            hosts[node['node_name']] = {
                'ansible_ssh_host': node['host_ip'],
                'vip_name': node['vip_name'],
                'vip_ip': node['vip_ip'],
                'ansible_ssh_user': self.ssh_user,
                'ansible_ssh_private_key_file': self.ssh_key,
                'ansible_ssh_extra_args': self.ssh_extra_args
            }
        
        group_vars = {
            'scan_name': cluster_config['scan_name'],
            'scan_port': cluster_config['scan_port'],
            'cluster_name': cluster_config['cluster_name'],
            'cluster_domain': cluster_config['cluster_domain'],
            'public_net': cluster_config['public_net'],
            'private_net': cluster_config['private_net'],
            'scan_ip1': cluster_config['scan_ip1'],
            'scan_ip2': cluster_config['scan_ip2'],
            'scan_ip3': cluster_config['scan_ip3'],
            'dg_name': cluster_config['dg_name']
        }
        
        inventory = {
            self.hostgroup_name: {
                'hosts': hosts,
                'vars': group_vars
            }
        }
        
        return inventory
    
    def generate_filename(self) -> str:
        """Generate appropriate filename based on deployment type."""
        if self.cluster_type and self.cluster_type.upper() == 'RAC':
            return f"inventory_{self.db_name}_RAC.yml"
        else:
            return f"inventory_{self.hostname}_{self.db_name}.yml"
    
    def format_yaml_output(self, inventory_dict: Dict) -> str:
        """Format the inventory dictionary as YAML."""
        return yaml.dump(
            inventory_dict,
            default_flow_style=False,
            indent=2,
            width=120,
            sort_keys=False
        )

    
    def generate_inventory(self, output_dir: str = '.') -> bool:
        """Generate the appropriate YAML inventory file based on configuration.
        
        Args:
            output_dir: Directory where to save the inventory file
        """
        is_rac = self.cluster_type and self.cluster_type.upper() == 'RAC'
        
        if is_rac:
            if not self.validate_rac_vars():
                return False
            inventory_dict = self.generate_rac_inventory()
        else:
            if not self.validate_single_instance_vars():
                return False
            inventory_dict = self.generate_single_instance_inventory()
        
        filename = self.generate_filename()
        filepath = os.path.join(output_dir, filename)
        
        yaml_content = self.format_yaml_output(inventory_dict)
        
        if output_dir != '.' and not os.path.exists(output_dir):
            try:
                os.makedirs(output_dir)
                print(f"Created output directory: {output_dir}")
            except OSError as e:
                print(f"Error creating output directory '{output_dir}': {e}")
                return False
        
        try:
            with open(filepath, 'w') as f:
                f.write(yaml_content)
            
            print(f"Successfully generated YAML inventory file: {filepath}")
            return True
            
        except IOError as e:
            print(f"Error writing inventory file: {e}")
            return False
        except yaml.YAMLError as e:
            print(f"Error formatting YAML: {e}")
            return False


def parse_arguments() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description='Generate Ansible YAML inventory files for Oracle database deployments',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  # Generate inventory using environment variables
  python3 generate_inventory.py
  
  # Generate inventory using variables from a file
  python3 generate_inventory.py --env-file oracle_config.env
  
  # Generate inventory with custom output directory
  python3 generate_inventory.py --env-file config.env --output-dir /path/to/inventories

Environment file format:
  KEY=VALUE
  KEY='VALUE'
  KEY="VALUE"
        ''')
    
    parser.add_argument(
        '-e', '--env-file',
        type=str,
        help='Path to environment file containing configuration variables'
    )
    
    parser.add_argument(
        '-o', '--output-dir',
        type=str,
        default='.',
        help='Output directory for generated inventory files (default: current directory)'
    )
    
    return parser.parse_args()


def main():
    args = parse_arguments()
    
    try:
        import yaml
    except ImportError:
        print("PyYAML is required but not installed.")
        print("Please install it using: sudo apt install python3-yaml")
        sys.exit(1)
    
    generator = AnsibleInventoryGenerator(env_file=args.env_file)
    
    success = generator.generate_inventory(output_dir=args.output_dir)
    if not success:
        sys.exit(1)


if __name__ == "__main__":
    main()
