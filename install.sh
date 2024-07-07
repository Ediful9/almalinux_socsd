#!/bin/bash

# Step 1: 检查 SELinux 状态并临时关闭
check_selinux_status() {
    SELINUX_STATUS=$(getenforce)
    echo "当前 SELinux 状态: $SELINUX_STATUS"
    if [ "$SELINUX_STATUS" != "Disabled" ]; then
        echo "临时关闭 SELinux..."
        setenforce 0
        echo "修改 GRUB 配置以永久关闭 SELinux..."
        detect_firmware_and_update_grub
        echo "请重启系统以应用永久关闭 SELinux 的更改。"
    else
        echo "SELinux 已经处于关闭状态，无需修改。"
    fi

    systemctl disable --now firewalld &>/dev/null
}

# Step 2: 根据系统固件类型更新 GRUB 配置
detect_firmware_and_update_grub() {
    if [ -d "/sys/firmware/efi" ]; then
        DISTRO=$(grep PRETTY_NAME /etc/os-release | cut -d '"' -f 2 | awk '{print tolower($1)}')
        sed -i '/SELINUX=enforcing/c\SELINUX=disabled' /etc/selinux/config
        grub2-mkconfig -o /boot/efi/EFI/${DISTRO}/grub.cfg
        echo "已更新 UEFI 系统的 GRUB 配置。"
    else
        sed -i '/SELINUX=enforcing/c\SELINUX=disabled' /etc/selinux/config
        grub2-mkconfig -o /boot/grub2/grub.cfg
        echo "已更新 BIOS 系统的 GRUB 配置。"
    fi
}

# Step 3: 检测并安装 epel-release 包
check_and_install_epel() {
    if ! rpm -qa | grep -qw epel-release; then
        echo "安装 epel-release..."
        yum install -y epel-release
    else
        echo "epel-release 已安装。"
    fi
}

# Step 4: 检测并安装 dante-server
check_and_install_dante_server() {
    check_and_install_epel
    if ! rpm -qa | grep -qw dante-server; then
        echo "安装 dante-server..."
        yum install -y dante-server
    else
        echo "dante-server 已安装。"
    fi
}

configure_firewalld(){
    local port=$1
    if systemctl is-active --quiet firewalld; then
        echo "Firewalld is running, configuring port ${port}..."
        firewall-cmd --permanent --add-port=${port}/tcp
        firewall-cmd --reload
        echo "Port ${port} has been allowed through firewalld."
    else
        echo "Firewalld is not running. No changes made to firewall rules."
    fi
}


create_dante_manage_script() {
        cat > /usr/local/bin/dante-manage << 'EOF'
#! /bin/bash

#Color Variable
CSI=$(echo -e "\033[")
CEND="${CSI}0m"
CDGREEN="${CSI}32m"
CRED="${CSI}1;31m"
CGREEN="${CSI}1;32m"
CYELLOW="${CSI}1;33m"
CBLUE="${CSI}1;34m"
CMAGENTA="${CSI}1;35m"
CCYAN="${CSI}1;36m"
CQUESTION="$CMAGENTA"
CWARNING="$CRED"
CMSG="$CCYAN"
#Color Variable

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DAEMON="/usr/sbin/sockd"
DESC="Dante SOCKS 5 daemon"
PID_FILE="/run/sockd.pid"
CONFIG_FILE="/etc/sockd.conf"
PASSWD_FILE="/etc/danted/sockd.passwd"

test -f $DAEMON || exit 0
test -f $CONFIG_FILE || exit 0

LOG_FILE=$(grep '^logoutput' ${CONFIG_FILE} | sed 's/.*logoutput: \(.*\).*/\1/g')


start_daemon_all(){
        systemctl start sockd.service
}

stop_daemon_all(){
        systemctl stop sockd.service
}

force_stop_daemon(){
    ps -ef | grep ${DAEMON} | grep -v 'grep' | awk '{print $2}' | \
            while read pid; do kill -9 $pid > /dev/null 2>&1 ;done

    [ -f "$PID_FILE" ] && rm -f $PID_FILE
}

reload_daemon_all(){
        systemctl reload sockd.service
}

status(){
    VERSION=$([ -f "${DAEMON}" ] && ${DAEMON} -v)

    printf "%s\n" "${CCYAN}+-----------------------------------------+$CEND"

    if [ ! -s ${PID_FILE} ];then
        printf "%s\n" "${CRED} Dante Server [ Stop ] ${CEND}"
    else
       ( [ -n "$( ps aux | awk '{print $2}'| grep "^$(cat ${PID_FILE})$" )" ] \
          && printf "%s\n" "${CGREEN} Dante Server [ Running ] ${CEND}" ) \
          || printf "%s\n" "${CRED} Dante Server [ PID.DIE;Running ] ${CEND}"
    fi

    printf "%s\n" "${CCYAN}+-----------------------------------------+$CEND"
    printf "%-30s%s\n"  "${CGREEN} Dante Version:${CEND}"  "$CMAGENTA ${VERSION}${CEND}"
    printf "%-30s\n"  "${CGREEN} Socks5 Info:${CEND}"

    grep '^internal:' ${CONFIG_FILE} | \
        sed 's/internal:[[:space:]]*\([0-9.]*\).*port[[:space:]]*=[[:space:]]*\(.*\)/\1:\2/g' | \
            while read proxy;do
                printf "%20s%s\n" "" "${CMAGENTA}${proxy}${CEND}"
            done

    if [ -s ${PASSWD_FILE} ];then
        SOCKD_USER=$(cat ${PASSWD_FILE} | while read line;do echo ${line} | sed 's/\(.*\):.*/\1/'                                                                                                                              ;done)
        printf "%-30s%s\n" "${CGREEN} Socks5 User:${CEND}"  "$CMAGENTA ${SOCKD_USER}${CEND}"
    fi

    printf "%s\n" "${CCYAN}+_________________________________________+$CEND"
}

add_user(){
    local User=$1
    local Password=$2
    ( [ -z "$User" ] || [ -z "$Password" ] ) && \
        echo " Error: User or password can't be blank" && return 0

    # 检查用户是否已存在
    if id "$User" &>/dev/null; then
        echo "错误：用户已存在"
        return 1
    fi

    # 添加用户
    useradd $User
    if [ $? -ne 0 ]; then
        echo "错误：无法创建用户"
        return 1
    fi

    # 设置密码
    echo "$Password" | passwd --stdin $User
    if [ $? -eq 0 ]; then
        echo "用户${User}成功创建并设置密码"
    else
        echo "错误：无法设置密码"
        userdel $User  # 如果设置密码失败，删除创建的用户
        return 1
    fi
}

del_user(){
    local User=$1
    [ -z "$User" ] && echo " Error: User Name can't be blank" && return 0

    if ! id "$User" &>/dev/null; then
        echo "错误：用户不存在"
        return 0
    fi

    userdel -r $User
    echo "用户${User}已被成功删除。"

}

clear_log(){
    [ -f "$PID_FILE" ] && rm -f $PID_FILE
    [ -f "$LOG_FILE" ]  && cp /dev/null $LOG_FILE
}

tail_log(){
    local LOG_FILE="$1"
    [ -f ${LOG_FILE} ] && tail -f ${LOG_FILE}
}

case "$1" in
  start)
    echo "Starting $DESC: "
    start_daemon_all
    ;;
  stop)
    echo "Stopping $DESC: "
    stop_daemon_all
    ;;
  force-stop)
    echo "Stopping $DESC: [Force]"
    force_stop_daemon
    ;;
  reload)
    echo "Reloading $DESC configuration files."
    reload_daemon_all
    ;;
  restart)
    echo "Restarting $DESC: "
    stop_daemon_all
    force_stop_daemon
    sleep 1
    start_daemon_all
    ;;
  status|state)
    clear
    status
    ;;
  adduser)
    echo "Adding User For $DESC: "
    add_user "$2" "$3"
    ;;
  deluser)
    echo "Clearing User For $DESC: "
    del_user "$2"
    ;;
  tail)
     echo "==> ${LOG_FILE} <=="
     tail_log "${LOG_FILE}"
    ;;
  conf)
      echo "==> ${CONFIG_FILE} <=="
      cat ${CONFIG_FILE}
    ;;
  *)
    N=dante-manage
    echo " Usage: $N {start|stop|restart|reload|status|state|adduser|deluser|tail|conf}" >&2
    exit 1
    ;;
esac

exit 0
EOF

chmod +x /usr/local/bin/dante-manage

}

create_or_update_pam_config() {
    local pam_file="/etc/pam.d/sockd"
    local content="auth    required    pam_unix.so\naccount required    pam_unix.so"

    # 检查文件是否存在且内容是否正确
    if [ -f "$pam_file" ]; then
        # 检查现有文件内容
        if grep -q "auth    required    pam_unix.so" "$pam_file" && grep -q "account required    pam_unix.so"                                                                          "$pam_file"; then
            echo "PAM configuration is already set correctly."
            return 0
        else
            echo "Updating the PAM configuration file..."
        fi
    else
        echo "Creating new PAM configuration file..."
    fi

    # 创建或更新文件
    echo -e "$content" > "$pam_file"

    if [ $? -eq 0 ]; then
        echo "PAM configuration file has been successfully created/updated at $pam_file."
    else
        echo "Failed to create/update the PAM configuration file." >&2
        return 1
    fi
}


# 执行所有步骤
check_selinux_status
check_and_install_dante_server
create_or_update_pam_config


VERSION="1.4.3"
INSTALL_FROM="rpm"
DEFAULT_PORT="80"
DEFAULT_PAWD=""
WHITE_LIST_NET=""
WHITE_LIST=""

BIN_PATH="/usr/sbin/sockd"
CONFIG_PATH="/etc/sockd.conf"
BIN_SCRIPT="/usr/bin/sockd"

DEFAULT_IPADDR=$(ip addr | grep 'inet ' | grep -Ev 'inet 127|inet 192\.168' | \
            sed "s/[[:space:]]*inet \([0-9.]*\)\/.*/\1/")
RUN_PATH=$(cd `dirname $0`;pwd )
RUN_OPTS=$*

##################------------Func()---------#####################################

setup_service(){
    systemctl enable --now sockd.service && echo "sockd service has been enabled and started."
}


detect_install(){
    if [ -s "${BIN_PATH}" ];then
        echo "dante socks5 already install"
        ${BIN_PATH} -v
    fi
}

generate_config_ip(){
    local ipaddr="$1"
    local port="$2"

    cat <<EOF
# Generate interface ${ipaddr}
internal: ${ipaddr}  port = ${port}
external: ${ipaddr}

EOF
}

generate_config_iplist(){
    local ipaddr_list="$1"
    local port="$2"

    [ -z "${ipaddr_list}" ] && return 1
    [ -z "${port}" ] && return 2

    for ipaddr in ${ipaddr_list};do
        generate_config_ip ${ipaddr} ${port} >> ${CONFIG_PATH}
    done

    ipaddr_array=($ipaddr_list)

    if [ ${#ipaddr_array[@]} -gt 1 ];then
        echo "external.rotation: same-same" >> ${CONFIG_PATH}
    fi
}

generate_config_static(){
    if [ "$VERSION" == "1.3.2" ];then
    cat <<EOF
method: pam none
clientmethod: none
user.privileged: root
user.notprivileged: nobody
logoutput: /var/log/sockd.log

client pass {
        from: 0.0.0.0/0  to: 0.0.0.0/0
}
client block {
        from: 0.0.0.0/0 to: 0.0.0.0/0
}
EOF
    else
    cat <<EOF
clientmethod: none
socksmethod: pam.username none

user.privileged: root
user.notprivileged: nobody

logoutput: /var/log/sockd.log

client pass {
    from: 0/0  to: 0/0
    log: connect disconnect
}
client block {
    from: 0/0 to: 0/0
    log: connect error
}
EOF
    fi
}
generate_config_white(){
    local white_ipaddr="$1"

    [ -z "${white_ipaddr}" ] && return 1

    # x.x.x.x/32
    for ipaddr_range in ${white_ipaddr};do
        cat <<EOF
#------------ Network Trust: ${ipaddr_range} ---------------
pass {
        from: ${ipaddr_range} to: 0.0.0.0/0
        method: none
}

EOF
    done
}

generate_config_whitelist(){
    local whitelist_url="$1"

    if [ -n "${whitelist_url}" ];then
        ipaddr_list=$(curl -s --insecure -A "Mozilla Server Init" ${whitelist_url})
        generate_config_white "${ipaddr_list}"
    fi
}

generate_config_bottom(){
    if [ "$VERSION" == "1.3.2" ];then
    cat <<EOF
pass {
        from: 0.0.0.0/0 to: 0.0.0.0/0
        protocol: tcp udp
        method: pam
        log: connect disconnect
}
block {
        from: 0.0.0.0/0 to: 0.0.0.0/0
        log: connect error
}

EOF
    else
    cat <<EOF
socks pass {
    from: 0/0 to: 0/0
    socksmethod: pam.username
    log: connect disconnect
}
socks block {
    from: 0/0 to: 0/0
    log: connect error
}

EOF
    fi
}

generate_config(){
    local ipaddr_list="$1"
    local whitelist_url="$2"
    local whitelist_ip="$3"

    echo "# Generate by sockd.info" > ${CONFIG_PATH}

    generate_config_iplist "${ipaddr_list}" ${DEFAULT_PORT} >> ${CONFIG_PATH}

    generate_config_static >> ${CONFIG_PATH}
    generate_config_white ${whitelist_ip} >> ${CONFIG_PATH}
    generate_config_whitelist "${whitelist_url}" >> ${CONFIG_PATH}
    generate_config_bottom  >> ${CONFIG_PATH}
}

##################------------Menu()---------#####################################
echo "Current Options: $RUN_OPTS"
for _PARAMETER in $RUN_OPTS
do
    case "${_PARAMETER}" in
      --ip=*)   #split by: ip1:ip2:ip3
        ipaddr_list=$(echo "${_PARAMETER#--ip=}" | sed 's/:/\n/g' | sed '/^$/d')
      ;;
      --port=*)
        port="${_PARAMETER#--port=}"
      ;;
      --whitelist=*)
        whitelist_ipaddrs=$(echo "${_PARAMETER#--whitelist=}" | sed 's/:/\n/g' | sed '/^$/d')
      ;;
      --whitelist-url=*)
        whitelist="${_PARAMETER#--whitelist-url=}"
      ;;
      --help|-h)
        clear
        options=(
                  "--ip=@Socks5 Server Ip address" \
                  "--port=[${DEFAULT_PORT}]@port for dante socks5 server" \
                  "--whitelist=@Socks5 Auth IP list" \
                  "--whitelist-url=@Socks Auth whitelist http online" \
                  "--help,-h@print help info" )
        printf "Usage: %s [OPTIONS]\n\nOptions:\n\n" $0

        for option in "${options[@]}";do
          printf "  %-20s%s\n" "$( echo ${option} | sed 's/@.*//g')"  "$( echo ${option} | sed 's/.*@//g')"
        done
        echo -e "\n"
        exit 1
      ;;
      *)
        echo "option ${_PARAMETER} is not support"
        exit 1
      ;;

    esac
done

create_dante_manage_script

[ -n "${port}" ] && DEFAULT_PORT="${port}"
[ -n "${ipaddr_list}" ] && DEFAULT_IPADDR="${ipaddr_list}"
[ -n "${whitelist_ipaddrs}" ] && WHITE_LIST_NET="${whitelist_ipaddrs}"
[ -n "${whitelist}" ] && WHITE_LIST="${whitelist}"

generate_config "${DEFAULT_IPADDR}" "${WHITE_LIST}" "${WHITE_LIST_NET}"

[ -n "$gen_config_only" ]  && echo "===========>> update config" && cat ${CONFIG_PATH} && exit 0

[ -n "$(detect_install)" ] && echo -e "\n[Warning] dante sockd already install." && setup_service && exit 1



echo ""

exit 0
