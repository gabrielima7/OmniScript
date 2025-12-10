# OmniScript 🚀

**Modular IaC Framework for Hybrid Deployments**

Framework de Infrastructure as Code em Bash puro para orquestração de implantações híbridas.

[![ShellCheck](https://img.shields.io/badge/ShellCheck-passing-brightgreen)](https://www.shellcheck.net/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## ✨ Features

- **🎯 Any-Target Architecture** - Deploy to Docker, Podman, LXC, or Bare Metal with the same workflow
- **🔍 Smart Search** - Unified search across Docker Hub, Quay.io, and native package managers
- **📦 Auto-tagging** - Automatically find latest stable versions (no `latest` tags)
- **🏗️ Builder Stack** - Compose complete environments (DB + Backend + Frontend + Proxy) in one step
- **💾 Universal Backup** - Backup and restore across all targets
- **🔄 Zero-Downtime Updates** - Update containers like Portainer Business
- **🔒 Security by Default** - Auto-generate 32-char passwords if not specified
- **🎨 Hacker-Chic UI** - Beautiful ASCII art and emoji-enhanced terminal experience

## 🚀 Quick Install

```bash
curl -sSL https://raw.githubusercontent.com/gabrielima7/OmniScript/main/install.sh | bash
```

## 📖 Usage

### Interactive Mode
```bash
omniscript
```

### CLI Commands
```bash
# System information
omniscript info

# Search for packages/images
omniscript search nginx

# Install an application
omniscript install nginx -t docker

# Build a complete stack
omniscript stack

# Check for updates
omniscript update

# Backup an application
omniscript backup nginx

# List installed apps
omniscript list
```

## 📁 Project Structure

```
OmniScript/
├── omniscript.sh          # Main entry point
├── install.sh             # One-liner installer
├── global.conf.example    # Configuration template
│
├── lib/                   # Core libraries
│   ├── core.sh           # OS detection, utilities
│   ├── logger.sh         # Logging with colors/emojis
│   ├── ui.sh             # Spinners, menus, progress bars
│   ├── config.sh         # Configuration management
│   └── security.sh       # Password generation, SSH keys
│
├── adapters/              # Target adapters
│   ├── base.sh           # Abstract interface
│   ├── docker.sh         # Docker/Compose
│   ├── podman.sh         # Podman (rootless)
│   ├── lxc.sh            # LXC/LXD
│   └── baremetal.sh      # Native packages
│
├── pkg/                   # Package manager adapters
│   ├── apt.sh            # Debian/Ubuntu
│   ├── dnf.sh            # Fedora/RHEL
│   ├── apk.sh            # Alpine
│   ├── pacman.sh         # Arch
│   └── zypper.sh         # openSUSE
│
├── modules/               # Feature modules
│   ├── search.sh         # Smart Search
│   ├── sysinfo.sh        # System Info
│   ├── backup.sh         # Backup/Restore
│   ├── updater.sh        # Image/Container updater
│   └── builder.sh        # Builder Stack
│
└── apps/                  # Application manifests
    ├── nginx/
    ├── postgres/
    └── traefik/
```

## 🎯 Targets

| Target | Description | Requirements |
|--------|-------------|--------------|
| 🐳 Docker | Docker containers with Compose | Docker Engine |
| 🦭 Podman | Rootless containers | Podman |
| 📦 LXC | System containers | LXD |
| 🖥️ Bare Metal | Native packages | Package manager |

## ⚙️ Configuration

Copy the example config and customize:

```bash
cp global.conf.example ~/.config/omniscript/global.conf
```

### Key Settings

| Setting | Description | Default |
|---------|-------------|---------|
| `DOMAIN` | Primary domain | localhost |
| `DEFAULT_TARGET` | Default deploy target | docker |
| `BACKUP_DIR` | Backup storage path | /var/backups/omniscript |
| `AUTO_UPDATE` | Enable auto-updates | false |

## 🏗️ Builder Stack Templates

Create complete environments in seconds:

| Template | Components |
|----------|------------|
| LAMP | Apache, MySQL, PHP, phpMyAdmin |
| LEMP | Nginx, MySQL, PHP, phpMyAdmin |
| MERN | MongoDB, Express, React, Nginx |
| Django | PostgreSQL, Python, Nginx, Redis |
| WordPress | WordPress, MySQL, Nginx |

```bash
omniscript stack
# Select "Use Template" → "LEMP"
```

## 📝 Creating App Manifests

Create a new app in `apps/myapp/manifest.sh`:

```bash
#!/usr/bin/env bash

APP_NAME="myapp"
APP_DESCRIPTION="My Application"

DOCKER_IMAGE="myapp/myapp"
APT_PACKAGES="myapp"

PORTS=(8080)
VOLUMES=("./data:/app/data")

CONFIGURABLE=(
    "API_KEY:string::API Key for service"
    "DEBUG:bool:false:Enable debug mode"
)

pre_install() {
    os_log_info "Preparing installation..."
}

post_install() {
    os_log_success "Installed!"
}
```

## 🔒 Security

- Passwords auto-generated with 32 cryptographically random characters
- SSH keys generated with Ed25519
- Installation summary shows credentials only once
- Secrets never logged to files

## 🧪 Development

```bash
# Run ShellCheck
shellcheck -x omniscript.sh lib/*.sh adapters/*.sh pkg/*.sh modules/*.sh

# Test help
./omniscript.sh --help

# Test system info
./omniscript.sh info
```

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.

## 🙏 Inspired By

- [Helper Scripts](https://helper-scripts.com/)
- [SetupOrion](https://github.com/oriondesign2015/SetupOrion)
- [Portainer](https://portainer.io/)

---

Made with ❤️ and lots of ☕