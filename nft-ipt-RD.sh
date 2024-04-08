#!/bin/bash

# Check and create /etc/iptables directory if not exists
if [[ ! -d "/etc/iptables" ]]; then
    mkdir -p /etc/iptables/
fi

# Check if nftables is installed
if [[ -f /etc/nftables.conf ]]; then
    echo "----------------------------------------------------"
    echo "******************* nftables 已安装 *******************"
else
    echo "----------------------------------------------------"
    echo "******************* nftables 未安装 *******************"
fi

# Check if iptables is installed
if whereis iptables | grep -q '/usr/sbin/iptables'; then
    echo "----------------------------------------------------"
    echo "******************* iptables 已安装 *******************"
    echo "----------------------------------------------------"
else
    echo "----------------------------------------------------"
    echo "******************* iptables 未安装 *******************"
    echo "----------------------------------------------------"
fi


# Function to validate IP address format
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate port range
validate_port() {
    local port=$1
    if [[ $port =~ ^[0-9]+$ && $port -ge 0 && $port -le 65535 ]]; then
        return 0
    else
        return 1
    fi
}

# Check if IP forwarding is enabled
if grep -q "net.ipv4.ip_forward = 1" /etc/sysctl.conf; then
    # Disable IP forwarding
    sed -i '/net.ipv4.ip_forward = 1/d' /etc/sysctl.conf
    sysctl -p > /dev/null
    echo "IP forwarding disabled successfully."
else
    # Enable IP forwarding
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sysctl -p > /dev/null
    echo "IP forwarding enabled successfully."
fi

# Main menu
while true; do
    echo "## 如果使用ufw,避免冲突,请systemctl stop ufw && systemctl disable ufw ！"
    echo "Choose firewall tool to use:"
    echo "1. Use 使用 nftables"
    echo "2. Use 使用 iptables"
    read choice

    case $choice in
        1)
            # Check if nftables is installed
if [ -e "/etc/nftables.conf" ]; then
    echo "正在使用nftables."
else
    # 安装nftables
    apt install -y nftables

    # 启用并启动nftables服务
    systemctl enable nftables
    systemctl start nftables

    echo "nftables installed and started."
fi

            # Level 1 menu for nftables
            while true; do
                echo "nftables:"
                echo "1: 配置端口转发 Configure port forwarding"
                echo "2: 管理端口转发 Manage port forwarding"
                echo "c: 退出 Exit"
                read -p "Choose action: " choice
                
                case $choice in
                    1)
                        # Validate and prompt for input
                        while true; do
                            read -p " 请输入本机端口(非落地) Enter local port (range: 0-65535): " local_port
                            if validate_port $local_port; then
                                break
                            else
                                echo "Invalid port, please try again!"
                            fi
                        done

                        while true; do
                            read -p " 请输入本机ip Enter local IP address (e.g.: 192.168.1.100): " local_ip
                            if validate_ip $local_ip; then
                                break
                            else
                                echo "Invalid IP format, please try again!"
                            fi
                        done

                        while true; do
                            read -p " 请输入落地端口 Enter remote port (range: 0-65535): " remote_port
                            if validate_port $remote_port; then
                                break
                            else
                                echo "Invalid port, please try again!"
                            fi
                        done

                        while true; do
                            read -p " 请输入落地ip Enter remote IP (e.g.: 192.168.1.2): " remote_ip
                            if validate_ip $remote_ip; then
                                break
                            else
                                echo "Invalid IP format, please try again!"
                            fi
                        done

                        # Generate config file content
                        config="table ip nat {
                            chain PREROUTING {
                                type nat hook prerouting priority -100;
                                tcp dport $local_port counter dnat to $remote_ip:$remote_port
                                udp dport $local_port counter dnat to $remote_ip:$remote_port
                            }
                            chain POSTROUTING {
                                type nat hook postrouting priority 100;
                                ip daddr $remote_ip tcp dport $remote_port counter snat to $local_ip
                                ip daddr $remote_ip udp dport $remote_port counter snat to $local_ip
                            }
                        }"

                                               # Write config file
                        echo "$config" > /etc/nftables/nat.nft

                        # Check if config file was successfully written
                        if [ -f "/etc/nftables/nat.nft" ]; then
                            # Include config file in nftables.conf
                            if ! grep -q 'include "/etc/nftables/nat.nft"' /etc/nftables.conf; then
                                echo 'include "/etc/nftables/nat.nft"' >> /etc/nftables.conf
                            fi

                            # Check nftables status and start or restart
                            if systemctl is-active --quiet nftables; then
                                systemctl restart nftables
                            else
                                systemctl start nftables
                            fi
                        else
                            echo "Failed to write config file to /etc/nftables/nat.nft"
                        fi


                        # Check nftables status and start or restart
                        if systemctl is-active --quiet nftables; then
                            systemctl restart nftables
                        else
                            systemctl start nftables
                        fi
                        ;;
                    2)
                        # Level 2 menu for nftables
                        while true; do
                            echo "nftables:"
                            echo "1: 查看所有规则 View rules"
                            echo "2: 清理端口转发 Clear port forwarding"
                            echo "3: 删除端口转发 Delete port forwarding"
                            echo "4: 重新创建 Recreate"
                            echo "b: 返回菜单 Back to menu"
                            echo "c: 退出 Exit"
                            read -p "Choose action: " choice2
                            
                            case $choice2 in
                                1) nft list ruleset ;;
                                2) 
                                    nft delete table ip nat
                                    sed -i '/include "\/etc\/nftables\/nat.nft"/d' /etc/nftables.conf
                                    systemctl restart nftables 
                                    ;;
                                3) 
                                    rm /etc/nftables/nat.nft
                                    sed -i '/include "\/etc\/nftables\/nat.nft"/d' /etc/nftables.conf
                                    systemctl restart nftables
                                    ;;
                                4)
                                    if [ -f "/etc/nftables/nat.nft" ]; then
                                        echo "Config file already exists, please execute 3 first."
                                        continue
                                    else
                                        $0
                                    fi
                                    ;;
                                b) 
                                    break ;;
                                c) 
                                    echo "Exiting script." 
                                    exit 0 
                                    ;;
                                *) 
                                    echo "Invalid choice, please try again." 
                                    ;;
                            esac
                        done
                        ;;
                    c) 
                        echo "Exiting script." 
                        exit 0 
                        ;;
                    *) 
                        echo "Invalid choice, please try again." 
                        ;;
                esac
            done
            ;;
        2)
           # Check if iptables is installed
if whereis iptables | grep -q '/usr/sbin/iptables'; then
    echo "iptables 已安装"
else
    echo "iptables 未安装"
    echo "Installing iptables..."
    sudo apt install iptables
    if [ $? -ne 0 ]; then
        echo "Failed to install iptables. Please install iptables manually to proceed."
        exit 1
    fi
fi

            # Level 1 menu for iptables
            while true; do
                echo " iptables:"
                echo "1: 添加端口转发 Configure port forwarding"
                echo "2: 管理端口转发 Manage port forwarding"
                echo "b: 返回菜单 Back to menu"
                echo "c: 退出 Exit"
                read -p "Choose action: " choice
                
                case $choice in
    1)
        # Validate and prompt for input
        while true; do
            read -p "本地端口（非落地）Enter local port (range: 0-65535): " local_port
            if validate_port $local_port; then
                break
            else
                echo "Invalid port, please try again!"
            fi
        done

        # Automatically get local IP address
          local_ip2=$(ip addr show eth0 | grep -E 'inet\s' | awk '{print $2}' | cut -f1 -d'/' | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' | head -n 1)

        # If eth0 doesn't have the required IP, check eth1
        if [[ -z "$local_ip2" ]]; then
            local_ip2=$(ip addr show eth1 | grep -E 'inet\s' | awk '{print $2}' | cut -f1 -d'/' | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' | head -n 1)
        fi

        # Print the IP address
        if [[ -n "$local_ip2" ]]; then
            echo "IP address from eth0: $local_ip2"
        elif [[ -n "$local_ip2" ]]; then
            echo "IP address from eth1: $local_ip2"
        fi


        while true; do
            read -p "落地端口 Enter remote port (range: 0-65535):" remote_port
            if validate_port $remote_port; then
                break
            else
                echo "Invalid port, please try again!"
            fi
        done

        while true; do
            read -p "落地IP Enter remote IP (e.g.: 192.168.1.2): " remote_ip
            if validate_ip $remote_ip; then
                break
            else
                echo "Invalid IP format, please try again!"
            fi
        done
        
        # Configure iptables rules
        iptables -t nat -A PREROUTING -p tcp --dport $local_port -j DNAT --to-destination $remote_ip:$remote_port
        iptables -t nat -A POSTROUTING -p tcp -d $remote_ip --dport $remote_port -j SNAT --to-source $local_ip2
        iptables -t nat -A PREROUTING -p udp --dport $local_port -j DNAT --to-destination $remote_ip:$remote_port
        iptables -t nat -A POSTROUTING -p udp -d $remote_ip --dport $remote_port -j SNAT --to-source $local_ip2
        iptables-save > /etc/iptables/natrule.v4
        ;;

                        
                    2)
                        # Level 2 menu for iptables
                        while true; do
                            echo "iptables:"
                            echo "1: 查看所有规则 View rules"
                            echo "2: 清除所有规则 Clear port forwarding"
                            echo "3: 设置开机自启 Set autostart on boot"
                            echo "b: 返回菜单 Back to menu"
                            echo "c: 退出 Exit"
                            read -p "Choose action: " choice2
                            
                            case $choice2 in
                                1) iptables -t nat -L -n -v ;;
                                2)
                                    iptables -t nat -F
                                    ;;
                                3)
                                    # Add iptables rule to crontab for autostart
                                    if ! crontab -l | grep -q '/usr/sbin/iptables-restore < /etc/iptables/natrule.v4'; then
                                        (crontab -l ; echo "@reboot /usr/sbin/iptables-restore < /etc/iptables/natrule.v4") | crontab -
                                        echo "iptables autostart set successfully."
                                    else
                                        echo "iptables autostart already set."
                                    fi
                                    ;;
                                b) 
                                    break ;;
                                c) 
                                    echo "Exiting script." 
                                    exit 0 
                                    ;;
                                *) 
                                    echo "Invalid choice, please try again." 
                                    ;;
                            esac
                        done
                        ;;
                    b) 
                        break ;;
                    c) 
                        echo "Exiting script." 
                        exit 0 
                        ;;
                    *) 
                        echo "Invalid choice, please try again." 
                        ;;
                esac
            done
            ;;
        *) 
            echo "Invalid choice" 
            ;;
    esac
done
