# Auto install Prometheus monitoring system on Linux
[![Download](https://img.shields.io/badge/download-Bash-brightgreen.svg)](https://raw.githubusercontent.com/MisterTowelie/Prometheus-Server-install/main/prometheus-server-install.sh)
[![License](https://img.shields.io/github/license/Shabinder/SpotiFlyer?style=flat-square)](https://www.gnu.org/licenses/gpl-3.0.html)

## System Required:
* Can work on armv*, mips, ppc64, riscv64, s390x.
* Can work on Debian, Ubuntu, CentOS(AlmaLinux), ArchLinux.
 (Tested on Debian11+(amd64 and Aaarch64), Ubuntu20+, Trisquel10+, not tested on other operating systems and platforms)
* Curl
* Sudo

## Prometheus monitoring system installer
Prometheus project, is a systems and service monitoring system. It collects metrics from configured targets at given intervals, evaluates rule expressions, displays the results, and can trigger alerts when specified conditions are observed.

[Prometheus GitHub](https://github.com/prometheus/prometheus)

The auto-installation script for the Prometheus monitoring system serves the purpose of quick and easy installation on your host

## Installing
It will install Prometheus the server, configure it, create a systemd service.
```bash
bash -c "$(curl -O https://raw.githubusercontent.com/MisterTowelie/Prometheus-Server-install/main/prometheus-server-install.sh)" && sudo chmod +x prometheus-server-install.sh && sudo ./prometheus-server-install.sh
```
Run the script again to update Prometheus

To fine-tune the Prometheus monitoring system after installation, edit the configuration file prometheus.yml [Prometheus DOCS](https://prometheus.io/docs/prometheus/latest/configuration/configuration/)
```bash
sudo nano /etc/prometheus/prometheus.yml
```








