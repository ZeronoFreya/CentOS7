#!/bin/bash
function addSudo() {
  sudoPwd=/etc/sudoers
  chmod u+w $sudoPwd
  if grep $1 $sudoPwd; then
    echo "User $1 already have sudo!"
  else
    sed -i '/root[\s\t]*ALL=(ALL)/a\'${1}' ALL=(ALL) ALL' $sudoPwd \
    && sed -i '/NOPASSWD/a\'${1}' ALL=(ALL) NOPASSWD: ALL' $sudoPwd \
    && echo "User $1 add sudo success!"
  fi
  chmod u-w $sudoPwd
}
function userAdd() {
  read -p 'user name:' USER_NAME
  if grep -q '^'${USER_NAME}':' /etc/passwd; then
    read -rp 'user already exists! new? [y/n]' add_new
    if [[ ${add_new} == "y" || ${add_new} == "Y" ]]; then
      userAdd
    fi
    return 0
  else
    read -p 'password:' USER_PWD
    useradd $USER_NAME
    echo $USER_PWD | passwd $USER_NAME --stdin
  fi

  sshPwd="/home/${USER_NAME}/.ssh"
  if [ ! -d "$sshPwd" ]; then
    mkdir -p $sshPwd
  fi
  # .ssh 目录的权限必须是 700
  chmod 700 $sshPwd
  cd $sshPwd || exit
  read -rp 'Add Public key ? [y/n]' is_add_key
  if [[ ${is_add_key} == "y" || ${is_add_key} == "Y" ]]; then
      read -rp 'Public key:' pub_key
      echo $pub_key >> authorized_keys
      chmod 600 authorized_keys
      chown $USER_NAME -R $sshPwd
  fi
  # 将用户加入sudoers, 获得sudo权限
  addSudo $USER_NAME
}

function sshCfg() {
  sshdPwd=/etc/ssh/sshd_config
  cp $sshdPwd $sshdPwd".bak"
  read -rp 'set SSH port:' ssh_port
  sed -i 's/^[#\s]*Port.*/Port '${ssh_port}'/g' $sshdPwd
  # 禁用Xshell等终端登录root账户
  sed -i 's/^[#\s]*PermitRootLogin.*/PermitRootLogin no/g' $sshdPwd

  systemctl restart sshd.service
}

function setSwap() {
  # 增加1GB大小的交换分区（内存的2倍）
  dd if=/dev/zero of=/root/swapfile bs=1M count=1024
  # 格式化为交换分区文件
  mkswap /root/swapfile
  # 启用交换分区文件
  swapon /root/swapfile
  # 备份fstab
  cd /etc || exit
  if [ -f "/etc/fstab.bak" ]
    then
    rm -rf fstab.bak #删除之前的备份
    else
    cp /etc/fstab /etc/fstab.bak #备份fstab
  fi
  #增加新的swap开机自动启动
  echo '/root/swapfile swap swap defaults 0 0'>>/etc/fstab

  # 修改 swappiness
  sysctlPwd=/etc/sysctl.conf
  cp $sysctlPwd $sysctlPwd".bak"
  swappiness=60
  grep -q 'vm.swappiness' $sysctlPwd \
  && sed -i "s/.*vm.swappiness.*/vm.swappiness = ${swappiness}/g" $sysctlPwd \
  || echo "vm.swappiness = ${swappiness}" >> $sysctlPwd

  sysctl -p
}

function disableFirewall() {
  systemctl stop firewalld.service     # 停止firewall
  systemctl disable firewalld.service  # 禁止firewall开机启动
}
function disableSelinux() {
  selinuxPwd=/etc/selinux/config
  cp $selinuxPwd $selinuxPwd".bak"
  sed -i 's/.*SELINUX\s*=\s*enforcing.*/SELINUX = disabled/g' $selinuxPwd
}

echo 'set swap ...'
setSwap

echo 'set ssh ...'
sshCfg

# echo 'disable selinux...'
# disableSelinux
echo 'disable firewall...'
disableFirewall

echo 'creat user:'
userAdd
