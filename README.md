# BishBash

A collection of scripts and snippets to manage everything from common tasks to full OS deployment and customisation.

## Table of Contents
- [Backup Scripts](#backup-scripts)
- [Utility Scripts](#utility-scripts)
- [Disk Tools](#disk-tools)
- [Configuration Scripts](#configuration-scripts)
- [Diagnostic Tools](#diagnostic-tools)
- [Benchmarking Tools](#benchmarking-tools)

## Backup Scripts

Collection of scripts for various backup operations.

### Docker Volume Backup Tool
**Script**: `backupscripts/backup-docker-volumes.sh`  
Automated backup tool for Docker volumes and bind mounts. Creates compressed backups with size checks and interactive confirmations.

#### Features
- Backs up both named volumes and bind mounts
- Size-based warnings for large volumes (>500MB)
- Selective backup options
- Support for running container filtering
- Interactive and silent modes
- Custom environment file support

#### Usage
```bash
./backup-named-volumes.sh <backup|show> <dir|container> <name> [options]
```

#### Commands
- `backup`: Create backups of volumes/bind mounts
- `show`: Display information about volumes/bind mounts without backing up

#### Modes
- `dir`: Process Docker Compose directory
- `container`: Process specific container

#### Options
- `--all`: Backup both named volumes and bind mounts (default)
- `--named-vols`: Backup only named volumes
- `--bind-mounts`: Backup only bind mounts
- `--env-path=#`: Specify custom .env file path
- `--silent`: Suppress all interactive prompts
- `--running=#`: Only process running containers (yes|no, default: yes)

#### Environment Variables (.env)
- `BACKUP_DIR`: Backup destination directory (default: /root/backup)
- `BASE_DOCKER_DIR`: Base directory for Docker Compose files (default: /root/docker)

#### Examples
1. Backup all volumes in a Docker Compose directory:
```bash
./backup-named-volumes.sh backup dir myproject
```

2. Show volumes for a specific container:
```bash
./backup-named-volumes.sh show container mycontainer
```

3. Backup only named volumes in silent mode:
```bash
./backup-named-volumes.sh backup dir myproject --named-vols --silent
```

4. Backup with custom environment file:
```bash
./backup-named-volumes.sh backup dir myproject --env-path=/path/to/.env
```

5. Backup all containers (running and stopped):
```bash
./backup-named-volumes.sh backup dir myproject --running=no
```

#### Backup Process
1. For named volumes:
   - Identifies volumes associated with the container/compose file
   - Calculates volume size
   - Prompts for confirmation if size > 500MB
   - Creates compressed tar.gz backup

2. For bind mounts:
   - Identifies bind mount paths
   - Calculates mount size
   - Prompts for confirmation if size > 500MB
   - Creates compressed tar.gz backup

#### Output
Backups are saved as: `<BACKUP_DIR>/<volume_name>_YYYYMMDD_HHMMSS.tar.gz`

### Traefik Certificate Export
**Script**: `backupscripts/export-traefik-certs.sh`  
Exports and backs up Traefik SSL certificates.

## Utility Scripts

Collection of general utility scripts for system management and maintenance.

### System Management
- `utils/bluetooth-check.sh` - Checks and manages Bluetooth connections
- `utils/powerdown-nas-b4shutdown.sh` - Safely powers down NAS before system shutdown
- `utils/linux-sysprep.sh` - Linux system preparation utility
- `utils/distrocheck.sh` - Identifies Linux distribution and version
- `utils/remove-proxmox-nag-screen.sh` - Removes Proxmox subscription nag screen
- `utils/removesnap.sh` - Removes Snap package manager

### Display and Desktop
- `utils/kderecoverdisplay.sh` - Recovers KDE display settings
- `utils/konstart.sh` - KDE startup configuration

### Development Tools
- `utils/gitstats.sh` - Generates Git repository statistics

### Network Tools
- `utils/nmap-hostlist.sh` - Network host discovery
- `utils/nmap-prettifier.sh` - Formats nmap output for better readability

### File Operations
- `utils/file-and-directory-counter.sh` - Counts files and directories in a path
- `utils/nfo-filename-transposer.sh` - Manages NFO files and filenames
- `utils/scp-by-ls.sh` - SCP file transfer utility

## Disk Tools

Scripts for disk operations, encryption, and storage management.

### Disk Operations
- `disk-tools/listdiskdetails.sh` - Displays detailed information about disk devices
- `disk-tools/diskusage.sh` - Shows disk usage statistics
- `disk-tools/nvmereadwritetest.sh` - Performance testing tool for NVMe drives
- `disk-tools/truenas-full-disk-info.sh` - Detailed TrueNAS disk information

### Data Transfer
- `disk-tools/_rsyncbatch.sh` - Batch file synchronization utility
- `disk-tools/_rbatch.sh` - Simplified batch file transfer tool
- `disk-tools/_rsyncbatchsend.sh` - Batch file sending utility with progress tracking

### Storage Management
- `disk-tools/luks2enc.sh` - LUKS2 encryption management tool
- `disk-tools/capture.sh` - Disk imaging and capture utility

## Configuration Scripts

Scripts for setting up and configuring various services and environments.

### Web Server Setup
- `configurators/nginxubuntu.sh` - Nginx installation and configuration for Ubuntu
- `configurators/nginx-php-mysql-optimised-install.sh` - Optimized LEMP stack installation

### Docker Configuration
- `configurators/dockerubuntu.sh` - Docker installation and setup for Ubuntu

### Shell Configuration
- `configurators/shellconfig.sh` - Shell environment configuration and customization

### Email Server Setup
- `configurators/piler.sh` - Piler email archiver setup and configuration

## Diagnostic Tools

Tools for system diagnosis and log analysis.

### Log Analysis
- `diagnoses/logcatch-fedora.sh` - Fedora system log collection and analysis tool

## Benchmarking Tools

Tools for performance testing and benchmarking.

### Storage Benchmarking
- `benchmarking/pvestorage.sh` - Proxmox VE storage performance testing tool

## Usage Instructions

### General Usage
1. Clone the repository:
```bash
git clone https://github.com/yourusername/bishbash.git
```

2. Make scripts executable:
```bash
chmod +x script_name.sh
```

3. Run desired script:
```bash
./script_name.sh
```

### Important Notes
- Always review scripts before running them
- Some scripts may require root privileges
- Backup your data before running system-modifying scripts
- Check script requirements in the script headers

## Contributing

Feel free to contribute to this collection by submitting pull requests or creating issues for bugs and feature requests.

## License

This project is open source and available under the [MIT License](LICENSE).
