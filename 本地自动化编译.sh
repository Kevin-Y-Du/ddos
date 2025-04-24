git clone https://github.com/aa123330/test.git#!/bin/bash

# 记录开始时间
START_TIME=$(date +%s)

# 设置自动选择y
export DEBIAN_FRONTEND=noninteractive

# 添加GitHub连通性检测
check_github_connectivity() {
    local test_repo="https://github.com/aa123330/test.git"
    local temp_dir=$(mktemp -d)
    
    echo "正在检测GitHub连通性..."
    
    # 设置超时10秒防止长时间阻塞
    if timeout 10 git clone "$test_repo" "$temp_dir" >/dev/null 2>&1; then
        echo "GitHub连接验证成功"
        # 清理测试目录及git缓存
        rm -rf "$temp_dir"
        git config --global --unset http.https://github.com/.extraheader >/dev/null 2>&1
        return 0
    else
        echo "错误：无法连接至GitHub，请检查网络或代理设置" >&2
        # 强制清理残留文件
        rm -rf "$temp_dir"
        git config --global --unset http.https://github.com/.extraheader >/dev/null 2>&1
        return 1
    fi
}

# 执行连通性检测
if ! check_github_connectivity; then
    exit 1
fi

# 增加交换空间（至少16GB）
sudo swapoff -a
sudo fallocate -l 16G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 必须设置的参数
export CPU="sm8750"                  # 分支名称
export FEIL="oneplus_ace5_pro"       # 配置文件
export ANDROID_VERSION="android15"    # 安卓版本
export KERNEL_VERSION="6.6"           # 内核版本
export KERNEL_NAME="-android15-8-g013ec21bba94-abogki383916444"

# 可选参数
export SUSFS_ENABLED="true"          # 启用SUSFS
export VFS_patch_ENABLED="enable"    # 启用VFS补丁
export kernelsu_variant="SukiSU-Ultra" # 选择KSU版本
export kernelsu_version="main"       # KSU分支

# 1. 创建编译目录
mkdir -p ~/kernel_build && cd ~/kernel_build

# 2. 安装系统依赖
sudo apt update && yes | sudo apt upgrade -y
sudo apt install -y \
    python3 git curl repo ccache \
    build-essential flex bison libssl-dev \
    libelf-dev bc kmod cpio lz4 zip

# 3. 配置Git
git config --global user.name "build"
git config --global user.email "12345@qq.com"

# 检查是否有编译缓存，如果有则清除
if [ -d "out" ] || [ -d ".cache" ] || [ -d "dist" ]; then
    echo "检测到编译缓存，正在清除..."
    rm -rf out
    rm -rf .cache
    rm -rf dist/Image dist/*.img dist/oImage
    echo "编译缓存已清除"
fi

# 检查是否已存在源码
if [ -d "kernel_platform" ]; then
    echo "检测到本地已存在源码，准备恢复初始状态并更新..."
    
    # 恢复初始状态
    cd kernel_platform
    git reset --hard
    git clean -fdx
    
    # 如果存在msm-kernel目录，也恢复它
    if [ -d "msm-kernel" ]; then
        cd msm-kernel
        git reset --hard
        git clean -fdx
        cd ..
    fi
    
    # 如果存在common目录，也恢复它
    if [ -d "common" ]; then
        cd common
        git reset --hard
        git clean -fdx
        cd ..
    fi
    
    # 返回上级目录并更新代码
    cd ..
    yes | repo sync -c -j$(nproc --all) --no-tags
    
    echo "源码已恢复初始状态并更新完成"
else
    echo "未检测到本地源码，准备初始化并同步代码..."
    
    # 1. 初始化repo
    yes | repo init -u https://github.com/JiuGeFaCai/kernel_manifest.git \
        -b refs/heads/oneplus/$CPU \
        -m $FEIL.xml \
        --depth=1

    # 2. 同步代码
    yes | repo sync -c -j$(nproc --all) --no-tags
    
    echo "源码初始化并同步完成"
fi

# 3. 清理保护符号
rm -f kernel_platform/common/android/abi_gki_protected_exports_*
rm -f kernel_platform/msm-kernel/android/abi_gki_protected_exports_*

# 4. 修复dirty标记
sed -i 's/ -dirty//g' kernel_platform/common/scripts/setlocalversion
sed -i 's/ -dirty//g' kernel_platform/msm-kernel/scripts/setlocalversion

cd kernel_platform

# 检查是否已存在KernelSU目录
if [ -d "KernelSU" ]; then
    echo "检测到KernelSU目录，准备更新..."
    cd KernelSU
    git reset --hard
    yes | git pull origin main
    cd ..
else
    # SukiSU-Ultra版本
    echo "未检测到KernelSU目录，准备安装SukiSU-Ultra..."
    yes | curl -LSs "https://raw.githubusercontent.com/ShirkNeko/SukiSU-Ultra/main/kernel/setup.sh" | bash -s susfs-dev
fi

# 计算KSU版本
cd KernelSU
KSU_VERSION=$(expr $(git rev-list --count main) "+" 10606)
sed -i "s/DKSU_VERSION=12800/DKSU_VERSION=${KSU_VERSION}/" kernel/Makefile
cd ..

# 检查并清理旧的补丁目录
if [ -d "susfs4ksu" ]; then
    rm -rf susfs4ksu
fi
if [ -d "SukiSU_patch" ]; then
    rm -rf SukiSU_patch
fi

# 克隆补丁仓库
yes | git clone https://gitlab.com/simonpunk/susfs4ksu.git -b gki-$ANDROID_VERSION-$KERNEL_VERSION
yes | git clone https://github.com/ExmikoN/SukiSU_patch.git

# 复制补丁文件
cp -v susfs4ksu/kernel_patches/50_add_susfs_in_gki-*.patch common/
cp -rv susfs4ksu/kernel_patches/fs/* common/fs/
cp -rv susfs4ksu/kernel_patches/include/linux/* common/include/linux/

# 应用核心补丁
cd common
cp -rv ./../SukiSU_patch/other/lz4k/crypto/* ./crypto/
cp -rv ./../SukiSU_patch/other/lz4k/include/linux/* ./include/linux/
cp -rv ./../SukiSU_patch/other/lz4k/lib/* ./lib/
yes | patch -p1 < 50_add_susfs_in_gki-$ANDROID_VERSION-$KERNEL_VERSION.patch
rm -f fs/namespace.c*  # 强制替换关键文件
cp ./../SukiSU_patch/namespace.c fs/

# 隐藏补丁
cp ./../SukiSU_patch/69_hide_stuff.patch ./
yes | patch -p1 -F 3 < 69_hide_stuff.patch

# VFS钩子补丁
if [ "$VFS_patch_ENABLED" = "enable" ]; then
    cp ./../SukiSU_patch/hooks/syscall_hooks.patch ./
    yes | patch -p1 -F 3 < syscall_hooks.patch
    cp ./../SukiSU_patch/other/lz4k_patch/$KERNEL_VERSION/lz4kd.patch ./
    yes | patch -p1 -F 3 < lz4kd.patch
fi

# 追加SUSFS配置
cat << EOF >> arch/arm64/configs/gki_defconfig
CONFIG_KSU=y
CONFIG_KPM=y
CONFIG_KSU_SUSFS_SUS_SU=n
CONFIG_KSU_MANUAL_HOOK=y
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y
CONFIG_KSU_SUSFS_SUS_PATH=y
CONFIG_KSU_SUSFS_SUS_MOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y
CONFIG_KSU_SUSFS_SUS_KSTAT=y
CONFIG_KSU_SUSFS_SUS_OVERLAYFS=n
CONFIG_KSU_SUSFS_TRY_UMOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT=y
CONFIG_KSU_SUSFS_SPOOF_UNAME=y
CONFIG_KSU_SUSFS_ENABLE_LOG=y
CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y
CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y
CONFIG_KSU_SUSFS_OPEN_REDIRECT=y
CONFIG_CRYPTO_LZ4HC=y
CONFIG_CRYPTO_LZ4K=y
CONFIG_CRYPTO_LZ4KD=y
CONFIG_CRYPTO_842=y
CONFIG_DEBUG_INFO_BTF_MODULES=y
EOF

# 禁用defconfig检查
sed -i 's/check_defconfig//' build.config.gki

# 修改版本标记
cd ~/kernel_build/kernel_platform
if [[ "$KERNEL_VERSION" == "6.1" || "$KERNEL_VERSION" == "6.6" ]]; then
    sed -i "/stable_scmversion_cmd/s/-maybe-dirty//g" build/kernel/kleaf/impl/stamp.bzl
fi

# 注入自定义名称
cd ~/kernel_build/kernel_platform/common
sed -i '$s|echo "$res"|echo "'$KERNEL_NAME'"|' scripts/setlocalversion

# 1. 使用LLVM工具链
export PATH="/usr/lib/llvm-16/bin:$PATH"

# 2. Bazel编译命令（增加内存限制）
cd ~/kernel_build/kernel_platform
yes | tools/bazel run --config=fast --config=stamp --lto=thin //common:kernel_aarch64_dist -- --dist_dir=dist

# 3. 处理编译产物
cd dist
curl -LO https://github.com/ShirkNeko/SukiSU_KernelPatch_patch/releases/download/0.11-beta/patch_linux
chmod +x patch_linux && ./patch_linux
mv oImage Image

# 1. 准备AnyKernel3
yes | git clone https://github.com/WildPlusKernel/AnyKernel3.git --depth=1
rm -rf AnyKernel3/.git
cp Image AnyKernel3/
# 2. 验证产物
file AnyKernel3/Image  # 应显示"Linux kernel ARM64 executable"
# 3.打包Ak3刷机包
cd AnyKernel3/
zip -r A5p_lz4kd.zip *

# 计算并显示总耗时
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
HOURS=$((TOTAL_TIME / 3600))
MINUTES=$(( (TOTAL_TIME % 3600) / 60 ))
SECONDS=$((TOTAL_TIME % 60))
echo "Total execution time: ${HOURS}h ${MINUTES}m ${SECONDS}s"