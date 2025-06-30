#!/bin/bash

# =================================================================
#            mywhitessh - SSH Whitelist Auto-Update Tool
#                 One-Click Installer & Updater
#                       Version 2.5
# =================================================================

# --- 全局变量和路径定义 ---
INSTALL_DIR="/etc/mywhitessh"; CONFIG_FILE="${INSTALL_DIR}/config.conf"; CORE_SCRIPT_PATH="${INSTALL_DIR}/update_ssh_whitelist.sh"; MGR_SCRIPT_PATH="/usr/local/bin/mywhitessh"; LOG_FILE="/var/log/mywhitessh_update.log"; CRON_JOB_FILE="/etc/cron.d/mywhitessh"
SELF_URL="https://raw.githubusercontent.com/your-username/your-repo/main/install.sh"

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
# 改为更易读的亮蓝色/青色(36)
BLUE='\033[0;36m'
NC='\033[0m' # No Color

# --- 函数定义 ---
# ... check_root, check_firewall, prompt_for_config, create_config_file, create_core_script 等函数内容均无变化，为节省空间已折叠 ...
check_root() { if [ "$(id -u)" -ne 0 ]; then echo -e "${RED}错误：此脚本需要以 root 权限运行。${NC}"; echo -e "请尝试使用: ${YELLOW}sudo bash $0${NC}"; exit 1; fi; }
check_firewall() { echo -e "${BLUE}--> 正在检查防火墙状态 (UFW)...${NC}"; if ! command -v ufw &> /dev/null; then echo -e "${RED}错误：未在本机上找到 'ufw' 命令。${NC}"; exit 1; fi; if ufw status | grep -q "Status: inactive"; then echo -e "${YELLOW}警告：UFW 防火墙已安装，但当前未启动。${NC}"; read -p "是否需要脚本为您启动防火墙？(Y/n): " enable_choice; enable_choice=${enable_choice:-Y}; if [[ "$enable_choice" == "Y" || "$enable_choice" == "y" ]]; then echo -e "${BLUE}为了防止在启动防火墙时断开您当前的SSH连接，请输入您的SSH端口。${NC}"; while true; do read -p "请输入您的SSH端口 (默认为22): " temp_ssh_port; temp_ssh_port=${temp_ssh_port:-22}; if [[ "$temp_ssh_port" =~ ^[0-9]+$ ]] && [ "$temp_ssh_port" -ge 1 ] && [ "$temp_ssh_port" -le 65535 ]; then SSH_PORT_FROM_CHECK="$temp_ssh_port"; break; else echo -e "${YELLOW}警告：请输入一个 1-65535 之间的有效端口号。${NC}"; fi; done; echo "正在允许端口 ${SSH_PORT_FROM_CHECK}/tcp 的入站连接..."; ufw allow ${SSH_PORT_FROM_CHECK}/tcp >/dev/null; echo "正在启动 UFW 防火墙..."; yes | ufw enable >/dev/null; echo -e "${GREEN}UFW 防火墙已成功启动！${NC}"; else echo -e "${RED}安装中止。请手动启动 UFW 后再重新运行此脚本。${NC}"; exit 1; fi; else echo -e "${GREEN}检测到 UFW 防火墙已在运行中。${NC}"; fi; echo ""; }
prompt_for_config() { echo -e "${BLUE}--- 欢迎使用 mywhitessh 自动安装程序 ---${NC}"; echo ""; while true; do read -p "请输入您的IP白名单来源URL: "; if [[ ! "$REPLY" =~ ^https?:// ]]; then echo -e "${YELLOW}警告：输入内容看起来不像一个有效的URL，请重新输入。${NC}"; continue; fi; IP_LIST_URL="$REPLY"; echo -e "${BLUE}--> 正在验证URL并拉取内容...${NC}"; IP_CONTENT=$(curl -sfL "${IP_LIST_URL}"); if [ $? -ne 0 ]; then echo -e "${RED}错误：无法从此URL获取内容。请检查URL是否拼写正确以及网络是否通畅。${NC}\n"; continue; fi; VALID_IPS=$(echo "${IP_CONTENT}" | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}"); if [ -z "${VALID_IPS}" ]; then echo -e "${RED}错误：成功连接到URL，但其内容中未发现任何可识别的IP地址。${NC}\n"; continue; fi; RAW_LINES=$(echo "${IP_CONTENT}" | grep -v '^\s*$'); echo -e "${GREEN}成功获取到以下原始内容预览:${NC}"; echo "-------------------------------------"; echo -e "${YELLOW}${RAW_LINES}${NC}"; echo "-------------------------------------"; echo "提示：脚本将自动提取所有符合格式的IP地址进行处理。"; read -p "按 [回车] 确认列表正确并继续，输入 [0] 终止安装: " confirm_choice; if [[ "$confirm_choice" == "0" ]]; then echo -e "${RED}安装已由用户终止。${NC}"; exit 0; fi; break; done; if [[ -n "$SSH_PORT_FROM_CHECK" ]]; then SSH_PORT="$SSH_PORT_FROM_CHECK"; echo -e "${GREEN}已自动使用您在防火墙启动步骤中输入的SSH端口: ${SSH_PORT}${NC}"; else while true; do read -p "请输入您的SSH端口 (默认为22): " SSH_PORT; SSH_PORT=${SSH_PORT:-22}; if [[ "$SSH_PORT" =~ ^[0-9]+$ ]] && [ "$SSH_PORT" -ge 1 ] && [ "$SSH_PORT" -le 65535 ]; then break; else echo -e "${YELLOW}警告：请输入一个 1-65535 之间的有效端口号。${NC}"; fi; done; fi; echo ""; echo -e "${GREEN}配置完成！信息如下:${NC}"; echo -e "URL: ${YELLOW}${IP_LIST_URL}${NC}"; echo -e "SSH端口: ${YELLOW}${SSH_PORT}${NC}"; read -p "按 [回车] 确认并开始安装..."; }
create_config_file() { echo -e "${BLUE}--> 正在创建配置文件...${NC}"; mkdir -p "$INSTALL_DIR"; echo "# mywhitessh 配置文件" > "$CONFIG_FILE"; echo "IP_LIST_URL=\"$IP_LIST_URL\"" >> "$CONFIG_FILE"; echo "SSH_PORT=\"$SSH_PORT\"" >> "$CONFIG_FILE"; echo "SELF_URL=\"$SELF_URL\"" >> "$CONFIG_FILE"; echo -e "${GREEN}配置文件已创建于 ${CONFIG_FILE}${NC}"; }
create_core_script() { echo -e "${BLUE}--> 正在创建核心更新脚本...${NC}"; cat << 'EOF' > "$CORE_SCRIPT_PATH"; #!/bin/bash
CONFIG_FILE="/etc/mywhitessh/config.conf"; if [ -f "$CONFIG_FILE" ]; then source "$CONFIG_FILE"; else echo "错误：配置文件 $CONFIG_FILE 未找到！" >&2; exit 1; fi; LOG_FILE="/var/log/mywhitessh_update.log"; log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "${LOG_FILE}"; }; log "--- Cron任务执行开始 ---"; if ! command -v ufw &> /dev/null || ufw status | grep -q "Status: inactive"; then log "[ERROR] UFW未安装或未激活。Cron任务中止。"; exit 1; fi; log "正在从 ${IP_LIST_URL} 获取IP列表..."; IP_LIST=$(curl -sfL "${IP_LIST_URL}"); if [ $? -ne 0 ]; then log "[ERROR] 从URL下载IP列表失败。更新中止。"; exit 1; fi; VALID_IPS=$(echo "${IP_LIST}" | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}"); if [ -z "${VALID_IPS}" ]; then log "[WARNING] 获取到的内容中无可识别的IP地址。为防止锁定，更新中止。"; exit 1; fi; log "成功解析出以下IP: ${VALID_IPS}"; log "正在清理针对端口 ${SSH_PORT} 的旧规则..."; for RULE_NUM in $(ufw status numbered | grep "${SSH_PORT}/tcp" | grep "ALLOW IN" | awk -F'[][]' '{print $2}' | sort -nr); do yes | ufw delete "${RULE_NUM}" > /dev/null; done; log "旧规则已清理。"; log "正在添加新规则..."; for IP in ${VALID_IPS}; do ufw allow from "${IP}" to any port "${SSH_PORT}" proto tcp; log "已添加规则: 允许来自 ${IP} 的SSH连接"; done; log "新规则已成功应用。"; ufw reload > /dev/null; log "防火墙已重载。"; log "--- Cron任务执行结束 ---"; echo "" >> "${LOG_FILE}"; exit 0
EOF
chmod +x "$CORE_SCRIPT_PATH"; echo -e "${GREEN}核心脚本已创建于 ${CORE_SCRIPT_PATH}${NC}"; }

# 创建用户管理脚本
create_management_script() {
    echo -e "${BLUE}--> 正在创建管理命令 'mywhitessh'...${NC}"
    # 这里是生成mywhitessh脚本的核心部分
    cat << 'EOF' > "$MGR_SCRIPT_PATH"
#!/bin/bash
# 这是mywhitessh的用户管理界面脚本。

CONFIG_FILE="/etc/mywhitessh/config.conf"
CORE_SCRIPT_PATH="/etc/mywhitessh/update_ssh_whitelist.sh"

# 【修改】将这里硬编码的颜色定义也进行同步修改
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'  # <-- 这里就是关键的修改点！
NC='\033[0m'

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        echo -e "${RED}错误：配置文件 $CONFIG_FILE 未找到！请尝试重新运行安装脚本。${NC}"
        exit 1
    fi
}

update_config_value() {
    local key="$1"; local value="$2"
    sed -i.bak "s|^\($key\s*=\s*\).*|\1\"$value\"|" "$CONFIG_FILE" && rm -f "${CONFIG_FILE}.bak"
}

show_menu() {
    load_config; clear
    echo -e "${BLUE}=====================================${NC}" # <-- 调用此处的BLUE变量
    echo -e "${BLUE}       mywhitessh 管理菜单         ${NC}" # <-- 调用此处的BLUE变量
    echo -e "${BLUE}=====================================${NC}" # <-- 调用此处的BLUE变量
    echo "1. 查看白名单来源URL及内容预览"
    echo "2. 修改白名单来源URL"
    echo "3. 查看当前SSH端口"
    echo "4. 修改SSH端口"
    echo "5. 手动执行一次白名单更新"
    echo "6. 从GitHub更新此脚本"
    echo "7. 退出脚本"
    echo -e "${BLUE}------------------------------------${NC}" # <-- 调用此处的BLUE变量
}

while true; do
    show_menu
    read -p "请输入选项数字并回车: " choice
    echo ""
    case $choice in
        1)
            echo -e "${YELLOW}当前URL为:${NC}"; echo "$IP_LIST_URL"; echo ""; echo -e "${BLUE}--> 正在实时拉取预览...${NC}"; IP_CONTENT=$(curl -sfL "${IP_LIST_URL}"); if [ $? -ne 0 ]; then echo -e "${RED}错误：无法获取内容。${NC}"; else RAW_LINES=$(echo "${IP_CONTENT}" | grep -v '^\s*$'); if [ -z "${RAW_LINES}" ]; then echo -e "${YELLOW}URL可访问，内容为空。${NC}"; else echo -e "${GREEN}实时预览内容:${NC}"; echo "-------------------------------------"; echo -e "${YELLOW}${RAW_LINES}${NC}"; echo "-------------------------------------"; fi; fi;;
        2)
            read -p "新URL: " new_url; update_config_value "IP_LIST_URL" "$new_url"; echo -e "${GREEN}URL已更新！${NC}";;
        3)
            echo -e "${YELLOW}当前SSH端口为:${NC}"; echo "$SSH_PORT";;
        4)
            read -p "新SSH端口: " new_port; update_config_value "SSH_PORT" "$new_port"; echo -e "${GREEN}SSH端口已更新！${NC}";;
        5)
            echo -e "${YELLOW}正在手动更新...${NC}"; sudo bash "$CORE_SCRIPT_PATH"; echo -e "${GREEN}执行完成！${NC}";;
        6)
            echo -e "${YELLOW}正在更新脚本...${NC}"; if [[ -z "$SELF_URL" ]]; then echo -e "${RED}错误：源URL未定义。${NC}"; else TMP_INSTALLER="/tmp/install_mywhitessh.sh"; if curl -sfL "$SELF_URL" -o "$TMP_INSTALLER"; then echo -e "${GREEN}下载成功，开始更新...${NC}"; sudo bash "$TMP_INSTALLER"; exit 0; else echo -e "${RED}错误：下载失败。${NC}"; fi; fi;;
        7)
            echo "正在退出..."; exit 0;;
        *)
            echo -e "${RED}无效输入。${NC}";;
    esac
    read -p "按 [回车] 返回主菜单..."
done
EOF
    chmod +x "$MGR_SCRIPT_PATH"
    echo -e "${GREEN}管理命令已创建于 ${MGR_SCRIPT_PATH}${NC}"
}

setup_cron() { echo -e "${BLUE}--> 正在设置Cron任务...${NC}"; echo "30 3 * * * root ${CORE_SCRIPT_PATH}" > "$CRON_JOB_FILE"; chmod 644 "$CRON_JOB_FILE"; if command -v systemctl &> /dev/null; then systemctl restart cron; else service cron restart; fi; echo -e "${GREEN}Cron任务设置完毕。${NC}"; }

# --- 主逻辑 ---
# ... 主逻辑内容无变化 ...
check_root
if [ -f "$CONFIG_FILE" ]; then echo -e "${YELLOW}检测到 'mywhitessh' 已安装。${NC}"; read -p "您想保留现有配置并更新脚本吗？(Y/n): " choice; choice=${choice:-Y}; if [[ "$choice" == "Y" || "$choice" == "y" ]]; then check_firewall; source "$CONFIG_FILE"; echo "正在使用现有配置更新..."; create_core_script; create_management_script; setup_cron; echo -e "${GREEN}mywhitessh已更新！${NC}"; exit 0; else check_firewall; prompt_for_config; fi; else check_firewall; prompt_for_config; fi
create_config_file; create_core_script; create_management_script; setup_cron
echo ""; echo -e "${BLUE}--- 准备首次执行白名单更新 ---${NC}"; sudo bash "$CORE_SCRIPT_PATH"; echo -e "${GREEN}首次更新执行完毕！${NC}";
echo ""; echo -e "${GREEN}======================================================${NC}"; echo -e "${GREEN}          🎉 mywhitessh 安装成功! 🎉          ${NC}"; echo -e "${GREEN}======================================================${NC}"; echo ""; echo "后续您可以随时在终端输入以下命令，"; echo "来再次唤出此管理菜单进行配置："; echo -e "  ${YELLOW}sudo mywhitessh${NC}"; echo ""; echo "日志文件位于: ${LOG_FILE}"; echo ""
