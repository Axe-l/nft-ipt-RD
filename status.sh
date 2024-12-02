#!/bin/bash

# 检查 /opt/ServerStatus/ 是否存在，不存在则创建
if [ ! -d "/opt/ServerStatus" ]; then
    echo "/opt/ServerStatus/ 目录不存在，正在创建..."
    mkdir -p /opt/ServerStatus
fi

# 检查是否已经下载并解压文件
if [ ! -f "/opt/ServerStatus/stat_client" ]; then
    # 下载并解压文件
    echo "正在下载并解压文件..."
    wget https://github.com/zdz/ServerStatus-Rust/releases/download/v1.8.1/client-x86_64-unknown-linux-musl.zip -O /tmp/client.zip
    unzip /tmp/client.zip -d /tmp/

    # 移动文件到目标位置
    mv /tmp/stat_client /opt/ServerStatus/
    mv /tmp/stat_client.service /etc/systemd/system/

    # 检查文件是否成功移动
    if [ ! -f "/etc/systemd/system/stat_client.service" ]; then
        echo "错误：stat_client.service 文件未成功移动到 /etc/systemd/system/"
        exit 1
    fi

    echo "文件已下载并移动到 /opt/ServerStatus/ 和 /etc/systemd/system/"
else
    echo "文件已经存在，跳过下载和解压步骤。"
fi

# 修改权限
chmod +x /opt/ServerStatus/stat_client

# 提示用户输入网站相关信息
echo "请输入你的网站地址，例如 https://status.952727.xyz/report"
read -p "请输入服务器报告地址: " server_url
read -p "请输入标识符 (例如 -g g4): " group
read -p "请输入密码: " password
read -p "请输入别名 (例如 alice): " alias
read -p "请输入端口号: " port

# 构建 ExecStart 命令行
exec_start_cmd="/opt/ServerStatus/./stat_client -a $server_url -g $group -p $password --alias $alias -w $port"

# 替换服务文件中的 ExecStart 行
echo "正在更新 stat_client.service 配置..."
sed -i "s|^ExecStart=.*|ExecStart=$exec_start_cmd|g" /etc/systemd/system/stat_client.service

# 重新加载 systemd 服务并启用
echo "正在重新加载 systemd 配置..."
systemctl daemon-reload
systemctl enable stat_client.service
systemctl start stat_client.service

echo "安装并配置完成，stat_client 服务已启动。"
