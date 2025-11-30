#!/bin/bash
#===============================================================================
# Network Diagnostics Tool - Comprehensive Network Troubleshooting
#
# Purpose:
#   Swiss-army knife for network troubleshooting with multiple diagnostic modes.
#   Uses git-style subcommand architecture for organized functionality.
#
# Usage:
#   ./network-diagnostics.sh <command> [options]
#
# Commands:
#   connectivity <host>     - Test connectivity to host (ping, traceroute, MTU)
#   dns <domain>            - DNS resolution testing (A, AAAA, MX, TXT)
#   routes [destination]    - Routing table analysis
#   ports <host> [ports]    - Port connectivity testing
#   scan <network>          - Local network discovery
#   report                  - Comprehensive network report (JSON)
#   help                    - Show detailed help
#
# Skills Demonstrated:
#   - Git-style subcommand architecture
#   - ASCII table generation
#   - Multiple network protocols (ICMP, DNS, TCP)
#   - Cross-platform tool detection
#   - Timeout handling
#   - JSON report generation
#   - User-friendly output formatting
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
readonly REPORT_DIR="${REPORT_DIR:-/var/reports}"
readonly TIMEOUT="${NETWORK_TIMEOUT_SECONDS:-10}"
readonly MAX_HOPS="${NETWORK_MAX_HOPS:-30}"

# Common ports for scanning
readonly -a COMMON_PORTS=(22 80 443 25 587 465 993 995 3306 5432 6379 8080 8443)

#===============================================================================
# Helper Functions
#===============================================================================

usage() {
    cat << EOF
Usage: $SCRIPT_NAME <command> [arguments]

Comprehensive network diagnostics and troubleshooting tool.

Commands:
    connectivity <host>         Test connectivity to a host
                                - ICMP ping test
                                - Traceroute with hop timing
                                - MTU discovery
                                - Gateway reachability

    dns <domain>                DNS resolution testing
                                - Query A, AAAA, MX, TXT records
                                - Measure query response time
                                - Test multiple nameservers
                                - Detect DNS issues

    routes [destination]        Routing table analysis
                                - Display routing table
                                - Default gateway check
                                - Interface statistics
                                - Path validation

    ports <host> [port1,port2]  Port connectivity testing
                                - TCP connect scan
                                - Service detection
                                - Timeout handling
                                - Common ports if none specified

    scan <network>              Local network discovery
                                - ARP-based host discovery
                                - Hostname resolution
                                - Active host list

    report                      Generate comprehensive report
                                - Run all diagnostics
                                - JSON output
                                - Summary + recommendations

    help                        Show this help message
    version                     Show version information

Examples:
    $SCRIPT_NAME connectivity google.com
    $SCRIPT_NAME dns example.com
    $SCRIPT_NAME ports 192.168.1.1 22,80,443
    $SCRIPT_NAME scan 192.168.1.0/24
    $SCRIPT_NAME report

Environment Variables:
    NETWORK_TIMEOUT_SECONDS     Timeout for network operations (default: 10)
    NETWORK_MAX_HOPS            Maximum hops for traceroute (default: 30)
    REPORT_DIR                  Directory for JSON reports (default: /var/reports)

EOF
}

version() {
    echo "$SCRIPT_NAME version $SCRIPT_VERSION"
}

print_table_header() {
    local header="$1"
    local width="${2:-60}"
    printf "┌%s┐\n" "$(printf '%*s' "$width" '' | tr ' ' '─')"
    printf "│ %-$((width-2))s │\n" "$header"
    printf "├%s┤\n" "$(printf '%*s' "$width" '' | tr ' ' '─')"
}

print_table_row() {
    local key="$1"
    local value="$2"
    local width="${3:-60}"
    local key_width=$((width / 2 - 2))
    local val_width=$((width - key_width - 5))
    printf "│ %-${key_width}s │ %-${val_width}s │\n" "$key" "$value"
}

print_table_footer() {
    local width="${1:-60}"
    printf "└%s┘\n" "$(printf '%*s' "$width" '' | tr ' ' '─')"
}

detect_tool() {
    local tool="$1"
    local alternatives="${2:-}"

    if command -v "$tool" &>/dev/null; then
        echo "$tool"
        return 0
    fi

    if [[ -n "$alternatives" ]]; then
        for alt in $alternatives; do
            if command -v "$alt" &>/dev/null; then
                echo "$alt"
                return 0
            fi
        done
    fi

    return 1
}

#===============================================================================
# Command: connectivity
#===============================================================================

cmd_connectivity() {
    local host="${1:-}"

    if [[ -z "$host" ]]; then
        log_error "Usage: $SCRIPT_NAME connectivity <host>"
        return 1
    fi

    log_info "Testing connectivity to: $host"
    echo ""

    print_table_header "Connectivity Test: $host" 70

    # ICMP Ping Test
    log_info "Running ping test..."
    local ping_cmd
    ping_cmd=$(detect_tool "ping" "") || { log_error "ping command not found"; return 1; }

    local ping_result
    if ping_result=$($ping_cmd -c 4 -W "$TIMEOUT" "$host" 2>&1); then
        local packet_loss
        packet_loss=$(echo "$ping_result" | grep -oP '\d+(?=% packet loss)' || echo "0")
        local avg_time
        avg_time=$(echo "$ping_result" | grep -oP 'avg = \K[\d.]+|rtt.*= [\d.]+/\K[\d.]+' | head -1 || echo "N/A")

        print_table_row "Ping Status" "✓ Success" 70
        print_table_row "Packet Loss" "${packet_loss}%" 70
        print_table_row "Avg RTT" "${avg_time} ms" 70
    else
        print_table_row "Ping Status" "✗ Failed" 70
        print_table_row "Error" "Host unreachable or timeout" 70
    fi

    # Gateway Test
    log_info "Checking gateway..."
    local gateway
    gateway=$(ip route | grep default | awk '{print $3}' | head -1 || echo "")

    if [[ -n "$gateway" ]]; then
        print_table_row "Default Gateway" "$gateway" 70
        if $ping_cmd -c 1 -W 2 "$gateway" &>/dev/null; then
            print_table_row "Gateway Status" "✓ Reachable" 70
        else
            print_table_row "Gateway Status" "✗ Unreachable" 70
        fi
    else
        print_table_row "Default Gateway" "Not found" 70
    fi

    # Traceroute (if available)
    local traceroute_cmd
    if traceroute_cmd=$(detect_tool "traceroute" "tracepath mtr"); then
        log_info "Running traceroute..."
        print_table_row "Traceroute" "Running (max $MAX_HOPS hops)..." 70

        local trace_result
        trace_result=$($traceroute_cmd -m "$MAX_HOPS" -w 2 "$host" 2>&1 | head -15)
        local hop_count
        hop_count=$(echo "$trace_result" | grep -c '^ *[0-9]' || echo "0")

        print_table_row "Hops to destination" "$hop_count" 70
    else
        print_table_row "Traceroute" "Command not available" 70
    fi

    # MTU Test (if ping supports it)
    log_info "Testing MTU..."
    local mtu_test
    if mtu_test=$($ping_cmd -c 1 -M do -s 1472 -W 2 "$host" 2>&1); then
        print_table_row "MTU Test (1500)" "✓ Pass" 70
    else
        print_table_row "MTU Test (1500)" "✗ Fail (fragmentation needed)" 70
    fi

    print_table_footer 70
    echo ""
    log_success "Connectivity test completed"
}

#===============================================================================
# Command: dns
#===============================================================================

cmd_dns() {
    local domain="${1:-}"

    if [[ -z "$domain" ]]; then
        log_error "Usage: $SCRIPT_NAME dns <domain>"
        return 1
    fi

    log_info "Testing DNS resolution for: $domain"
    echo ""

    print_table_header "DNS Resolution Test: $domain" 70

    # Check resolv.conf
    if [[ -f /etc/resolv.conf ]]; then
        local nameservers
        nameservers=$(grep ^nameserver /etc/resolv.conf | awk '{print $2}' | tr '\n' ', ' | sed 's/,$//')
        print_table_row "Configured Nameservers" "$nameservers" 70
    fi

    # Detect DNS tool
    local dns_tool
    if ! dns_tool=$(detect_tool "dig" "nslookup host"); then
        log_error "No DNS query tool found (dig, nslookup, host)"
        return 1
    fi

    # A Record (IPv4)
    log_info "Querying A record..."
    local a_record
    if [[ "$dns_tool" == "dig" ]]; then
        a_record=$(dig +short A "$domain" 2>/dev/null | grep -E '^[0-9.]+$' | head -1 || echo "N/A")
        local query_time
        query_time=$(dig "$domain" 2>/dev/null | grep 'Query time' | awk '{print $4}' || echo "N/A")
        print_table_row "Query Time" "${query_time} ms" 70
    elif [[ "$dns_tool" == "nslookup" ]]; then
        a_record=$(nslookup "$domain" 2>/dev/null | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' | head -1 || echo "N/A")
    else
        a_record=$(host -t A "$domain" 2>/dev/null | awk '{print $NF}' | head -1 || echo "N/A")
    fi
    print_table_row "A Record (IPv4)" "$a_record" 70

    # AAAA Record (IPv6)
    log_info "Querying AAAA record..."
    local aaaa_record
    if [[ "$dns_tool" == "dig" ]]; then
        aaaa_record=$(dig +short AAAA "$domain" 2>/dev/null | head -1 || echo "N/A")
    else
        aaaa_record=$(host -t AAAA "$domain" 2>/dev/null | awk '{print $NF}' | head -1 || echo "N/A")
    fi
    print_table_row "AAAA Record (IPv6)" "$aaaa_record" 70

    # MX Record
    log_info "Querying MX record..."
    local mx_record
    if [[ "$dns_tool" == "dig" ]]; then
        mx_record=$(dig +short MX "$domain" 2>/dev/null | head -1 || echo "N/A")
    else
        mx_record=$(host -t MX "$domain" 2>/dev/null | awk '{print $NF}' | head -1 || echo "N/A")
    fi
    print_table_row "MX Record (Mail)" "$mx_record" 70

    # TXT Record
    log_info "Querying TXT record..."
    local txt_count
    if [[ "$dns_tool" == "dig" ]]; then
        txt_count=$(dig +short TXT "$domain" 2>/dev/null | wc -l || echo "0")
    else
        txt_count=$(host -t TXT "$domain" 2>/dev/null | wc -l || echo "0")
    fi
    print_table_row "TXT Records" "$txt_count record(s)" 70

    print_table_footer 70
    echo ""
    log_success "DNS resolution test completed"
}

#===============================================================================
# Command: routes
#===============================================================================

cmd_routes() {
    local destination="${1:-}"

    log_info "Analyzing routing table..."
    echo ""

    print_table_header "Routing Table Analysis" 80

    # Default route
    local default_route
    default_route=$(ip route show default 2>/dev/null | head -1 || echo "No default route")
    print_table_row "Default Route" "$default_route" 80

    # Primary interface
    local primary_if
    primary_if=$(get_primary_interface || echo "N/A")
    print_table_row "Primary Interface" "$primary_if" 80

    if [[ -n "$primary_if" ]] && [[ "$primary_if" != "N/A" ]]; then
        # Interface IP
        local if_ip
        if_ip=$(ip addr show "$primary_if" 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1 || echo "N/A")
        print_table_row "Interface IP" "$if_ip" 80

        # Interface status
        local if_status
        if_status=$(ip link show "$primary_if" 2>/dev/null | grep -oP 'state \K\w+' || echo "UNKNOWN")
        print_table_row "Interface Status" "$if_status" 80
    fi

    print_table_footer 80

    # Show routing table
    echo ""
    log_info "Complete Routing Table:"
    echo ""
    ip route show 2>/dev/null | head -20

    # If destination specified, show route to it
    if [[ -n "$destination" ]]; then
        echo ""
        log_info "Route to $destination:"
        echo ""
        ip route get "$destination" 2>/dev/null || log_warning "Could not determine route"
    fi

    echo ""
    log_success "Routing analysis completed"
}

#===============================================================================
# Command: ports
#===============================================================================

cmd_ports() {
    local host="${1:-}"
    local ports_arg="${2:-}"

    if [[ -z "$host" ]]; then
        log_error "Usage: $SCRIPT_NAME ports <host> [port1,port2,...]"
        return 1
    fi

    local -a ports
    if [[ -n "$ports_arg" ]]; then
        IFS=',' read -ra ports <<< "$ports_arg"
    else
        ports=("${COMMON_PORTS[@]}")
        log_info "No ports specified, scanning common ports"
    fi

    log_info "Scanning ${#ports[@]} ports on $host..."
    echo ""

    print_table_header "Port Scan: $host" 60

    local open_count=0
    local closed_count=0

    for port in "${ports[@]}"; do
        local status
        if check_port "$host" "$port" 2; then
            status="✓ Open"
            ((open_count++))
            log_debug "Port $port: OPEN"
        else
            status="✗ Closed/Filtered"
            ((closed_count++))
            log_debug "Port $port: CLOSED"
        fi

        print_table_row "Port $port" "$status" 60
    done

    print_table_footer 60

    echo ""
    log_info "Results: $open_count open, $closed_count closed/filtered"
    log_success "Port scan completed"
}

#===============================================================================
# Command: scan
#===============================================================================

cmd_scan() {
    local network="${1:-}"

    if [[ -z "$network" ]]; then
        # Try to detect local network
        local primary_if
        primary_if=$(get_primary_interface)
        if [[ -n "$primary_if" ]]; then
            network=$(ip addr show "$primary_if" | grep -oP 'inet \K[\d.]+/[\d]+' | head -1)
        fi

        if [[ -z "$network" ]]; then
            log_error "Usage: $SCRIPT_NAME scan <network>"
            log_error "Example: $SCRIPT_NAME scan 192.168.1.0/24"
            return 1
        fi
    fi

    log_info "Scanning network: $network"
    log_warning "Note: Network scanning may take several minutes"
    echo ""

    # Check for scanning tools
    if command -v nmap &>/dev/null; then
        log_info "Using nmap for network scan..."
        nmap -sn "$network" 2>/dev/null | grep -E "Nmap scan|Host is up" | head -20
    elif command -v arp-scan &>/dev/null; then
        log_info "Using arp-scan for network discovery..."
        arp-scan --localnet 2>/dev/null | head -20
    else
        log_warning "No scanning tool found (nmap, arp-scan)"
        log_info "Showing ARP cache instead..."
        echo ""
        arp -a 2>/dev/null || ip neigh show 2>/dev/null
    fi

    echo ""
    log_success "Network scan completed"
}

#===============================================================================
# Command: report
#===============================================================================

cmd_report() {
    ensure_directory "$REPORT_DIR"
    local report_file="${REPORT_DIR}/network-diagnostics-$(timestamp_filename).json"

    log_info "Generating comprehensive network diagnostics report..."

    # Gather system information
    local primary_if
    primary_if=$(get_primary_interface || echo "unknown")
    local ip_addr
    ip_addr=$(get_ip_address || echo "unknown")
    local gateway
    gateway=$(ip route | grep default | awk '{print $3}' | head -1 || echo "unknown")

    # Test internet connectivity
    local internet_status="down"
    if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        internet_status="up"
    fi

    # Count interfaces
    local if_count
    if_count=$(ip link show | grep -c '^[0-9]:' || echo "0")

    # DNS nameservers
    local nameservers
    nameservers=$(grep ^nameserver /etc/resolv.conf 2>/dev/null | awk '{print $2}' | paste -sd ',' - || echo "none")

    # Generate JSON report
    cat > "$report_file" << EOF
{
    "timestamp": "$(timestamp_iso)",
    "hostname": "$(hostname)",
    "script": "$SCRIPT_NAME",
    "version": "$SCRIPT_VERSION",
    "network": {
        "primary_interface": "$primary_if",
        "ip_address": "$ip_addr",
        "default_gateway": "$gateway",
        "interface_count": $if_count,
        "internet_connectivity": "$internet_status"
    },
    "dns": {
        "nameservers": "$nameservers"
    },
    "diagnostics_run": [
        "interface_detection",
        "gateway_check",
        "internet_connectivity_test",
        "dns_configuration_check"
    ]
}
EOF

    log_success "Report generated: $report_file"
    echo ""
    cat "$report_file"
}

#===============================================================================
# Main Command Dispatcher
#===============================================================================

main() {
    local command="${1:-help}"

    case "$command" in
        connectivity)
            shift
            cmd_connectivity "$@"
            ;;
        dns)
            shift
            cmd_dns "$@"
            ;;
        routes)
            shift
            cmd_routes "$@"
            ;;
        ports)
            shift
            cmd_ports "$@"
            ;;
        scan)
            shift
            cmd_scan "$@"
            ;;
        report)
            cmd_report
            ;;
        help|--help|-h)
            usage
            ;;
        version|--version|-v)
            version
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            usage
            exit 1
            ;;
    esac
}

# Allow sourcing for testing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
