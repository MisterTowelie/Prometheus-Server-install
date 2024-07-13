# Auto install Prometheus monitoring system on Linux
[![Download](https://img.shields.io/badge/download-Bash-brightgreen.svg)](https://raw.githubusercontent.com/MisterTowelie/Prometheus-Server-install/prometheus-server-install.sh)
[![License](https://img.shields.io/github/license/Shabinder/SpotiFlyer?style=flat-square)](https://www.gnu.org/licenses/gpl-3.0.html)

## System Required:
* Tested on Debian11+(amd64 and Aaarch64), Ubuntu20+(amd64), Trisquel10+(amd64)
* Curl
* Sudo

## Prometheus monitoring system installer
Prometheus project, is a systems and service monitoring system. It collects metrics from configured targets at given intervals, evaluates rule expressions, displays the results, and can trigger alerts when specified conditions are observed.

[Prometheus GitHub](https://github.com/prometheus/prometheus)

The auto-installation script for the Prometheus monitoring system serves the purpose of quick and easy installation on your host

## Installing
It will install Prometheus the server, configure it, create a systemd service.
```bash
curl -O https://raw.githubusercontent.com/MisterTowelie/Prometheus-Server-install/prometheus-server-install.sh && sudo chmod +x prometheus-server-install.sh
sudo ./prometheus-server-install.sh
```
Run the script again to update Prometheus

To fine-tune the Prometheus monitoring system after installation, edit the configuration file prometheus.yml [Prometheus DOCS](https://prometheus.io/docs/prometheus/latest/configuration/configuration/)
```bash
nano /etc/prometheus/prometheus.yml
```








