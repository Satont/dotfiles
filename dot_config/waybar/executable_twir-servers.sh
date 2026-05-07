#!/bin/bash

# Configuration: Add your server Usernames and IPs here
# Format: "user@ip|Label"
SERVERS=(
    "twir-traefik-1|Traefik"
    "twir-microservices-1|Microservices 1"
    "twir-databases-1|Databases-1"
)


# Icons
ICON_CPU="󰻠"
ICON_RAM="󰍛"

# Function to get stats via SSH
# Note: 2>/dev/null is added to suppress SSH errors
get_stats() {
    local server=$1
    # timeout command ensures the script doesn't hang if a server is dead
    timeout 2 ssh -o ConnectTimeout=1 -o StrictHostKeyChecking=no "$server" bash -s 2>/dev/null << 'EOF'
        # Get CPU Load (1 min avg) * 100 for percentage
        # Adjust the divisor (e.g., / 4) if you have a 4-core CPU for accurate usage %
        read -r one five fifteen rest < /proc/loadavg
        # Treating Load 1.0 as 100%. For multi-core, divide by cores here.
        cpu_load=$(awk "BEGIN {printf \"%.0f\", ($one * 100)}")

        # Get RAM Usage
        # MemTotal, MemFree, Buffers, Cached
        read -r _ total _ < /proc/meminfo
        read -r _ free _ < /proc/meminfo
        read -r _ buffers _ < /proc/meminfo
        read -r _ cached _ < /proc/meminfo
        
        # Calculate Used RAM (Total - Free - Buffers - Cached)
        used_mem=$((total - free - buffers - cached))
        ram_percent=$(awk "BEGIN {printf \"%.0f\", ($used_mem / $total * 100)}")

        echo "$cpu_load $ram_percent"
EOF
}

# Build the JSON Array
json_array=""
first=true

for server_info in "${SERVERS[@]}"; do
    IFS="|" read -r conn label <<< "$server_info"
    
    # Fetch stats (errors from SSH/command are suppressed inside the function)
    stats=$(get_stats "$conn")
    
    if [ -n "$stats" ]; then
        IFS=" " read -r cpu ram <<< "$stats"
        
        text="${label}: ${ICON_CPU} ${cpu}% ${ICON_RAM} ${ram}%"
        # Create a safe CSS class name (lowercase, no spaces)
        css_class="server-$(echo "$label" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
    else
        # If stats are empty (connection failed/timeout)
        text="${label}: OFF"
        css_class="server-offline"
    fi

    # Append to JSON string
    # We escape quotes in text just in case, though unlikely here
    escaped_text=$(echo "$text" | sed 's/"/\\"/g')

    if [ "$first" = true ]; then
        json_array="{\"text\": \"$escaped_text\", \"class\": \"$css_class\", \"tooltip\": \"$conn\"}"
        first=false
    else
        json_array="$json_array, {\"text\": \" | $escaped_text\", \"class\": \"$css_class\", \"tooltip\": \"$conn\"}"
    fi
done

# Print the final JSON array
echo "[$json_array]"
