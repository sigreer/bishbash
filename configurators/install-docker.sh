#!/bin/bash

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_FAMILY=$(echo "$ID_LIKE" | tr '[:upper:]' '[:lower:]')
        DISTRO_NAME=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
        
        if [[ "$DISTRO_FAMILY" == *"debian"* ]] || [[ "$DISTRO_NAME" == "debian" ]] || [[ "$DISTRO_NAME" == "ubuntu" ]]; then
            echo "debian"
        elif [[ "$DISTRO_FAMILY" == *"rhel"* ]] || [[ "$DISTRO_FAMILY" == *"fedora"* ]] || [[ "$DISTRO_NAME" == "fedora" ]]; then
            echo "redhat"
        else
            echo "unknown"
        fi
    else
        echo "unknown"
    fi
}

# Function to install Docker on Debian/Ubuntu
install_docker_debian() {
    # Remove old versions
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do 
        apt-get remove -y $pkg
    done

    # Add Docker's official GPG key
    apt-get update
    apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update

    # Install Docker packages
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

# Function to install Docker on RHEL/Fedora
install_docker_redhat() {
    # Remove old versions
    dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine podman runc

    # Add Docker repository
    dnf -y install dnf-plugins-core
    dnf config-manager --add-repo https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/docker-ce.repo

    # Install Docker packages
    dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Start and enable Docker service
    systemctl start docker
    systemctl enable docker
}

# Main installation function
installDocker() {
    # Check if script is run as root
    if [ "$EUID" -ne 0 ]; then 
        echo "Please run as root"
        exit 1
    fi

    # Detect distribution and install accordingly
    DISTRO=$(detect_distro)
    case $DISTRO in
        "debian")
            echo "Installing Docker for Debian/Ubuntu..."
            install_docker_debian
            ;;
        "redhat")
            echo "Installing Docker for RHEL/Fedora..."
            install_docker_redhat
            ;;
        *)
            echo "Unsupported distribution. Please install Docker manually."
            exit 1
            ;;
    esac

    # Verify installation
    if command -v docker &> /dev/null; then
        echo "Docker installed successfully!"
        docker --version
        echo "Docker Compose installed successfully!"
        docker compose version
    else
        echo "Docker installation failed!"
        exit 1
    fi
}

# Run the installation
installDocker