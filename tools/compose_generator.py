#!/usr/bin/env python3
"""
OmniScript - Compose Generator
Generate Docker Compose files from templates with security best practices.
"""

import argparse
import os
import secrets
import string
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional

import yaml

# Templates for common services
TEMPLATES = {
    'nginx': {
        'image': 'nginx:alpine',
        'ports': ['80:80', '443:443'],
        'volumes': ['./conf.d:/etc/nginx/conf.d:ro', './www:/var/www/html:ro'],
        'restart': 'unless-stopped',
        'healthcheck': {
            'test': ['CMD', 'nginx', '-t'],
            'interval': '30s',
            'timeout': '10s',
            'retries': 3
        }
    },
    'postgres': {
        'image': 'postgres:16-alpine',
        'ports': ['5432:5432'],
        'environment': {
            'POSTGRES_USER': '${DB_USER:-postgres}',
            'POSTGRES_PASSWORD': '${DB_PASSWORD}',
            'POSTGRES_DB': '${DB_NAME:-app}'
        },
        'volumes': ['postgres-data:/var/lib/postgresql/data'],
        'restart': 'unless-stopped',
        'healthcheck': {
            'test': ['CMD-SHELL', 'pg_isready -U ${DB_USER:-postgres}'],
            'interval': '10s',
            'timeout': '5s',
            'retries': 5
        }
    },
    'mysql': {
        'image': 'mysql:8.0',
        'ports': ['3306:3306'],
        'environment': {
            'MYSQL_ROOT_PASSWORD': '${DB_PASSWORD}',
            'MYSQL_DATABASE': '${DB_NAME:-app}'
        },
        'volumes': ['mysql-data:/var/lib/mysql'],
        'restart': 'unless-stopped',
        'healthcheck': {
            'test': ['CMD', 'mysqladmin', 'ping', '-h', 'localhost'],
            'interval': '10s',
            'timeout': '5s',
            'retries': 5
        }
    },
    'redis': {
        'image': 'redis:alpine',
        'ports': ['6379:6379'],
        'command': 'redis-server --requirepass ${REDIS_PASSWORD}',
        'volumes': ['redis-data:/data'],
        'restart': 'unless-stopped',
        'healthcheck': {
            'test': ['CMD', 'redis-cli', '-a', '${REDIS_PASSWORD}', 'ping'],
            'interval': '10s',
            'timeout': '5s',
            'retries': 5
        }
    },
    'mongo': {
        'image': 'mongo:6',
        'ports': ['27017:27017'],
        'environment': {
            'MONGO_INITDB_ROOT_USERNAME': '${DB_USER:-admin}',
            'MONGO_INITDB_ROOT_PASSWORD': '${DB_PASSWORD}'
        },
        'volumes': ['mongo-data:/data/db'],
        'restart': 'unless-stopped'
    },
    'traefik': {
        'image': 'traefik:v2.10',
        'ports': ['80:80', '443:443', '8080:8080'],
        'command': [
            '--api.insecure=true',
            '--providers.docker=true',
            '--entrypoints.web.address=:80',
            '--entrypoints.websecure.address=:443'
        ],
        'volumes': ['/var/run/docker.sock:/var/run/docker.sock:ro'],
        'restart': 'unless-stopped'
    },
    'portainer': {
        'image': 'portainer/portainer-ce:latest',
        'ports': ['9000:9000', '9443:9443'],
        'volumes': [
            '/var/run/docker.sock:/var/run/docker.sock',
            'portainer-data:/data'
        ],
        'restart': 'unless-stopped'
    }
}

@dataclass
class ComposeService:
    """Docker Compose service definition."""
    name: str
    image: str
    ports: list[str] = field(default_factory=list)
    environment: dict[str, str] = field(default_factory=dict)
    volumes: list[str] = field(default_factory=list)
    depends_on: list[str] = field(default_factory=list)
    restart: str = 'unless-stopped'
    command: Optional[Any] = None
    healthcheck: Optional[dict] = None
    labels: dict[str, str] = field(default_factory=dict)
    networks: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        result = {
            'image': self.image,
            'container_name': self.name,
            'restart': self.restart
        }

        if self.ports:
            result['ports'] = self.ports
        if self.environment:
            result['environment'] = self.environment
        if self.volumes:
            result['volumes'] = self.volumes
        if self.depends_on:
            result['depends_on'] = self.depends_on
        if self.command:
            result['command'] = self.command
        if self.healthcheck:
            result['healthcheck'] = self.healthcheck
        if self.labels:
            result['labels'] = self.labels
        if self.networks:
            result['networks'] = self.networks

        return result


class ComposeGenerator:
    """Generate Docker Compose configurations."""

    def __init__(self, project_name: str = 'omniscript'):
        self.project_name = project_name
        self.services: list[ComposeService] = []
        self.volumes: list[str] = []
        self.networks: list[str] = ['default']
        self.env_vars: dict[str, str] = {}

    def generate_password(self, length: int = 32) -> str:
        """Generate a secure password."""
        alphabet = string.ascii_letters + string.digits + '!@#$%^&*'
        return ''.join(secrets.choice(alphabet) for _ in range(length))

    def add_service_from_template(self, service_name: str,
                                   template_name: str,
                                   overrides: Optional[dict] = None) -> None:
        """Add a service from a template."""
        if template_name not in TEMPLATES:
            raise ValueError(f"Unknown template: {template_name}")

        template = TEMPLATES[template_name].copy()
        if overrides:
            template.update(overrides)

        service = ComposeService(
            name=f"{self.project_name}-{service_name}",
            image=template.get('image', ''),
            ports=template.get('ports', []),
            environment=template.get('environment', {}),
            volumes=template.get('volumes', []),
            command=template.get('command'),
            healthcheck=template.get('healthcheck'),
            restart=template.get('restart', 'unless-stopped')
        )

        # Extract volumes
        for vol in service.volumes:
            if ':' in vol and not vol.startswith('.') and not vol.startswith('/'):
                vol_name = vol.split(':')[0]
                if vol_name not in self.volumes:
                    self.volumes.append(vol_name)

        self.services.append(service)

    def add_custom_service(self, service: ComposeService) -> None:
        """Add a custom service."""
        self.services.append(service)

    def generate(self) -> dict:
        """Generate the complete Docker Compose configuration."""
        compose = {
            'version': '3.8',
            'services': {}
        }

        for service in self.services:
            service_key = service.name.replace(f"{self.project_name}-", "")
            compose['services'][service_key] = service.to_dict()

        if self.volumes:
            compose['volumes'] = {v: {} for v in self.volumes}

        if len(self.networks) > 1 or 'default' not in self.networks:
            compose['networks'] = {n: {'driver': 'bridge'} for n in self.networks}

        return compose

    def generate_env_file(self) -> str:
        """Generate .env file content with secure defaults."""
        lines = [
            "# Generated by OmniScript",
            f"# Project: {self.project_name}",
            f"# Generated: {__import__('datetime').datetime.now().isoformat()}",
            "",
        ]

        # Check for required passwords
        for service in self.services:
            env = service.environment
            if 'DB_PASSWORD' in str(env) or 'POSTGRES_PASSWORD' in str(env):
                if 'DB_PASSWORD' not in self.env_vars:
                    self.env_vars['DB_PASSWORD'] = self.generate_password()
            if 'REDIS_PASSWORD' in str(env) and 'REDIS_PASSWORD' not in self.env_vars:
                self.env_vars['REDIS_PASSWORD'] = self.generate_password(24)

        for key, value in self.env_vars.items():
            lines.append(f"{key}={value}")

        return '\n'.join(lines) + '\n'

    def to_yaml(self) -> str:
        """Export as YAML."""
        return yaml.dump(self.generate(), default_flow_style=False, sort_keys=False)

    def save(self, output_dir: Path) -> None:
        """Save compose and env files."""
        output_dir = Path(output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)

        # Docker Compose
        compose_file = output_dir / 'docker-compose.yml'
        with open(compose_file, 'w') as f:
            f.write(self.to_yaml())
        print(f"Created: {compose_file}")

        # .env file
        env_content = self.generate_env_file()
        if self.env_vars:
            env_file = output_dir / '.env'
            with open(env_file, 'w') as f:
                f.write(env_content)
            os.chmod(env_file, 0o600)  # Secure permissions
            print(f"Created: {env_file}")


def create_stack(stack_type: str, project_name: str, output_dir: str) -> None:
    """Create a pre-defined stack."""
    gen = ComposeGenerator(project_name)

    stacks = {
        'lemp': ['nginx', 'mysql'],
        'mean': ['mongo', 'nginx'],
        'lamp': ['nginx', 'mysql'],
        'cache': ['redis', 'postgres'],
        'monitoring': ['portainer', 'traefik']
    }

    if stack_type not in stacks:
        print(f"Unknown stack: {stack_type}")
        print(f"Available: {', '.join(stacks.keys())}")
        sys.exit(1)

    for svc in stacks[stack_type]:
        gen.add_service_from_template(svc, svc)

    gen.save(Path(output_dir))


def main():
    parser = argparse.ArgumentParser(description='OmniScript Compose Generator')
    subparsers = parser.add_subparsers(dest='command', help='Commands')

    # List templates
    subparsers.add_parser('list', help='List available templates')

    # Create single service
    create_parser = subparsers.add_parser('create', help='Create compose for a service')
    create_parser.add_argument('template', help='Template name')
    create_parser.add_argument('-n', '--name', default='app', help='Project name')
    create_parser.add_argument('-o', '--output', default='.', help='Output directory')

    # Create stack
    stack_parser = subparsers.add_parser('stack', help='Create a pre-defined stack')
    stack_parser.add_argument('type', help='Stack type (lemp, mean, lamp, cache, monitoring)')
    stack_parser.add_argument('-n', '--name', default='app', help='Project name')
    stack_parser.add_argument('-o', '--output', default='.', help='Output directory')

    # Generate password
    pwd_parser = subparsers.add_parser('password', help='Generate secure password')
    pwd_parser.add_argument('-l', '--length', type=int, default=32, help='Password length')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return

    if args.command == 'list':
        print("Available templates:")
        for name, config in TEMPLATES.items():
            print(f"  {name}: {config['image']}")

    elif args.command == 'create':
        gen = ComposeGenerator(args.name)
        gen.add_service_from_template(args.template, args.template)
        gen.save(Path(args.output))

    elif args.command == 'stack':
        create_stack(args.type, args.name, args.output)

    elif args.command == 'password':
        gen = ComposeGenerator()
        print(gen.generate_password(args.length))


if __name__ == '__main__':
    main()
