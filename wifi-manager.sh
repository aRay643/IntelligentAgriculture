#!/bin/bash
# NetworkManager WiFi热点管理器
# 功能：基于NetworkManager的热点模式 ↔ 客户端模式切换
# 配置：SSID=WHUCS-Ubuntu, 密码=12345678

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置变量
HOTSPOT_SSID="WHUCS-Ubuntu"
HOTSPOT_PASSWORD="12345678"
HOTSPOT_CONNECTION_NAME="WHUCS-Hotspot"
WIFI_CONNECTION_NAME=""

# 获取当前WiFi连接名称（用于恢复）
get_current_wifi_connection() {
    WIFI_CONNECTION_NAME=$(nmcli -t -f NAME,TYPE,DEVICE connection show --active | \
        grep "wireless.*$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2}')" | \
        cut -d: -f1 | head -1)
    
    if [ -n "$WIFI_CONNECTION_NAME" ]; then
        echo -e "${GREEN}当前WiFi连接: $WIFI_CONNECTION_NAME${NC}"
    fi
}

# 检测无线接口
detect_wifi_interface() {
    WIFI_IFACE=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2}')
    
    if [ -z "$WIFI_IFACE" ]; then
        # 尝试其他方法检测
        WIFI_IFACE=$(ls /sys/class/net | grep -E '^wlan[0-9]+$|^wlp[0-9]+s[0-9]+$|^wlx[0-9a-f]+$' | head -1)
    fi
    
    if [ -z "$WIFI_IFACE" ]; then
        echo -e "${RED}错误: 未检测到无线网卡${NC}"
        echo "请检查："
        echo "1. USB无线网卡是否已插入"
        echo "2. 运行: lsusb | grep -i wireless"
        echo "3. 运行: ip link show"
        return 1
    fi
    
    echo -e "${GREEN}检测到无线接口: $WIFI_IFACE${NC}"
    
    # 检查网卡是否支持AP模式
    if ! iw list 2>/dev/null | grep -q "AP"; then
        echo -e "${YELLOW}警告: 网卡可能不支持AP模式，但NetworkManager会尝试${NC}"
    fi
    
    return 0
}

# 检查NetworkManager服务
check_network_manager() {
    if ! systemctl is-active --quiet NetworkManager; then
        echo -e "${RED}错误: NetworkManager服务未运行${NC}"
        echo "启动NetworkManager..."
        sudo systemctl start NetworkManager
        sleep 2
        
        if ! systemctl is-active --quiet NetworkManager; then
            echo -e "${RED}无法启动NetworkManager，请手动启动${NC}"
            return 1
        fi
    fi
    
    echo -e "${GREEN}✓ NetworkManager运行正常${NC}"
    return 0
}

# 检查root权限
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}请使用root权限运行此脚本${NC}"
        echo "用法: sudo $0 [选项]"
        exit 1
    fi
}

# 检查并安装必要工具
check_tools() {
    echo -e "${YELLOW}检查必要工具...${NC}"
    
    # 检查nmcli
    if ! command -v nmcli >/dev/null 2>&1; then
        echo "安装NetworkManager..."
        apt update && apt install -y network-manager
        
        # 重启NetworkManager服务
        systemctl restart NetworkManager
        sleep 2
    fi
    
    echo -e "${GREEN}✓ 所有必要工具已安装${NC}"
}

# 切换到热点模式
switch_to_hotspot() {
    echo -e "${CYAN}切换到热点模式...${NC}"
    echo "热点名称: ${HOTSPOT_SSID}"
    echo "密码: ${HOTSPOT_PASSWORD}"
    
    # 检查NetworkManager
    if ! check_network_manager; then
        exit 1
    fi
    
    # 检测无线接口
    if ! detect_wifi_interface; then
        exit 1
    fi
    
    # 获取当前WiFi连接
    get_current_wifi_connection
    
    # 确保WiFi开启
    nmcli radio wifi on
    
    # 检查是否已存在热点连接
    if nmcli connection show "$HOTSPOT_CONNECTION_NAME" >/dev/null 2>&1; then
        echo "热点配置已存在，重新配置..."
        nmcli connection delete "$HOTSPOT_CONNECTION_NAME"
    fi
    
    # 创建热点连接
    echo "创建热点配置..."
    
    # 方法1: 使用nmcli直接创建热点（推荐）
    if nmcli device wifi hotspot ifname "$WIFI_IFACE" ssid "$HOTSPOT_SSID" password "$HOTSPOT_PASSWORD" connection-name "$HOTSPOT_CONNECTION_NAME" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 热点创建成功${NC}"
    else
        # 方法2: 手动创建连接（如果上面命令失败）
        echo "使用备用方法创建热点..."
        
        # 删除可能存在的旧连接
        nmcli connection delete "$HOTSPOT_CONNECTION_NAME" 2>/dev/null || true
        
        # 创建新的热点连接
        nmcli connection add type wifi ifname "$WIFI_IFACE" con-name "$HOTSPOT_CONNECTION_NAME" \
            autoconnect no ssid "$HOTSPOT_SSID" \
            ipv4.method shared ipv4.addresses 192.168.88.1/24 \
            wifi.mode ap wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$HOTSPOT_PASSWORD"
        
        echo -e "${GREEN}✓ 热点配置创建完成${NC}"
    fi
    
    # 启用热点
    echo "启用热点..."
    
    # 先禁用可能活动的连接
    nmcli connection down "$WIFI_CONNECTION_NAME" 2>/dev/null || true
    
    # 激活热点
    if nmcli connection up "$HOTSPOT_CONNECTION_NAME" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 热点已启用${NC}"
    else
        echo -e "${YELLOW}尝试重新启动网络...${NC}"
        nmcli networking off
        sleep 2
        nmcli networking on
        sleep 2
        nmcli connection up "$HOTSPOT_CONNECTION_NAME"
    fi
    
    # 获取热点IP
    HOTSPOT_IP=$(ip -4 addr show "$WIFI_IFACE" | grep -oP 'inet \K[\d.]+' | head -1)
    if [ -z "$HOTSPOT_IP" ]; then
        HOTSPOT_IP="192.168.88.1"
    fi
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✅ 热点模式已启用！${NC}"
    echo ""
    echo "连接信息："
    echo -e "  📶 热点名称: ${CYAN}${HOTSPOT_SSID}${NC}"
    echo -e "  🔑 密码: ${CYAN}${HOTSPOT_PASSWORD}${NC}"
    echo -e "  🌐 管理地址: ${CYAN}${HOTSPOT_IP}${NC}"
    echo -e "  🔧 接口: ${CYAN}${WIFI_IFACE}${NC}"
    echo ""
    echo "其他设备可以搜索并连接此WiFi热点。"
    echo -e "${GREEN}========================================${NC}"
    
    # 显示状态
    sleep 2
    show_status
}

# 切换到客户端模式
switch_to_client() {
    echo -e "${CYAN}切换到WiFi客户端模式...${NC}"
    
    # 检查NetworkManager
    if ! check_network_manager; then
        exit 1
    fi
    
    # 检测无线接口
    if ! detect_wifi_interface; then
        exit 1
    fi
    
    # 停止热点
    echo "停止热点连接..."
    nmcli connection down "$HOTSPOT_CONNECTION_NAME" 2>/dev/null || true
    
    # 删除热点连接（可选）
    read -p "是否删除热点配置？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        nmcli connection delete "$HOTSPOT_CONNECTION_NAME" 2>/dev/null || true
        echo "热点配置已删除"
    fi
    
    # 启用WiFi
    echo "启用WiFi客户端..."
    nmcli radio wifi off
    sleep 1
    nmcli radio wifi on
    
    # 扫描可用网络
    echo "扫描可用WiFi网络..."
    nmcli device wifi rescan
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✅ WiFi客户端模式已启用！${NC}"
    echo ""
    echo "现在可以："
    echo "1. 点击系统托盘网络图标连接WiFi"
    echo "2. 或使用以下命令连接:"
    echo "   nmcli device wifi list"
    echo "   nmcli device wifi connect '网络名称' password '密码'"
    echo ""
    
    # 如果之前有WiFi连接，尝试重新连接
    if [ -n "$WIFI_CONNECTION_NAME" ]; then
        read -p "是否尝试重新连接之前的WiFi ($WIFI_CONNECTION_NAME)？(Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo "尝试重新连接: $WIFI_CONNECTION_NAME"
            nmcli connection up "$WIFI_CONNECTION_NAME" 2>/dev/null || \
                echo "无法自动连接，请手动连接"
        fi
    fi
    
    echo -e "${GREEN}========================================${NC}"
}

# 显示当前状态
show_status() {
    echo -e "${CYAN}当前网络状态:${NC}"
    
    # 检测无线接口
    detect_wifi_interface
    
    # 获取热点状态
    HOTSPOT_ACTIVE=$(nmcli -t -f NAME,TYPE,DEVICE connection show --active | \
        grep "wifi.*$WIFI_IFACE" | grep "hotspot\|ap")
    
    echo ""
    
    if [ -n "$HOTSPOT_ACTIVE" ]; then
        echo -e "  📡 ${GREEN}热点模式${NC} (AP)"
        CONN_NAME=$(echo "$HOTSPOT_ACTIVE" | cut -d: -f1)
        SSID=$(nmcli -t -f 802-11-wireless.ssid connection show "$CONN_NAME" 2>/dev/null)
        
        if [ -n "$SSID" ]; then
            echo -e "     热点名称: ${SSID}"
        else
            echo -e "     热点名称: ${HOTSPOT_SSID}"
        fi
        
        # 获取IP地址
        WIFI_IP=$(ip -4 addr show "$WIFI_IFACE" | grep -oP 'inet \K[\d.]+' | head -1)
        if [ -n "$WIFI_IP" ]; then
            echo -e "     管理地址: ${WIFI_IP}"
        fi
        
        # 显示连接设备数（通过ARP）
        echo "     连接设备:"
        ip neigh show dev "$WIFI_IFACE" | while read line; do
            IP=$(echo $line | awk '{print $1}')
            MAC=$(echo $line | awk '{print $5}')
            STATE=$(echo $line | awk '{print $6}')
            if [ "$STATE" = "REACHABLE" ] || [ "$STATE" = "STALE" ]; then
                echo "       - $IP ($MAC)"
            fi
        done
        
    else
        echo -e "  📱 ${BLUE}客户端模式${NC}"
        
        # 获取当前WiFi连接
        CURRENT_CONNECTION=$(nmcli -t -f NAME,TYPE,DEVICE connection show --active | \
            grep "wifi.*$WIFI_IFACE" | cut -d: -f1)
        
        if [ -n "$CURRENT_CONNECTION" ]; then
            SSID=$(nmcli -t -f 802-11-wireless.ssid connection show "$CURRENT_CONNECTION")
            echo -e "     已连接: ${SSID}"
            
            # 获取IP地址
            WIFI_IP=$(ip -4 addr show "$WIFI_IFACE" | grep -oP 'inet \K[\d.]+' | head -1)
            if [ -n "$WIFI_IP" ]; then
                echo -e "     IP地址: ${WIFI_IP}"
            fi
            
            # 获取信号强度
            SIGNAL=$(nmcli -t -f ACTIVE,SIGNAL device wifi | grep "^是" | cut -d: -f2 | head -1)
            if [ -n "$SIGNAL" ]; then
                echo -e "     信号强度: ${SIGNAL}%"
            fi
        else
            echo "     未连接WiFi"
        fi
        
        # 显示可用网络
        echo ""
        echo "     可用WiFi网络:"
        nmcli -f SSID,SIGNAL dev wifi list | head -10 | while read line; do
            echo "       $line"
        done
    fi
    
    echo ""
    echo -e "  🔧 接口信息: ${WIFI_IFACE}"
    echo -e "  📊 MAC地址: $(cat /sys/class/net/$WIFI_IFACE/address 2>/dev/null || echo '未知')"
}

# 列出可用WiFi网络
list_wifi_networks() {
    echo -e "${CYAN}扫描可用WiFi网络...${NC}"
    nmcli device wifi rescan
    echo ""
    nmcli -f SSID,SIGNAL,SECURITY dev wifi list
}

# 连接到WiFi网络
connect_to_wifi() {
    if [ $# -lt 1 ]; then
        echo -e "${RED}错误: 需要提供WiFi名称${NC}"
        echo "用法: $0 connect <SSID> [密码]"
        return 1
    fi
    
    SSID="$1"
    PASSWORD="$2"
    
    echo "连接到WiFi: $SSID"
    
    if [ -n "$PASSWORD" ]; then
        nmcli device wifi connect "$SSID" password "$PASSWORD"
    else
        nmcli device wifi connect "$SSID"
    fi
}

# 断开当前WiFi连接
disconnect_wifi() {
    echo "断开WiFi连接..."
    nmcli device disconnect "$WIFI_IFACE"
}

# 重启网络服务
restart_network() {
    echo -e "${YELLOW}重启网络服务...${NC}"
    
    # 保存当前连接
    CURRENT_CONNECTION=$(nmcli -t -f NAME,TYPE,DEVICE connection show --active | \
        grep "wifi.*$WIFI_IFACE" | cut -d: -f1)
    
    # 重启NetworkManager
    systemctl restart NetworkManager
    sleep 3
    
    # 重新启用WiFi
    nmcli radio wifi on
    
    echo -e "${GREEN}✓ 网络服务已重启${NC}"
    
    # 如果之前有连接，尝试重新连接
    if [ -n "$CURRENT_CONNECTION" ] && [ "$CURRENT_CONNECTION" != "$HOTSPOT_CONNECTION_NAME" ]; then
        echo "尝试重新连接: $CURRENT_CONNECTION"
        nmcli connection up "$CURRENT_CONNECTION" 2>/dev/null || true
    fi
}

# 显示帮助信息
show_help() {
    echo -e "${CYAN}NetworkManager WiFi管理器脚本${NC}"
    echo "功能：基于NetworkManager的热点模式 ↔ 客户端模式切换"
    echo ""
    echo -e "${GREEN}使用方法:${NC}"
    echo "  sudo $0 [选项]"
    echo ""
    echo -e "${GREEN}选项:${NC}"
    echo "  hotspot        切换到热点模式 (SSID: WHUCS-Ubuntu, 密码: 12345678)"
    echo "  client         切换到WiFi客户端模式"
    echo "  status         显示当前状态"
    echo "  list           列出可用WiFi网络"
    echo "  connect <SSID> [密码]  连接到指定WiFi"
    echo "  disconnect     断开当前WiFi连接"
    echo "  restart        重启网络服务"
    echo "  help           显示此帮助信息"
    echo ""
    echo -e "${GREEN}示例:${NC}"
    echo "  sudo $0 hotspot           # 开启WiFi热点"
    echo "  sudo $0 client            # 切换回普通WiFi"
    echo "  sudo $0 status            # 查看当前状态"
    echo "  sudo $0 list              # 列出可用WiFi"
    echo "  sudo $0 connect MyWiFi MyPassword  # 连接WiFi"
    echo ""
    echo -e "${GREEN}热点配置:${NC}"
    echo "  SSID: ${HOTSPOT_SSID}"
    echo "  密码: ${HOTSPOT_PASSWORD}"
    echo ""
}

# 主函数
main() {
    # 检查参数
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    # 检查root权限
    check_root
    
    # 检查并安装必要工具
    check_tools
    
    case "$1" in
        "hotspot"|"ap")
            switch_to_hotspot
            ;;
        "client"|"wifi")
            switch_to_client
            ;;
        "status"|"info")
            show_status
            ;;
        "list")
            list_wifi_networks
            ;;
        "connect")
            shift
            connect_to_wifi "$@"
            ;;
        "disconnect")
            disconnect_wifi
            ;;
        "restart")
            restart_network
            ;;
        "help"|"--help"|-h)
            show_help
            ;;
        *)
            echo -e "${RED}未知选项: $1${NC}"
            echo "使用 'sudo $0 help' 查看帮助"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
