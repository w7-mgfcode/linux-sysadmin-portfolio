#!/bin/bash
#===============================================================================
# System Inventory - Comprehensive System Information Gathering
#
# Purpose:
#   Collects detailed system inventory including hardware, software, network,
#   and security configuration. Generates JSON reports with diff detection.
#
# Usage:
#   ./system-inventory.sh collect [--output file]    # Gather inventory
#   ./system-inventory.sh report [--format json|html] # Generate report
#   ./system-inventory.sh diff <old> <new>            # Compare inventories
#   ./system-inventory.sh watch                       # Monitor changes
#   ./system-inventory.sh export [--format csv]       # Export data
#
# Configuration:
#   INVENTORY_DIR     Directory for inventory storage (default: /var/lib/inventory)
#   INVENTORY_FORMAT  Output format: json, html (default: json)
#
# Skills Demonstrated:
#   - Comprehensive system information gathering
#   - Hardware and software inventory
#   - JSON and HTML report generation
#   - Change detection and diff reporting
#   - Multi-format data export
#   - OS-agnostic detection logic
#
# Author: Linux Sysadmin Portfolio
# License: MIT
#===============================================================================

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

#===============================================================================
# Configuration
#===============================================================================
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly INVENTORY_DIR="${INVENTORY_DIR:-/var/lib/inventory}"
readonly INVENTORY_FORMAT="${INVENTORY_FORMAT:-json}"

# Inventory data structure
declare -A INVENTORY

#===============================================================================
# Hardware Inventory
#===============================================================================

collect_cpu_info() {
    log_debug "Collecting CPU information..."

    local cpu_model cpu_cores cpu_threads cpu_arch cpu_vendor

    if [[ -f /proc/cpuinfo ]]; then
        cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
        cpu_cores=$(grep "^cpu cores" /proc/cpuinfo | head -1 | awk '{print $4}')
        cpu_threads=$(grep "^processor" /proc/cpuinfo | wc -l)
        cpu_vendor=$(grep "vendor_id" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    else
        cpu_model="Unknown"
        cpu_cores="Unknown"
        cpu_threads=$(nproc 2>/dev/null || echo "Unknown")
        cpu_vendor="Unknown"
    fi

    cpu_arch=$(uname -m)

    INVENTORY["cpu_model"]="$cpu_model"
    INVENTORY["cpu_cores"]="$cpu_cores"
    INVENTORY["cpu_threads"]="$cpu_threads"
    INVENTORY["cpu_arch"]="$cpu_arch"
    INVENTORY["cpu_vendor"]="$cpu_vendor"

    log_success "CPU: $cpu_model ($cpu_threads threads)"
}

collect_memory_info() {
    log_debug "Collecting memory information..."

    local mem_total mem_free mem_available swap_total swap_free

    if [[ -f /proc/meminfo ]]; then
        mem_total=$(grep "MemTotal:" /proc/meminfo | awk '{print $2}')
        mem_free=$(grep "MemFree:" /proc/meminfo | awk '{print $2}')
        mem_available=$(grep "MemAvailable:" /proc/meminfo | awk '{print $2}')
        swap_total=$(grep "SwapTotal:" /proc/meminfo | awk '{print $2}')
        swap_free=$(grep "SwapFree:" /proc/meminfo | awk '{print $2}')
    else
        mem_total="Unknown"
        mem_free="Unknown"
        mem_available="Unknown"
        swap_total="Unknown"
        swap_free="Unknown"
    fi

    INVENTORY["mem_total_kb"]="$mem_total"
    INVENTORY["mem_free_kb"]="$mem_free"
    INVENTORY["mem_available_kb"]="$mem_available"
    INVENTORY["swap_total_kb"]="$swap_total"
    INVENTORY["swap_free_kb"]="$swap_free"

    if [[ "$mem_total" != "Unknown" ]]; then
        INVENTORY["mem_total_gb"]="$(bytes_to_gb $((mem_total * 1024)))"
    else
        INVENTORY["mem_total_gb"]="Unknown"
    fi

    log_success "Memory: ${INVENTORY[mem_total_gb]} GB total"
}

collect_disk_info() {
    log_debug "Collecting disk information..."

    local disk_data=""
    local disk_count=0

    # Get disk information from df
    while IFS= read -r line; do
        local filesystem size used avail use_pct mount
        read -r filesystem size used avail use_pct mount <<< "$line"

        if [[ -n "$filesystem" && "$filesystem" != "Filesystem" ]]; then
            ((disk_count++))
            disk_data+="$filesystem|$size|$used|$avail|$use_pct|$mount;"
        fi
    done < <(df -h 2>/dev/null | grep "^/")

    INVENTORY["disk_count"]="$disk_count"
    INVENTORY["disk_data"]="$disk_data"

    # Get block device information if available
    if command -v lsblk &>/dev/null; then
        local block_devices
        block_devices=$(lsblk -d -n -o NAME,SIZE,TYPE 2>/dev/null | tr '\n' ';' || echo "")
        INVENTORY["block_devices"]="$block_devices"
    else
        INVENTORY["block_devices"]=""
    fi

    log_success "Disks: $disk_count filesystems"
}

collect_network_info() {
    log_debug "Collecting network information..."

    local hostname fqdn primary_ip primary_iface

    hostname=$(hostname 2>/dev/null || echo "Unknown")
    fqdn=$(hostname -f 2>/dev/null || hostname)
    primary_ip=$(get_ip_address 2>/dev/null || echo "Unknown")
    primary_iface=$(get_primary_interface 2>/dev/null || echo "Unknown")

    INVENTORY["hostname"]="$hostname"
    INVENTORY["fqdn"]="$fqdn"
    INVENTORY["primary_ip"]="$primary_ip"
    INVENTORY["primary_interface"]="$primary_iface"

    # Get all network interfaces
    local interfaces=""
    if command -v ip &>/dev/null; then
        interfaces=$(ip -o link show | awk '{print $2}' | sed 's/:$//' | tr '\n' ',' || echo "")
    elif command -v ifconfig &>/dev/null; then
        interfaces=$(ifconfig -a | grep "^[a-z]" | awk '{print $1}' | sed 's/:$//' | tr '\n' ',' || echo "")
    fi

    INVENTORY["network_interfaces"]="$interfaces"

    # DNS servers
    local dns_servers=""
    if [[ -f /etc/resolv.conf ]]; then
        dns_servers=$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}' | tr '\n' ',' || echo "")
    fi
    INVENTORY["dns_servers"]="$dns_servers"

    log_success "Network: $hostname ($primary_ip)"
}

#===============================================================================
# Operating System Inventory
#===============================================================================

collect_os_info() {
    log_debug "Collecting OS information..."

    local os_name os_version os_id kernel_version uptime_seconds

    os_name=$(detect_os)
    os_version=$(detect_os_version)
    os_id="${os_name}-${os_version}"
    kernel_version=$(uname -r)

    if [[ -f /proc/uptime ]]; then
        uptime_seconds=$(awk '{print int($1)}' /proc/uptime)
    else
        uptime_seconds="Unknown"
    fi

    INVENTORY["os_name"]="$os_name"
    INVENTORY["os_version"]="$os_version"
    INVENTORY["os_id"]="$os_id"
    INVENTORY["kernel_version"]="$kernel_version"
    INVENTORY["uptime_seconds"]="$uptime_seconds"

    if [[ "$uptime_seconds" != "Unknown" ]]; then
        INVENTORY["uptime_human"]="$(seconds_to_duration "$uptime_seconds")"
    else
        INVENTORY["uptime_human"]="Unknown"
    fi

    # Architecture
    INVENTORY["architecture"]=$(uname -m)

    # Init system
    INVENTORY["init_system"]=$(detect_init_system)

    # Package manager
    INVENTORY["package_manager"]=$(detect_package_manager)

    log_success "OS: $os_name $os_version (kernel $kernel_version)"
}

collect_package_info() {
    log_debug "Collecting package information..."

    local pkg_manager
    pkg_manager=$(detect_package_manager)

    local installed_packages=""
    local package_count=0

    case "$pkg_manager" in
        apt)
            if command -v dpkg-query &>/dev/null; then
                installed_packages=$(dpkg-query -W -f='${Package}=${Version}\n' 2>/dev/null | tr '\n' ';' || echo "")
                package_count=$(dpkg-query -W -f='${Package}\n' 2>/dev/null | wc -l)
            fi
            ;;
        apk)
            if command -v apk &>/dev/null; then
                installed_packages=$(apk info -v 2>/dev/null | tr '\n' ';' || echo "")
                package_count=$(apk info 2>/dev/null | wc -l)
            fi
            ;;
        yum)
            if command -v rpm &>/dev/null; then
                installed_packages=$(rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}\n' 2>/dev/null | tr '\n' ';' || echo "")
                package_count=$(rpm -qa 2>/dev/null | wc -l)
            fi
            ;;
        *)
            installed_packages=""
            package_count=0
            ;;
    esac

    INVENTORY["package_manager"]="$pkg_manager"
    INVENTORY["package_count"]="$package_count"
    INVENTORY["installed_packages"]="$installed_packages"

    log_success "Packages: $package_count installed"
}

collect_service_info() {
    log_debug "Collecting service information..."

    local init_system
    init_system=$(detect_init_system)

    local running_services=""
    local service_count=0

    case "$init_system" in
        systemd)
            if command -v systemctl &>/dev/null; then
                running_services=$(systemctl list-units --type=service --state=running --no-pager --no-legend | awk '{print $1}' | tr '\n' ',' || echo "")
                service_count=$(systemctl list-units --type=service --state=running --no-pager --no-legend | wc -l)
            fi
            ;;
        openrc)
            if command -v rc-status &>/dev/null; then
                running_services=$(rc-status -s 2>/dev/null | grep "started" | awk '{print $1}' | tr '\n' ',' || echo "")
                service_count=$(rc-status -s 2>/dev/null | grep "started" | wc -l)
            fi
            ;;
        *)
            running_services=""
            service_count=0
            ;;
    esac

    INVENTORY["running_services"]="$running_services"
    INVENTORY["service_count"]="$service_count"

    log_success "Services: $service_count running"
}

#===============================================================================
# Security Inventory
#===============================================================================

collect_security_info() {
    log_debug "Collecting security information..."

    # Firewall status
    local firewall_status="unknown"
    if command -v ufw &>/dev/null; then
        firewall_status=$(ufw status 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")
    elif command -v firewall-cmd &>/dev/null; then
        firewall_status=$(firewall-cmd --state 2>/dev/null || echo "unknown")
    elif command -v iptables &>/dev/null; then
        local rule_count
        rule_count=$(iptables -L -n 2>/dev/null | grep -c "^Chain" || echo "0")
        firewall_status="iptables ($rule_count chains)"
    fi

    INVENTORY["firewall_status"]="$firewall_status"

    # SELinux status (if available)
    local selinux_status="not-installed"
    if command -v getenforce &>/dev/null; then
        selinux_status=$(getenforce 2>/dev/null || echo "unknown")
    fi
    INVENTORY["selinux_status"]="$selinux_status"

    # SSH configuration
    local ssh_status="unknown"
    local ssh_port="unknown"
    if [[ -f /etc/ssh/sshd_config ]]; then
        ssh_status="configured"
        ssh_port=$(grep "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")
    fi
    INVENTORY["ssh_status"]="$ssh_status"
    INVENTORY["ssh_port"]="$ssh_port"

    # User count
    local user_count
    user_count=$(awk -F: '$3 >= 1000 {print $1}' /etc/passwd 2>/dev/null | wc -l)
    INVENTORY["user_count"]="$user_count"

    log_success "Security: Firewall $firewall_status, SELinux $selinux_status"
}

#===============================================================================
# Report Generation
#===============================================================================

generate_json_report() {
    local output_file="${1:-}"

    log_info "Generating JSON report..."

    local json_report
    json_report=$(cat << EOF
{
    "inventory_version": "1.0",
    "timestamp": "$(timestamp_iso)",
    "system": {
        "hostname": "${INVENTORY[hostname]:-unknown}",
        "fqdn": "${INVENTORY[fqdn]:-unknown}",
        "primary_ip": "${INVENTORY[primary_ip]:-unknown}",
        "primary_interface": "${INVENTORY[primary_interface]:-unknown}",
        "uptime_seconds": ${INVENTORY[uptime_seconds]:-0},
        "uptime_human": "${INVENTORY[uptime_human]:-unknown}"
    },
    "hardware": {
        "cpu": {
            "model": "${INVENTORY[cpu_model]:-unknown}",
            "vendor": "${INVENTORY[cpu_vendor]:-unknown}",
            "architecture": "${INVENTORY[cpu_arch]:-unknown}",
            "cores": ${INVENTORY[cpu_cores]:-0},
            "threads": ${INVENTORY[cpu_threads]:-0}
        },
        "memory": {
            "total_kb": ${INVENTORY[mem_total_kb]:-0},
            "total_gb": ${INVENTORY[mem_total_gb]:-0},
            "free_kb": ${INVENTORY[mem_free_kb]:-0},
            "available_kb": ${INVENTORY[mem_available_kb]:-0}
        },
        "swap": {
            "total_kb": ${INVENTORY[swap_total_kb]:-0},
            "free_kb": ${INVENTORY[swap_free_kb]:-0}
        },
        "disk": {
            "filesystem_count": ${INVENTORY[disk_count]:-0}
        }
    },
    "operating_system": {
        "name": "${INVENTORY[os_name]:-unknown}",
        "version": "${INVENTORY[os_version]:-unknown}",
        "kernel": "${INVENTORY[kernel_version]:-unknown}",
        "architecture": "${INVENTORY[architecture]:-unknown}",
        "init_system": "${INVENTORY[init_system]:-unknown}",
        "package_manager": "${INVENTORY[package_manager]:-unknown}"
    },
    "software": {
        "package_count": ${INVENTORY[package_count]:-0},
        "service_count": ${INVENTORY[service_count]:-0}
    },
    "network": {
        "interfaces": "${INVENTORY[network_interfaces]:-}",
        "dns_servers": "${INVENTORY[dns_servers]:-}"
    },
    "security": {
        "firewall_status": "${INVENTORY[firewall_status]:-unknown}",
        "selinux_status": "${INVENTORY[selinux_status]:-not-installed}",
        "ssh_status": "${INVENTORY[ssh_status]:-unknown}",
        "ssh_port": "${INVENTORY[ssh_port]:-22}",
        "user_count": ${INVENTORY[user_count]:-0}
    }
}
EOF
)

    if [[ -n "$output_file" ]]; then
        echo "$json_report" > "$output_file"
        log_success "Report saved to: $output_file"
    else
        echo "$json_report"
    fi
}

generate_html_report() {
    local output_file="${1:-inventory.html}"

    log_info "Generating HTML report..."

    cat > "$output_file" << 'EOF_HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>System Inventory Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 { font-size: 2.5em; margin-bottom: 10px; }
        .header p { font-size: 1.1em; opacity: 0.9; }
        .content { padding: 30px; }
        .section {
            margin-bottom: 30px;
            border-bottom: 2px solid #f0f0f0;
            padding-bottom: 20px;
        }
        .section:last-child { border-bottom: none; }
        .section h2 {
            color: #667eea;
            margin-bottom: 15px;
            font-size: 1.8em;
        }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 15px;
        }
        .info-item {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 8px;
            border-left: 4px solid #667eea;
        }
        .info-label {
            font-weight: 600;
            color: #555;
            font-size: 0.9em;
            text-transform: uppercase;
            margin-bottom: 5px;
        }
        .info-value {
            font-size: 1.1em;
            color: #333;
        }
        .footer {
            text-align: center;
            padding: 20px;
            background: #f8f9fa;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>System Inventory Report</h1>
            <p>Generated on TIMESTAMP_PLACEHOLDER</p>
        </div>
        <div class="content">
            <div class="section">
                <h2>System Information</h2>
                <div class="info-grid">
                    <div class="info-item">
                        <div class="info-label">Hostname</div>
                        <div class="info-value">HOSTNAME_PLACEHOLDER</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">IP Address</div>
                        <div class="info-value">IP_PLACEHOLDER</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Uptime</div>
                        <div class="info-value">UPTIME_PLACEHOLDER</div>
                    </div>
                </div>
            </div>

            <div class="section">
                <h2>Hardware</h2>
                <div class="info-grid">
                    <div class="info-item">
                        <div class="info-label">CPU</div>
                        <div class="info-value">CPU_MODEL_PLACEHOLDER</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">CPU Threads</div>
                        <div class="info-value">CPU_THREADS_PLACEHOLDER</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Memory</div>
                        <div class="info-value">MEMORY_PLACEHOLDER GB</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Filesystems</div>
                        <div class="info-value">DISK_COUNT_PLACEHOLDER</div>
                    </div>
                </div>
            </div>

            <div class="section">
                <h2>Operating System</h2>
                <div class="info-grid">
                    <div class="info-item">
                        <div class="info-label">Distribution</div>
                        <div class="info-value">OS_NAME_PLACEHOLDER OS_VERSION_PLACEHOLDER</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Kernel</div>
                        <div class="info-value">KERNEL_PLACEHOLDER</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Init System</div>
                        <div class="info-value">INIT_PLACEHOLDER</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Package Manager</div>
                        <div class="info-value">PKG_MGR_PLACEHOLDER</div>
                    </div>
                </div>
            </div>

            <div class="section">
                <h2>Software & Services</h2>
                <div class="info-grid">
                    <div class="info-item">
                        <div class="info-label">Installed Packages</div>
                        <div class="info-value">PKG_COUNT_PLACEHOLDER</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Running Services</div>
                        <div class="info-value">SERVICE_COUNT_PLACEHOLDER</div>
                    </div>
                </div>
            </div>

            <div class="section">
                <h2>Security</h2>
                <div class="info-grid">
                    <div class="info-item">
                        <div class="info-label">Firewall</div>
                        <div class="info-value">FIREWALL_PLACEHOLDER</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">SELinux</div>
                        <div class="info-value">SELINUX_PLACEHOLDER</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">SSH Port</div>
                        <div class="info-value">SSH_PORT_PLACEHOLDER</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">User Accounts</div>
                        <div class="info-value">USER_COUNT_PLACEHOLDER</div>
                    </div>
                </div>
            </div>
        </div>
        <div class="footer">
            <p>Generated by System Inventory Tool v1.0.0</p>
        </div>
    </div>
</body>
</html>
EOF_HTML

    # Replace placeholders
    sed -i "s/TIMESTAMP_PLACEHOLDER/$(timestamp_human)/g" "$output_file"
    sed -i "s/HOSTNAME_PLACEHOLDER/${INVENTORY[hostname]:-unknown}/g" "$output_file"
    sed -i "s/IP_PLACEHOLDER/${INVENTORY[primary_ip]:-unknown}/g" "$output_file"
    sed -i "s/UPTIME_PLACEHOLDER/${INVENTORY[uptime_human]:-unknown}/g" "$output_file"
    sed -i "s/CPU_MODEL_PLACEHOLDER/${INVENTORY[cpu_model]:-unknown}/g" "$output_file"
    sed -i "s/CPU_THREADS_PLACEHOLDER/${INVENTORY[cpu_threads]:-0}/g" "$output_file"
    sed -i "s/MEMORY_PLACEHOLDER/${INVENTORY[mem_total_gb]:-0}/g" "$output_file"
    sed -i "s/DISK_COUNT_PLACEHOLDER/${INVENTORY[disk_count]:-0}/g" "$output_file"
    sed -i "s/OS_NAME_PLACEHOLDER/${INVENTORY[os_name]:-unknown}/g" "$output_file"
    sed -i "s/OS_VERSION_PLACEHOLDER/${INVENTORY[os_version]:-unknown}/g" "$output_file"
    sed -i "s/KERNEL_PLACEHOLDER/${INVENTORY[kernel_version]:-unknown}/g" "$output_file"
    sed -i "s/INIT_PLACEHOLDER/${INVENTORY[init_system]:-unknown}/g" "$output_file"
    sed -i "s/PKG_MGR_PLACEHOLDER/${INVENTORY[package_manager]:-unknown}/g" "$output_file"
    sed -i "s/PKG_COUNT_PLACEHOLDER/${INVENTORY[package_count]:-0}/g" "$output_file"
    sed -i "s/SERVICE_COUNT_PLACEHOLDER/${INVENTORY[service_count]:-0}/g" "$output_file"
    sed -i "s/FIREWALL_PLACEHOLDER/${INVENTORY[firewall_status]:-unknown}/g" "$output_file"
    sed -i "s/SELINUX_PLACEHOLDER/${INVENTORY[selinux_status]:-not-installed}/g" "$output_file"
    sed -i "s/SSH_PORT_PLACEHOLDER/${INVENTORY[ssh_port]:-22}/g" "$output_file"
    sed -i "s/USER_COUNT_PLACEHOLDER/${INVENTORY[user_count]:-0}/g" "$output_file"

    log_success "HTML report saved to: $output_file"
}

#===============================================================================
# Commands
#===============================================================================

cmd_collect() {
    local output_file=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --output|-o)
                output_file="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    log_info "Collecting system inventory..."

    # Collect all inventory data
    collect_os_info
    collect_cpu_info
    collect_memory_info
    collect_disk_info
    collect_network_info
    collect_package_info
    collect_service_info
    collect_security_info

    log_success "Inventory collection complete"

    # Generate default report
    if [[ -z "$output_file" ]]; then
        ensure_directory "$INVENTORY_DIR"
        output_file="${INVENTORY_DIR}/inventory-$(timestamp_filename).json"
    fi

    generate_json_report "$output_file"
}

cmd_report() {
    local format="json"
    local output_file=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --format|-f)
                format="$2"
                shift 2
                ;;
            --output|-o)
                output_file="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    # Collect inventory first
    collect_os_info
    collect_cpu_info
    collect_memory_info
    collect_disk_info
    collect_network_info
    collect_package_info
    collect_service_info
    collect_security_info

    case "$format" in
        json)
            generate_json_report "$output_file"
            ;;
        html)
            if [[ -z "$output_file" ]]; then
                output_file="inventory-$(timestamp_filename).html"
            fi
            generate_html_report "$output_file"
            ;;
        *)
            log_error "Unknown format: $format"
            return 1
            ;;
    esac
}

cmd_diff() {
    local old_file="$1"
    local new_file="$2"

    if [[ ! -f "$old_file" ]]; then
        log_error "Old inventory file not found: $old_file"
        return 1
    fi

    if [[ ! -f "$new_file" ]]; then
        log_error "New inventory file not found: $new_file"
        return 1
    fi

    log_info "Comparing inventories..."
    log_info "Old: $old_file"
    log_info "New: $new_file"

    # Simple diff for now (in production, use jq for JSON diff)
    if diff -u "$old_file" "$new_file"; then
        log_success "No changes detected"
    else
        log_warning "Changes detected (see diff above)"
    fi
}

cmd_watch() {
    log_info "Starting inventory monitoring..."
    log_info "Press Ctrl+C to stop"

    local previous_file="${INVENTORY_DIR}/previous.json"

    while true; do
        local current_file="${INVENTORY_DIR}/current.json"

        # Collect current inventory
        cmd_collect --output "$current_file" >/dev/null 2>&1

        # Compare with previous if exists
        if [[ -f "$previous_file" ]]; then
            if ! diff -q "$previous_file" "$current_file" >/dev/null 2>&1; then
                log_warning "Changes detected at $(timestamp_human)"
                cmd_diff "$previous_file" "$current_file"
            fi
        fi

        # Save current as previous
        cp "$current_file" "$previous_file"

        sleep 60
    done
}

#===============================================================================
# Usage
#===============================================================================

usage() {
    cat << EOF
Usage: $SCRIPT_NAME <command> [options]

Comprehensive system inventory and reporting tool.

Commands:
    collect [--output file]          Collect system inventory
    report [--format json|html]      Generate inventory report
    diff <old> <new>                 Compare two inventories
    watch                            Monitor for changes

Options:
    --output, -o <file>              Output file path
    --format, -f <format>            Report format (json, html)

Examples:
    # Collect and save inventory
    $SCRIPT_NAME collect --output /tmp/inventory.json

    # Generate HTML report
    $SCRIPT_NAME report --format html --output /var/www/inventory.html

    # Compare two inventories
    $SCRIPT_NAME diff /tmp/old.json /tmp/new.json

    # Monitor for changes
    $SCRIPT_NAME watch

EOF
}

#===============================================================================
# Main Entry Point
#===============================================================================

main() {
    local command="${1:-help}"

    case "$command" in
        collect)
            shift
            cmd_collect "$@"
            ;;
        report)
            shift
            cmd_report "$@"
            ;;
        diff)
            shift
            if [[ $# -lt 2 ]]; then
                log_error "Missing arguments for diff command"
                usage
                exit 1
            fi
            cmd_diff "$@"
            ;;
        watch)
            cmd_watch
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Allow sourcing for testing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
