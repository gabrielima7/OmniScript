# OmniScript 🚀

> **Modular IaC Framework for Hybrid Deployments**

[![ShellCheck](https://github.com/gabrielima7/OmniScript/workflows/ShellCheck/badge.svg)](https://github.com/gabrielima7/OmniScript/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A powerful Infrastructure as Code framework for orchestrating hybrid deployments across Docker, Podman, LXC, and Bare Metal with a single unified workflow.

## ⚡ Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/gabrielima7/OmniScript/main/install.sh | bash
```

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🎯 **Any-Target Architecture** | Deploy to Docker, Podman, LXC, or Bare Metal with the same workflow |
| 🔍 **Smart Search** | Unified search across Docker Hub, Quay.io, and native package managers |
| 📦 **Auto-tagging** | Automatically find latest stable versions (no `latest` tags) |
| 🏗️ **Builder Stack** | Compose complete environments (DB + Backend + Frontend + Proxy) in one step |
| 💾 **Universal Backup** | Backup and restore across all targets |
| 🔄 **Zero-Downtime Updates** | Rolling updates like Portainer Business |
| 🔒 **Security by Default** | Auto-generate secure passwords if not specified |
| 🎨 **Hacker-Chic UI** | Beautiful ASCII art and emoji-enhanced terminal experience |

## 🎯 Supported Targets

| Target | Icon | Description | Requirements |
|--------|------|-------------|--------------|
| Docker | 🐳 | Docker containers with Compose | Docker Engine |
| Podman | 🦭 | Rootless containers | Podman |
| LXC | 📦 | System containers | LXD |
| Bare Metal | 🖥️ | Native packages | Package manager |

## 📖 Usage

### Interactive TUI

```bash
omniscript      # Launch interactive menu
os              # Shorthand alias
```

### Command Line

```bash
# Search for applications
omniscript search nginx

# Install a module
omniscript install postgresql

# Install with specific target
omniscript -t docker install redis

# Backup a deployment
omniscript backup myapp

# Update OmniScript
omniscript update
```

### CLI Options

```
Usage: omniscript [OPTIONS] [COMMAND]

Commands:
    install <module>        Install a module
    remove <module>         Remove a module
    search <term>           Search for applications/images
    backup <target>         Backup a deployment
    restore <backup>        Restore from backup
    update                  Update OmniScript
    
Options:
    -t, --target <target>   Set deployment target (docker|podman|lxc|baremetal)
    -c, --config <file>     Use alternate config file
    -y, --yes               Skip confirmation prompts
    -v, --verbose           Enable verbose logging
    -h, --help              Show this help message
    --version               Show version information
```

## 🏗️ Builder Stack Templates

Create complete environments with pre-configured templates:

| Template | Components |
|----------|------------|
| LEMP | Linux + Nginx + MySQL + PHP |
| MEAN | MongoDB + Express + Angular + Node |
| MERN | MongoDB + Express + React + Node |
| LAMP | Linux + Apache + MySQL + PHP |
| WordPress | WordPress + MySQL + Nginx |
| GitOps | GitLab + Runner + Registry |
| Monitoring | Prometheus + Grafana + AlertManager |
| Logging | Loki + Promtail + Grafana |
| Media | Jellyfin + Sonarr + Radarr |

```bash
omniscript
# Select: Builder Stack → Use Template → LEMP
```

## 📦 Available Modules

### Databases
- PostgreSQL, MySQL, MariaDB
- MongoDB, Redis
- ClickHouse, InfluxDB

### Web Servers
- Nginx, Caddy, Traefik
- Nginx Proxy Manager, HAProxy

### Monitoring
- Portainer, Grafana
- Prometheus, Netdata
- Uptime Kuma

### Development
- GitLab, Gitea
- Jenkins, Drone CI
- SonarQube

### Security
- Keycloak, Authelia
- Vaultwarden, Vault

## ⚙️ Configuration

Configuration is stored in `~/.omniscript/config.conf`:

```bash
# Default deployment target
OS_DEFAULT_TARGET="docker"

# Global domain for deployments
OS_DOMAIN="example.com"

# Email for SSL certificates
OS_EMAIL="admin@example.com"

# Enable auto-update checking
OS_AUTO_UPDATE="true"
```

Or configure via TUI: `omniscript` → Settings

## 🔒 Security Features

- **Auto-generated passwords**: Secure 32-character passwords by default
- **Secrets management**: Encrypted storage for sensitive data
- **Self-signed SSL**: Automatic certificate generation
- **Permission hardening**: Secure file permissions

```bash
# Generate a secure password
omniscript
# Select: Settings → Manage Secrets → Generate Password
```

## 📁 Project Structure

```
OmniScript/
├── omniscript.sh          # Main entry point
├── install.sh             # One-liner installer
├── config/
│   └── default.conf       # Default configuration
├── lib/
│   ├── core/
│   │   ├── ui.sh          # TUI components
│   │   ├── utils.sh       # Utility functions
│   │   ├── distro.sh      # Distribution detection
│   │   └── targets.sh     # Target management
│   ├── targets/
│   │   ├── docker.sh      # Docker adapter
│   │   ├── podman.sh      # Podman adapter
│   │   ├── lxc.sh         # LXC adapter
│   │   └── baremetal.sh   # Bare Metal adapter
│   ├── features/
│   │   ├── search.sh      # Smart search
│   │   ├── autotag.sh     # Auto-tagging
│   │   ├── security.sh    # Security features
│   │   ├── backup.sh      # Backup/restore
│   │   └── update.sh      # Updates
│   └── menus/
│       ├── main.sh        # Main menu
│       ├── builder.sh     # Builder Stack
│       └── settings.sh    # Settings
└── modules/
    ├── databases/         # Database modules
    ├── webservers/        # Web server modules
    ├── devtools/          # Development tools
    └── monitoring/        # Monitoring tools
```

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines.

### Creating a Module

```bash
#!/usr/bin/env bash
# modules/category/mymodule.sh

OS_MODULE_NAME="mymodule"
OS_MODULE_VERSION="1.0.0"
OS_MODULE_DESCRIPTION="My awesome module"
OS_MODULE_CATEGORY="category"
OS_MODULE_SERVICE="myservice"

# Docker Compose generation
os_module_compose() {
    cat << EOF
version: "3.8"
services:
  mymodule:
    image: myimage:latest
    ...
EOF
}

# Bare Metal installation
os_module_baremetal() {
    os_pkg_install mypackage
    os_service_enable myservice
}
```

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

Inspired by:
- [Chris Titus Tech's Linutil](https://github.com/ChrisTitusTech/linutil)
- [LinuxToys](https://linux.toys)
- Helper scripts community

---

<p align="center">
  Made with ❤️ for the Linux community
</p>