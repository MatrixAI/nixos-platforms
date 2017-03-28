#!/usr/bin/env bash

# This script requires:
#   awk - gawk
#   last - utillinux
#   users - coreutils
#   cat - coreutils
#   ps - procps
#   grep - coreutils
#   head - coreutils
#   sed - gnused
#   date - coreutils
#   uname - coreutils
#   whoami - coreuils
#   hostname - nettools
#   uptime - coreutils
#   free - procps
#   df - coreutils
#   ip - iproute2
#   tput - ncurses
# Make sure the above commands are available when matrix-status is executed.
# 
# This script is ZSH compatible

# This indents a block of strings given the number of whitespace
space-indent () {
    while read -r line; do
        whitespace="$(printf "%${1}s")"
        printf "${whitespace}${line}\n"
    done
}

matrix-status () {

    # General information
    local current_user \
          host_name \
          version \
          kernel \
          current_time \
          current_date_human_readable

    current_user="$(whoami)"
    host_name="$(hostname)"
    version="$(grep --max-count=1 'VERSION' /etc/os-release | sed 's/.*="\(.*\)"/\1/')"
    kernel="$(uname --kernel-name --kernel-release --operating-system --machine)"
    current_time="$(date +%s)"
    current_date_human_readable="$(date -d @"$current_time")"

    # Get the last login session
    local last_login

    last_login="$(last --fulltimes --ip --limit 2 "$current_user" | sed --quiet '2p')" # sed gets the 2nd line
    if [ -n "$last_login" ]; then
        last_login=$(awk '{print $6, $4, $5, $7, $8, "-", $12, $10, $11, $13, $14, $15, "from", $3, $2}' <<< "$last_login" )
    else
        last_login='just now.'
    fi

    # Users
    local current_users \
          current_users_number

    current_users="$(users)"
    current_users_number="$(users | wc --words)"

    # Uptime (GNU coreutils uptime is pretty basic)
    local uptime_length \
          uptime_since \
          days \
          hours \
          minutes \
          seconds \

    uptime_length="$(awk '{print $1}' /proc/uptime | cut --delimiter='.' --fields=1)"
    uptime_since="$(date --date="@$(( current_time - uptime_length ))")"
    days=$(( uptime_length/60/60/24 ))
    hours=$(( uptime_length/60/60%24 ))
    minutes=$(( uptime_length/60%60 ))
    seconds=$(( uptime_length%60 ))
    uptime_length='up'
    if [[ $days -ne 0 ]]; then
        if [[ $days -gt 1 ]]; then
            uptime_length=$uptime_length" $days days,"
        else
            uptime_length=$uptime_length" $days day,"
        fi
    fi
    if [[ $hours -ne 0 ]]; then
        if [[ $hours -gt 1 ]]; then
            uptime_length=$uptime_length" $hours hours,"
        else
            uptime_length=$uptime_length" $hours hour,"
        fi
    fi
    if [[ $minutes -ne 0 ]]; then
        if [[ $minutes -gt 1 ]]; then
            uptime_length=$uptime_length" $minutes minutes,"
        else
            uptime_length=$uptime_length" $minutes minute,"
        fi
    fi
    if [[ $seconds -ne 0 ]]; then
        if [[ $seconds -gt 1 ]]; then
            uptime_length=$uptime_length" $seconds seconds"
        else
            uptime_length=$uptime_length" $seconds second"
        fi
    fi

    # Process Count
    # Ignores the 4 measuring processes: bash, subshell, ps and wc
    local process_count \
          total_process_count

    process_count=$(( $(ps --no-headers | wc --lines) - 4 ))
    total_process_count=$(( $(ps -A --no-headers | wc --lines) - 4 ))

    # CPU
    local cpu_number \
          cpu_type \
          cpu_usage \
          load

    cpu_number=$(nproc)
    cpu_type="$(grep 'model name' /proc/cpuinfo | sed 's/.*: \(.*\)/\1/' | head --lines 1)"
    cpu_usage="$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%0.2f", usage}')"
    load="$(uptime | sed 's/.*load average: \(.*\)/\1/')"

    # Memory Percentage (in binary)
    local total_memory \
          used_memory \
          memory_usage

    read total_memory used_memory <<< "$(free --bytes | grep Mem | awk '{print $2, $3}')"
    memory_usage=$(( used_memory*100/total_memory ))

    # Memory (in human readable binary)
    local total_memory_h \
          used_memory_h \
          free_memory_h
    
    read total_memory_h used_memory_h free_memory_h <<< "$(free --human | grep Mem | awk '{print $2, $3, $4}')"

    # Swap Percentage (in binary)
    local total_swap \
          used_swap \
          swap_usage

    read total_swap used_swap <<< "$(free --bytes | grep Swap | awk '{print $2, $3}')"
    if [ "$total_swap" = 0 ]; then
        swap_usage=0
    else
        swap_usage=$(( used_swap*100/total_swap ))
    fi

    # Swap (in human readable binary)
    local total_swap_h \
          used_swap_h \
          free_swap_h

    read total_swap_h used_swap_h free_swap_h <<< "$(free --human | grep Swap | awk '{print $2, $3, $4}')"

    # Storage (in human readable binary)
    local total_disk \
          used_disk \
          free_disk \
          disk_usage

    read total_disk used_disk free_disk disk_usage <<< "$(df --local --human-readable | awk '{if ($6 == "/") { print $2, $3, $4, $5 }}' | head --lines 1)"

    # Tabular IP information
    local ip_status

    ip_status="$(ip -o addr | awk 'BEGIN {  printf "%-12s %-12s %-12s\n", "Interface", "Protocol", "Address"
                                            printf "%-12s %-12s %-12s\n", "---------", "--------", "-------" }
                                         {  printf "%-12s %-12s %-12s\n", $2, $3, $4 }')"

    # Colours & Styling
    local esc="\x1b["
    local creset=$esc"39;49;00m"
    local red=$esc"31;01m"
    local green=$esc"32;01m"
    local yellow=$esc"33;01m"
    local blue=$esc"34;01m"
    local magenta=$esc"35;01m"
    local cyan=$esc"36;01m"
    local white=$esc"01;37m"
    local tunder="$(tput sgr 0 1)"
    local treset="$(tput sgr0)"

    # Display the information! All data size units are in binary form, not SI.
    echo -e "
    ${white}Hello ${yellow}${current_user}${white}! Welcome to ${yellow}${host_name} ${version} ${white}(${yellow}${kernel}${white})${creset}

    ${white}Your last login was ${yellow}${last_login}${creset}

    ${white}System information as of ${yellow}$current_date_human_readable${creset}:

        ${tunder}${yellow}SitRep${creset}${treset}

          ${green}* Users:      ${blue}${current_users_number} Online ${green}- ${blue}${current_users}${creset}
          ${green}* Uptime:     ${blue}${load} ${green}- ${blue}${uptime_length} since ${uptime_since}${creset}
          ${green}* Processes:  ${blue}User $process_count ${green}/ ${blue}Total ${total_process_count}${creset}
          ${green}* CPU:        ${blue}${cpu_usage}% ${green}- ${blue}${cpu_number}x ${cpu_type}${creset}
          ${green}* Memory:     ${blue}${memory_usage}% ${green}- ${blue}Free $free_memory_h ${green}|| ${blue}Used $used_memory_h ${green}|| ${blue}Total $total_memory_h${creset}
          ${green}* Swap:       ${blue}${swap_usage}% ${green}- ${blue}Free $free_swap_h ${green}|| ${blue}Used $used_swap_h ${green}|| ${blue}Total $total_swap_h${creset}
          ${green}* Storage:    ${blue}${disk_usage} ${green}- ${blue}Free $free_disk ${green}|| ${blue}Used $used_disk ${green}|| ${blue}Total ${total_disk}${creset}
    ${green}"
    echo -e "$(space-indent 12 <<< "$ip_status")"
    echo -e "${creset}
    ${white}You can access this information later by running \`${magenta}matrix-status${white}\`${creset}
    "

}

matrix-motd () {

    echo -e "\x1b[36;01m

    ███╗   ███╗     █████╗     ████████╗    ██████╗     ██╗    ██╗  ██╗
    ████╗ ████║    ██╔══██╗    ╚══██╔══╝    ██╔══██╗    ██║    ╚██╗██╔╝
    ██╔████╔██║    ███████║       ██║       ██████╔╝    ██║     ╚███╔╝
    ██║╚██╔╝██║    ██╔══██║       ██║       ██╔══██╗    ██║     ██╔██╗
    ██║ ╚═╝ ██║    ██║  ██║       ██║       ██║  ██║    ██║    ██╔╝ ██╗
    ╚═╝     ╚═╝    ╚═╝  ╚═╝       ╚═╝       ╚═╝  ╚═╝    ╚═╝    ╚═╝  ╚═╝
    "

    matrix-status

}
