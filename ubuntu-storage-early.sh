#!/bin/bash
sed -i -E '/^\.{3}$/d' /autoinstall.yaml
echo 'storage:' >>/autoinstall.yaml

# 禁用 swap（由 extra_cache_size 控制）
cat <<EOF >>/autoinstall.yaml
  swap:
    size: 0
EOF

# 计算 OS 分区大小
size_os=$(lsblk -bn -o SIZE /dev/disk/by-label/os)

# shellcheck disable=SC2154
if parted "/dev/$xda" print | grep '^Partition Table' | grep gpt; then
    # efi
    if [ -e /dev/disk/by-label/efi ]; then
        size_efi=$(lsblk -bn -o SIZE /dev/disk/by-label/efi)
        cat <<EOF >>/autoinstall.yaml
  config:
    - ptable: gpt
      path: /dev/$xda
      preserve: true
      type: disk
      id: disk-xda

    - device: disk-xda
      size: $size_efi
      number: 1
      preserve: true
      grub_device: true
      type: partition
      id: partition-efi
    - fstype: fat32
      volume: partition-efi
      type: format
      id: format-efi

    - device: disk-xda
      size: $size_os
      number: 2
      preserve: true
      type: partition
      id: partition-os
    - fstype: ext4
      volume: partition-os
      type: format
      id: format-os

    - path: /
      device: format-os
      type: mount
      id: mount-os
    - path: /boot/efi
      device: format-efi
      type: mount
      id: mount-efi
EOF
    else
        size_biosboot=$(parted "/dev/$xda" unit b print | grep bios_grub | awk '{print $4}' | sed 's/B$//')
        cat <<EOF >>/autoinstall.yaml
  config:
    - ptable: gpt
      path: /dev/$xda
      preserve: true
      grub_device: true
      type: disk
      id: disk-xda

    - device: disk-xda
      size: $size_biosboot
      number: 1
      preserve: true
      type: partition
      id: partition-biosboot

    - device: disk-xda
      size: $size_os
      number: 2
      preserve: true
      type: partition
      id: partition-os
    - fstype: ext4
      volume: partition-os
      type: format
      id: format-os

    - path: /
      device: format-os
      type: mount
      id: mount-os
EOF
    fi
else
    cat <<EOF >>/autoinstall.yaml
  config:
    - ptable: msdos
      path: /dev/$xda
      preserve: true
      grub_device: true
      type: disk
      id: disk-xda

    - device: disk-xda
      size: $size_os
      number: 1
      preserve: true
      type: partition
      id: partition-os
    - fstype: ext4
      volume: partition-os
      type: format
      id: format-os

    - path: /
      device: format-os
      type: mount
      id: mount-os
EOF
fi

# 如果 extra_cache_size 存在，autoinstall.yaml 会被追加 swap:size=XXM
echo "..." >>/autoinstall.yaml
