# 🛡️ Linux Server Monitoring Suite

[![ShellCheck](https://github.com/florianorineveu/linux-server-monitoring/workflows/ShellCheck/badge.svg)](https://github.com/florianorineveu/linux-server-monitoring/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Bash-5.0+-green.svg)](https://www.gnu.org/software/bash/)
[![Debian](https://img.shields.io/badge/Debian-11%2B-red.svg)](https://www.debian.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%2B-orange.svg)](https://ubuntu.com/)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://github.com/florianorineveu/linux-server-monitoring/graphs/commit-activity)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

> Production-ready monitoring suite for Linux servers with intelligent false-positive filtering

A comprehensive collection of bash scripts for automated server monitoring, security scanning, and alerting. Built for reliability, with smart filtering to eliminate noisy false positives.

## ✨ Features

- 🔒 **Security Scanning**: Daily rootkit detection (rkhunter, chkrootkit, Lynis)
- 🐳 **Docker Monitoring**: Track critical container health
- 📊 **System Monitoring**: Services, disk space, mail queue
- 📧 **Smart Notifications**: Email alerts only for real issues
- ⚙️ **External Configuration**: Easy maintenance with separate config files
- 🎯 **STRICT/PARANOID Modes**: Eliminate false positives intelligently
- 🔄 **Backup Verification**: Ensure your backups are running
- 📝 **Detailed Logging**: All events tracked for audit

## 🎯 Why This Project?

After managing multiple production servers, I got tired of:
- ❌ Daily false-positive alerts from rkhunter
- ❌ Noisy chkrootkit warnings about legitimate system files
- ❌ Docker containers failing silently
- ❌ Missed backup failures

This suite solves all of that with intelligent filtering and real-world tested configurations.

## 🚀 Quick Start
```bash
# Clone the repository
git clone https://github.com/florianorineveu/linux-server-monitoring.git /opt/monitoring
cd /opt/monitoring

# Copy and configure
cp config/global.conf.example config/global.conf
cp config/services.conf.example config/services.conf
cp config/rkhunter.conf.example config/rkhunter.conf
cp config/chkrootkit.conf.example config/chkrootkit.conf

# Edit configuration files
nano config/global.conf          # Set EMAIL and HOSTNAME
nano config/services.conf        # List your services
nano config/rkhunter.conf        # Customize if needed
nano config/chkrootkit.conf      # Customize if needed

# Install dependencies
sudo apt-get update
sudo apt-get install -y rkhunter chkrootkit lynis fail2ban mailutils

# Set permissions
chmod +x scripts/*.sh
mkdir -p logs

# Install cron jobs (see examples/crontab.example)
sudo crontab -e
```

## 📊 Available Scripts

| Script | Schedule | Purpose |
|--------|----------|---------|
| `rkhunter-scan.sh` | Daily 2 AM | Rootkit detection with intelligent filtering |
| `chkrootkit-scan.sh` | Daily 3 AM | Secondary rootkit scan (STRICT mode) |
| `lynis-audit.sh` | Weekly (Sun 4 AM) | Complete security audit |
| `check-services.sh` | Hourly | Monitor system services |
| `check-docker-containers.sh` | Every 15 min | Docker container health |
| `check-minecraft-backup.sh` | Daily 8 AM | Verify Minecraft server backups |
| `check-disk-space.sh` | Every 6 hours | Disk usage monitoring |
| `check-mail-queue.sh` | Every 6 hours | Mail queue monitoring |

## 🎛️ Configuration Modes

### STRICT Mode (Recommended)

Filters out common false positives automatically. You only get alerts for real issues.

**Perfect for**: Production servers, daily operations

### PARANOID Mode

Reports everything, including warnings. Requires manual tuning of ignore patterns.

**Perfect for**: Security audits, incident investigation

## 📖 Documentation

- [📦 Complete Installation Guide](docs/INSTALLATION.md)
- [⚙️ Configuration Details](docs/CONFIGURATION.md)
- [❓ FAQ & Troubleshooting](docs/FAQ.md)

## 🔧 Requirements

- **OS**: Debian 11+, Ubuntu 20.04+
- **Shell**: Bash 5.0+
- **Privileges**: Root access for monitoring (runs via cron)
- **Mail**: Configured mail transport (Postfix, sendmail, etc.)

## 💡 Use Cases

Perfect for:
- 🖥️ VPS servers (OVH, DigitalOcean, Hetzner, AWS EC2, etc.)
- 🏢 Dedicated servers
- 🐳 Docker-based infrastructure (Nextcloud, web services, etc.)
- 🎮 Game servers (Minecraft, etc.)
- 🌐 Web hosting environments

## 📈 Real-World Usage

This suite is battle-tested on:
- Multiple production VPS instances
- Debian 13 environments
- Docker deployments with 10+ containers
- Servers running 24/7 for months

**Result**: Zero false-positive emails, reliable alerts for real issues.

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details.

### How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 🐛 Reporting Issues

Found a bug or false positive? Please [open an issue](https://github.com/florianorineveu/linux-server-monitoring/issues) with:
- Your OS version
- Script output/logs
- Expected vs actual behavior

## 📊 Project Stats

![GitHub stars](https://img.shields.io/github/stars/florianorineveu/linux-server-monitoring?style=social)
![GitHub forks](https://img.shields.io/github/forks/florianorineveu/linux-server-monitoring?style=social)
![GitHub issues](https://img.shields.io/github/issues/florianorineveu/linux-server-monitoring)
![GitHub pull requests](https://img.shields.io/github/issues-pr/florianorineveu/linux-server-monitoring)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by real-world sysadmin challenges
- Built with best practices from the Linux community
- Tested in production environments

## ⭐ Show Your Support

If this project helped you, please give it a star! ⭐

It helps others discover the project and motivates continued development.

## 📬 Contact

**Florian Orineveu**
- GitHub: [@florianorineveu](https://github.com/florianorineveu)
- Website: [fnev.eu](https://fnev.eu)

## 🗺️ Roadmap

- [ ] Signal/Discord/Slack notification support

---

<p align="center">Made with ❤️ by <a href="https://github.com/florianoreineveu">Florian "Ori" Neveu</a></p>
<p align="center">
  <sub>Built from real production experience, for real production needs.</sub>
</p>
