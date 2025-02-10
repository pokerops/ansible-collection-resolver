# Ansible Collection - pokerops.resolver

[![Build Status](https://github.com/pokerops/ansible-collection-resolver/actions/workflows/libvirt.yml/badge.svg)](https://github.com/pokerops/ansible-collection-resolver/actions/workflows/libvirt.yml)
[![Ansible Galaxy](http://img.shields.io/badge/ansible--galaxy-pokerops.resolver.svg)](https://galaxy.ansible.com/ui/repo/published/pokerops/resolver/)

An [ansible collection](https://galaxy.ansible.com/ui/repo/published/pokerops/resolver/) for managing Linux resolver configuration across multiple platforms.

## Requirements

- Ansible 2.9 or higher

## Features

- Unified DNS resolver configuration across different Linux distributions
- Support for both Netplan and RedHat-based systems
- Configurable nameservers and search domains
- Automatic detection and configuration of network interfaces
- Safe handling of existing configurations

## Installation

```bash
ansible-galaxy collection install pokerops.resolver
```

## Usage

Include the collection in your playbook:

```yaml
- name: Configure DNS resolvers
  hosts: all
  collections:
    - pokerops.resolver
  vars:
    resolver_nameservers:
      - 8.8.8.8
      - 8.8.4.4
    resolver_search:
      - example.com
      - local.domain
  tasks:
    - name: Import resolver configuration
      ansible.builtin.import_playbook: pokerops.resolver.configure
```

## Variables

| Variable                    | Description                       | Required | Default    |
| --------------------------- | --------------------------------- | -------- | ---------- |
| resolver_nameservers        | List of DNS nameservers           | Yes      | -          |
| resolver_search             | List of DNS search domains        | No       | []         |
| resolver_group              | Target host group                 | No       | all        |
| resolver_unsupported_ignore | Ignore unsupported configurations | No       | false      |
| resolver_netplan_package    | Netplan package name              | No       | netplan.io |

## License

MIT
