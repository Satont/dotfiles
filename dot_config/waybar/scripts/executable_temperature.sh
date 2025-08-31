#!/bin/bash

# Temperature thresholds
CPU_WARNING=70
CPU_CRITICAL=85
GPU_WARNING=75
GPU_CRITICAL=90
NVME_WARNING=70
NVME_CRITICAL=80

# Get main CPU temperature for display
cpu_temp_raw=$(sensors k10temp-pci-00c3 | grep 'Tctl:' | awk '{print $2}' | sed 's/+//g' | sed 's/°C//g')
cpu_temp=${cpu_temp_raw%.*}  # Remove decimal part

# Get CPU frequency information with improved error handling
get_cpu_freq() {
    # Try multiple methods to get CPU frequency
    local freq=""

    # Method 1: Use /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq
    if [[ -f "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq" ]]; then
        freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
        if [[ -n "$freq" && "$freq" != "0" ]]; then
            echo "scale=2; $freq / 1000" | bc 2>/dev/null || awk "BEGIN {printf \"%.2f\", $freq/1000}"
            return
        fi
    fi

    # Method 2: Use /proc/cpuinfo
    freq=$(grep "cpu MHz" /proc/cpuinfo | head -1 | awk '{print $4}' 2>/dev/null)
    if [[ -n "$freq" && "$freq" != "0" ]]; then
        echo "scale=2; $freq / 1000" | bc 2>/dev/null || awk "BEGIN {printf \"%.2f\", $freq/1000}"
        return
    fi

    # Method 3: Use lscpu
    freq=$(lscpu | grep "CPU MHz" | awk '{print $3}' 2>/dev/null)
    if [[ -n "$freq" && "$freq" != "0" ]]; then
        echo "scale=2; $freq / 1000" | bc 2>/dev/null || awk "BEGIN {printf \"%.2f\", $freq/1000}"
        return
    fi

    echo "N/A"
}

get_cpu_max_freq() {
    local max_freq=""

    # Method 1: Use cpufreq max frequency
    if [[ -f "/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq" ]]; then
        max_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)
        if [[ -n "$max_freq" && "$max_freq" != "0" ]]; then
            echo "scale=2; $max_freq / 1000" | bc 2>/dev/null || awk "BEGIN {printf \"%.2f\", $max_freq/1000}"
            return
        fi
    fi

    # Method 2: Use lscpu
    max_freq=$(lscpu | grep "CPU max MHz" | awk '{print $4}' 2>/dev/null)
    if [[ -n "$max_freq" && "$max_freq" != "0" ]]; then
        echo "scale=2; $max_freq / 1000" | bc 2>/dev/null || awk "BEGIN {printf \"%.2f\", $max_freq/1000}"
        return
    fi

    echo "N/A"
}

cpu_freq_current_ghz=$(get_cpu_freq)
cpu_freq_max_ghz=$(get_cpu_max_freq)

# Determine status and class based on highest temperature
max_temp=0
status_class="normal"
status_icon=""

# Function to update max temperature and status
update_status() {
    local temp=$1
    local warning_threshold=$2
    local critical_threshold=$3

    if [[ $temp -gt $max_temp ]]; then
        max_temp=$temp
    fi

    if [[ $temp -ge $critical_threshold ]]; then
        status_class="critical"
        status_icon="󰚽 "
    elif [[ $temp -ge $warning_threshold && $status_class != "critical" ]]; then
        status_class="warning"
        status_icon="󰀦 "
    elif [[ $status_class == "normal" ]]; then
        status_icon=""
    fi
}

# Collect all temperatures and frequencies for tooltip
tooltip=" System Information:\\n\\n"

# CPU frequencies
tooltip+="⚡ CPU Frequencies:\\n"
tooltip+=" • Current: ${cpu_freq_current_ghz} GHz\\n"
if [[ "$cpu_freq_max_ghz" != "N/A" ]]; then
    tooltip+=" • Maximum: ${cpu_freq_max_ghz} GHz\\n"
fi

# Per-core frequencies with improved handling
tooltip+="\\n⚡ Per-Core Frequencies:\\n"
core_count=0
max_cores_to_show=4

# Use /sys filesystem for more accurate per-core frequencies
for cpu_dir in /sys/devices/system/cpu/cpu[0-9]*; do
    if [[ -f "$cpu_dir/cpufreq/scaling_cur_freq" ]]; then
        core_freq_khz=$(cat "$cpu_dir/cpufreq/scaling_cur_freq" 2>/dev/null)
        if [[ -n "$core_freq_khz" && "$core_freq_khz" != "0" ]]; then
            core_freq_ghz=$(echo "scale=2; $core_freq_khz / 1000" | bc 2>/dev/null || awk "BEGIN {printf \"%.2f\", $core_freq_khz/1000}")
            tooltip+=" • Core $core_count: ${core_freq_ghz} GHz\\n"
        else
            tooltip+=" • Core $core_count: N/A\\n"
        fi
        ((core_count++))
        if [[ $core_count -ge $max_cores_to_show ]]; then
            remaining_cores=$(($(nproc) - $max_cores_to_show))
            if [[ $remaining_cores -gt 0 ]]; then
                tooltip+=" • ... and $remaining_cores more cores\\n"
            fi
            break
        fi
    fi
done

# Fallback to /proc/cpuinfo if /sys method failed
if [[ $core_count -eq 0 ]]; then
    while IFS= read -r line; do
        if [[ $line == *"cpu MHz"* ]]; then
            core_freq=$(echo "$line" | awk '{print $4}')
            if [[ -n "$core_freq" && "$core_freq" != "0" ]]; then
                core_freq_ghz=$(echo "scale=2; $core_freq / 1000" | bc 2>/dev/null || awk "BEGIN {printf \"%.2f\", $core_freq/1000}")
                tooltip+=" • Core $core_count: ${core_freq_ghz} GHz\\n"
            else
                tooltip+=" • Core $core_count: N/A\\n"
            fi
            ((core_count++))
            if [[ $core_count -ge $max_cores_to_show ]]; then
                remaining_cores=$(($(nproc) - $max_cores_to_show))
                if [[ $remaining_cores -gt 0 ]]; then
                    tooltip+=" • ... and $remaining_cores more cores\\n"
                fi
                break
            fi
        fi
    done < <(cat /proc/cpuinfo)
fi

# CPU temperatures (k10temp)
tooltip+="\\n🌡️ CPU Temperatures:\\n"
while IFS= read -r line; do
    if [[ $line == *"Tctl:"* ]]; then
        temp=$(echo "$line" | awk '{print $2}')
        temp_num=${temp%.*}
        temp_num=${temp_num#+}
        temp_num=${temp_num%°C}
        update_status $temp_num $CPU_WARNING $CPU_CRITICAL

        # Add warning/critical indicators
        if [[ $temp_num -ge $CPU_CRITICAL ]]; then
            tooltip+=" • Tctl: $temp 🔥 CRITICAL\\n"
        elif [[ $temp_num -ge $CPU_WARNING ]]; then
            tooltip+=" • Tctl: $temp ⚠️ WARNING\\n"
        else
            tooltip+=" • Tctl: $temp\\n"
        fi
    elif [[ $line == *"Tccd"* ]]; then
        label=$(echo "$line" | awk '{print $1}')
        temp=$(echo "$line" | awk '{print $2}')
        temp_num=${temp%.*}
        temp_num=${temp_num#+}
        temp_num=${temp_num%°C}
        update_status $temp_num $CPU_WARNING $CPU_CRITICAL

        if [[ $temp_num -ge $CPU_CRITICAL ]]; then
            tooltip+=" • $label: $temp 🔥 CRITICAL\\n"
        elif [[ $temp_num -ge $CPU_WARNING ]]; then
            tooltip+=" • $label: $temp ⚠️ WARNING\\n"
        else
            tooltip+=" • $label: $temp\\n"
        fi
    fi
done < <(sensors k10temp-pci-00c3 2>/dev/null)

# GPU information (остальная часть скрипта остается без изменений)
gpu_found=false
tooltip+="\\n🎮 Graphics Card:\\n"

# Check for NVIDIA GPU
if command -v nvidia-smi &> /dev/null; then
    gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null)
    gpu_freq_current=$(nvidia-smi --query-gpu=clocks.current.graphics --format=csv,noheader,nounits 2>/dev/null)
    gpu_freq_max=$(nvidia-smi --query-gpu=clocks.max.graphics --format=csv,noheader,nounits 2>/dev/null)
    gpu_mem_freq_current=$(nvidia-smi --query-gpu=clocks.current.memory --format=csv,noheader,nounits 2>/dev/null)
    gpu_mem_freq_max=$(nvidia-smi --query-gpu=clocks.max.memory --format=csv,noheader,nounits 2>/dev/null)

    if [[ -n "$gpu_temp" ]]; then
        # GPU frequencies
        if [[ -n "$gpu_freq_current" ]]; then
            tooltip+=" • GPU Clock: ${gpu_freq_current} MHz"
            if [[ -n "$gpu_freq_max" ]]; then
                tooltip+=" (Max: ${gpu_freq_max} MHz)"
            fi
            tooltip+="\\n"
        fi

        if [[ -n "$gpu_mem_freq_current" ]]; then
            tooltip+=" • Memory Clock: ${gpu_mem_freq_current} MHz"
            if [[ -n "$gpu_mem_freq_max" ]]; then
                tooltip+=" (Max: ${gpu_mem_freq_max} MHz)"
            fi
            tooltip+="\\n"
        fi

        # GPU temperature
        update_status $gpu_temp $GPU_WARNING $GPU_CRITICAL

        if [[ $gpu_temp -ge $GPU_CRITICAL ]]; then
            tooltip+=" • Temperature: +${gpu_temp}°C 🔥 CRITICAL\\n"
        elif [[ $gpu_temp -ge $GPU_WARNING ]]; then
            tooltip+=" • Temperature: +${gpu_temp}°C ⚠️ WARNING\\n"
        else
            tooltip+=" • Temperature: +${gpu_temp}°C\\n"
        fi
        gpu_found=true
    fi
fi

# Check for AMD GPU (amdgpu)
if ! $gpu_found; then
    # Try to get AMD GPU frequencies from sysfs
    for card in /sys/class/drm/card*; do
        if [[ -f "$card/gt_act_freq_mhz" ]]; then
            gpu_freq_current=$(cat "$card/gt_act_freq_mhz" 2>/dev/null)
            gpu_freq_max=$(cat "$card/gt_max_freq_mhz" 2>/dev/null)

            if [[ -n "$gpu_freq_current" ]]; then
                tooltip+=" • GPU Clock: ${gpu_freq_current} MHz"
                if [[ -n "$gpu_freq_max" ]]; then
                    tooltip+=" (Max: ${gpu_freq_max} MHz)"
                fi
                tooltip+="\\n"
                break
            fi
        fi
    done

    # AMD GPU temperatures
    while IFS= read -r line; do
        if [[ $line == *"edge:"* ]]; then
            temp=$(echo "$line" | awk '{print $2}')
            temp_num=${temp%.*}
            temp_num=${temp_num#+}
            temp_num=${temp_num%°C}
            update_status $temp_num $GPU_WARNING $GPU_CRITICAL

            if [[ $temp_num -ge $GPU_CRITICAL ]]; then
                tooltip+=" • GPU Edge: $temp 🔥 CRITICAL\\n"
            elif [[ $temp_num -ge $GPU_WARNING ]]; then
                tooltip+=" • GPU Edge: $temp ⚠️ WARNING\\n"
            else
                tooltip+=" • GPU Edge: $temp\\n"
            fi
            gpu_found=true
        elif [[ $line == *"junction:"* ]]; then
            temp=$(echo "$line" | awk '{print $2}')
            temp_num=${temp%.*}
            temp_num=${temp_num#+}
            temp_num=${temp_num%°C}
            update_status $temp_num $GPU_WARNING $GPU_CRITICAL

            if [[ $temp_num -ge $GPU_CRITICAL ]]; then
                tooltip+=" • GPU Junction: $temp 🔥 CRITICAL\\n"
            elif [[ $temp_num -ge $GPU_WARNING ]]; then
                tooltip+=" • GPU Junction: $temp ⚠️ WARNING\\n"
            else
                tooltip+=" • GPU Junction: $temp\\n"
            fi
        elif [[ $line == *"mem:"* ]]; then
            temp=$(echo "$line" | awk '{print $2}')
            temp_num=${temp%.*}
            temp_num=${temp_num#+}
            temp_num=${temp_num%°C}
            update_status $temp_num $GPU_WARNING $GPU_CRITICAL

            if [[ $temp_num -ge $GPU_CRITICAL ]]; then
                tooltip+=" • GPU Memory: $temp 🔥 CRITICAL\\n"
            elif [[ $temp_num -ge $GPU_WARNING ]]; then
                tooltip+=" • GPU Memory: $temp ⚠️ WARNING\\n"
            else
                tooltip+=" • GPU Memory: $temp\\n"
            fi
        fi
    done < <(sensors amdgpu-pci-* 2>/dev/null)
fi

# If no dedicated GPU found
if ! $gpu_found; then
    tooltip+=" • No dedicated GPU detected\\n"
fi

# NVMe SSD temperatures
tooltip+="\\n💾 NVMe Storage:\\n"
while IFS= read -r line; do
    if [[ $line == *"Composite:"* ]]; then
        temp=$(echo "$line" | awk '{print $2}')
        temp_num=${temp%.*}
        temp_num=${temp_num#+}
        temp_num=${temp_num%°C}
        update_status $temp_num $NVME_WARNING $NVME_CRITICAL

        if [[ $temp_num -ge $NVME_CRITICAL ]]; then
            tooltip+=" • Composite: $temp 🔥 CRITICAL\\n"
        elif [[ $temp_num -ge $NVME_WARNING ]]; then
            tooltip+=" • Composite: $temp ⚠️ WARNING\\n"
        else
            tooltip+=" • Composite: $temp\\n"
        fi
    elif [[ $line == *"Sensor 1:"* ]]; then
        temp=$(echo "$line" | awk '{print $3}')
        temp_num=${temp%.*}
        temp_num=${temp_num#+}
        temp_num=${temp_num%°C}
        update_status $temp_num $NVME_WARNING $NVME_CRITICAL

        if [[ $temp_num -ge $NVME_CRITICAL ]]; then
            tooltip+=" • Sensor 1: $temp 🔥 CRITICAL\\n"
        elif [[ $temp_num -ge $NVME_WARNING ]]; then
            tooltip+=" • Sensor 1: $temp ⚠️ WARNING\\n"
        else
            tooltip+=" • Sensor 1: $temp\\n"
        fi
    elif [[ $line == *"Sensor 2:"* ]]; then
        temp=$(echo "$line" | awk '{print $3}')
        temp_num=${temp%.*}
        temp_num=${temp_num#+}
        temp_num=${temp_num%°C}
        update_status $temp_num $NVME_WARNING $NVME_CRITICAL

        if [[ $temp_num -ge $NVME_CRITICAL ]]; then
            tooltip+=" • Sensor 2: $temp 🔥 CRITICAL\\n"
        elif [[ $temp_num -ge $NVME_WARNING ]]; then
            tooltip+=" • Sensor 2: $temp ⚠️ WARNING\\n"
        else
            tooltip+=" • Sensor 2: $temp\\n"
        fi
    fi
done < <(sensors nvme-pci-0100 2>/dev/null)

# Add temperature thresholds info
tooltip+="\\n📊 Temperature Thresholds:\\n"
tooltip+=" • CPU: Warning >${CPU_WARNING}°C, Critical >${CPU_CRITICAL}°C\\n"
tooltip+=" • GPU: Warning >${GPU_WARNING}°C, Critical >${GPU_CRITICAL}°C\\n"
tooltip+=" • NVMe: Warning >${NVME_WARNING}°C, Critical >${NVME_CRITICAL}°C\\n"

# Output JSON with status class for CSS styling
echo "{\"text\":\"${status_icon}${cpu_temp_raw}\", \"tooltip\":\"$tooltip\", \"class\":\"$status_class\"}"
