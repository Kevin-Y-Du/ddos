好的，收到您的脚本了。这是一个用于编译 Android 内核的 Bash 脚本，它依赖于 repo 工具、特定的编译器（这里强制使用了 LLVM 16）以及其他一些构建工具。
这个脚本在 Linux 环境下是通用的，但是在不同的发行版上运行，需要确保所有依赖项都已正确安装，并且路径设置正确。在 Debian 12 上运行这个脚本，主要需要关注以下几点：
 * repo 工具的安装： repo 是 Google 开发的用于管理多个 Git 仓库的工具，通常不包含在 Debian 的默认软件仓库中，需要手动安装。
 * 构建依赖： 脚本中列出了一些依赖，但可能还需要一些 Android 构建常用的其他工具，尤其是 Bazel 所需的 Java 环境以及脚本明确指定的 LLVM 版本。
 * LLVM 版本和路径： 脚本强制将 /usr/lib/llvm-16/bin 加入 PATH。需要确保系统中确实安装了 llvm-16、clang-16 和 lld-16。
我将为您修改脚本，添加 repo 和其他关键依赖的安装步骤，使其更适合在干净的 Debian 12 环境中运行。
#!/bin/bash

# 记录开始时间
START_TIME=$(date +%s)

# 设置自动选择y
# export DEBIAN_FRONTEND=noninteractive # 脚本中使用-y参数更常见，这里保留，但下面的apt命令会用-y

# 添加GitHub连通性检测
check_github_connectivity() {
    local test_repo="https://github.com/aa123330/test.git"
    local temp_dir=$(mktemp -d)

    echo "正在检测GitHub连通性..."

    # 设置超时10秒防止长时间阻塞
    # 注意：某些网络环境下（如国内），直接连接GitHub可能不稳定。
    # 如果经常失败，可能需要配置代理或使用镜像。
    if timeout 20 git clone "$test_repo" "$temp_dir" >/dev/null 2>&1; then # 增加超时时间到20秒
        echo "GitHub连接验证成功"
        # 清理测试目录及git缓存
        rm -rf "$temp_dir"
        #git config --global --unset http.https://github.com/.extraheader >/dev/null 2>&1 # 这行通常不需要
        return 0
    else
        echo "错误：无法连接至GitHub，请检查网络或代理设置" >&2
        # 强制清理残留文件
        rm -rf "$temp_dir"
        #git config --global --unset http.https://github.com/.extraheader >/dev/null 2>&1 # 这行通常不需要
        return 1
    fi
}

# 执行连通性检测
if ! check_github_connectivity; then
    exit 1
fi

# 增加交换空间（至少16GB）- 编译大型项目建议
echo "正在检查或增加交换空间..."
SWAP_SIZE_GB=16
SWAP_FILE="/swapfile_${SWAP_SIZE_GB}G"

# 检查是否存在并激活同名或已知的大交换文件
if ! swapon --show | grep -q "/swapfile" && ! swapon --show | grep -q "$SWAP_FILE"; then
    if [ ! -f "$SWAP_FILE" ]; then
        echo "创建 ${SWAP_SIZE_GB}GB 交换文件..."
        sudo fallocate -l ${SWAP_SIZE_GB}G "$SWAP_FILE"
        if [ $? -ne 0 ]; then
            echo "错误：创建交换文件失败，请检查磁盘空间或权限。" >&2
            # 尝试使用dd备用方法（较慢）
            echo "尝试使用dd创建交换文件（可能较慢）..."
            sudo dd if=/dev/zero of="$SWAP_FILE" bs=1M count=$((${SWAP_SIZE_GB} * 1024))
            if [ $? -ne 0 ]; then
                echo "错误：使用dd创建交换文件也失败。请检查磁盘空间或权限。" >&2
                exit 1
            fi
        fi
        sudo chmod 600 "$SWAP_FILE"
        sudo mkswap "$SWAP_FILE"
        echo "交换文件创建完成。"
    fi

    echo "激活交换空间..."
    sudo swapon "$SWAP_FILE"
    if [ $? -ne 0 ]; then
        echo "错误：激活交换空间失败。请手动检查 '/etc/fstab' 或确保文件正确。" >&2
        exit 1
    fi
    echo "交换空间已激活。"
else
    echo "检测到已有交换空间，跳过创建。"
fi
# 可以在此处考虑将交换文件添加到 /etc/fstab 以便重启后自动挂载，但脚本不修改系统文件，用户可自行添加。
# echo "$SWAP_FILE none swap sw 0 0" | sudo tee -a /etc/fstab

# 必须设置的参数
export CPU="sm8750"                  # 分支名称
export FEIL="oneplus_ace5_pro"       # 配置文件
export ANDROID_VERSION="android15"    # 安卓版本
export KERNEL_VERSION="6.6"           # 内核版本
export KERNEL_NAME="-android15-8-g013ec21bba94-abogki383916444" # 通常这个值会自动生成，直接写死可能不是最佳做法

# 可选参数
export SUSFS_ENABLED="true"          # 启用SUSFS
export VFS_patch_ENABLED="enable"    # 启用VFS补丁
export kernelsu_variant="SukiSU-Ultra" # 选择KSU版本
export kernelsu_version="main"       # KSU分支

# 1. 创建编译目录
echo "创建并进入编译目录 ~/kernel_build"
mkdir -p ~/kernel_build && cd ~/kernel_build || { echo "错误：无法创建或进入编译目录"; exit 1; }

# 2. 安装系统依赖
echo "正在更新系统并安装编译依赖..."
# 使用-y参数代替yes |，并添加 Bazel 所需的 openjdk 和脚本强制使用的 LLVM 16 工具链
sudo apt update && sudo apt upgrade -y
sudo apt install -y \
    python3 git curl repo ccache \
    build-essential flex bison libssl-dev \
    libelf-dev bc kmod cpio lz4 zip \
    openjdk-11-jdk \
    llvm-16 clang-16 lld-16

# 检查安装是否成功
if [ $? -ne 0 ]; then
    echo "错误：安装依赖失败。请检查apt源或手动安装缺少的软件包。" >&2
    exit 1
fi
echo "依赖安装完成。"

# **在安装repo包失败时，手动安装repo工具**
# 如果上面的apt install repo成功，则跳过此步
if ! command -v repo &> /dev/null; then
    echo "repo 命令未找到，正在尝试手动安装 repo 工具..."
    mkdir -p ~/.bin
    PATH="${HOME}/.bin:${PATH}"
    curl https://storage.googleapis.com/git-repo-downloads/repo > ~/.bin/repo
    if [ $? -ne 0 ]; then
        echo "错误：下载 repo 工具失败。" >&2
        exit 1
    fi
    chmod a+x ~/.bin/repo
    echo "repo 工具安装完成至 ~/.bin。已添加到当前会话的 PATH。"
    # 建议将 ~/.bin 永久添加到用户的 PATH 环境变量中
    echo "提示：建议将 'export PATH=\"\$HOME/.bin:\$PATH\"' 添加到您的 ~/.bashrc 或 ~/.profile 文件中，以便repo命令永久可用。"
else
    echo "repo 命令已找到，跳过手动安装。"
fi


# 3. 配置Git
echo "配置Git用户信息..."
git config --global user.name "build"
git config --global user.email "12345@qq.com"
echo "Git配置完成。"

# 检查是否有编译缓存，如果有则清除
if [ -d "out" ] || [ -d ".cache" ] || [ -d "dist" ]; then
    echo "检测到编译缓存，正在清除..."
    # 检查dist目录内的特定文件是否存在再删除，防止误删
    if [ -d "dist" ]; then
        rm -f dist/Image dist/*.img dist/oImage
    fi
    rm -rf out .cache
    echo "编译缓存已清除"
fi

# 检查是否已存在源码
if [ -d "kernel_platform" ]; then
    echo "检测到本地已存在源码，准备恢复初始状态并更新..."

    cd kernel_platform || { echo "错误：无法进入 kernel_platform 目录"; exit 1; }

    # 恢复初始状态
    echo "正在恢复 kernel_platform 仓库到初始状态..."
    git reset --hard
    git clean -fdx

    # 如果存在msm-kernel目录，也恢复它
    if [ -d "msm-kernel" ]; then
        echo "正在恢复 msm-kernel 仓库到初始状态..."
        cd msm-kernel || { echo "错误：无法进入 msm-kernel 目录"; exit 1; }
        git reset --hard
        git clean -fdx
        cd ..
    fi

    # 如果存在common目录，也恢复它
    if [ -d "common" ]; then
        echo "正在恢复 common 仓库到初始状态..."
        cd common || { echo "错误：无法进入 common 目录"; exit 1; }
        git reset --hard
        git clean -fdx
        cd ..
    fi

    # 返回上级目录并更新代码
    cd .. # 返回 ~/kernel_build
    echo "正在同步代码仓库..."
    # yes | repo sync -c -j$(nproc --all) --no-tags # 使用-c表示当前分支，-j指定线程数
    repo sync -c -j$(nproc --all) --no-tags
     if [ $? -ne 0 ]; then
        echo "错误：repo sync 失败。" >&2
        echo "可能原因：网络问题，manifest文件错误，或其他repo同步问题。" >&2
        exit 1
    fi
    echo "源码已恢复初始状态并更新完成"
else
    echo "未检测到本地源码，准备初始化并同步代码..."

    # 1. 初始化repo
    echo "正在初始化 repo 仓库..."
    # yes | repo init ... # 使用 -y 参数，但repo init通常是交互式的，除非指定非交互选项或输入y
    repo init -u https://github.com/JiuGeFaCai/kernel_manifest.git \
        -b refs/heads/oneplus/$CPU \
        -m $FEIL.xml \
        --depth=1 # --depth=1 只克隆最新提交，节省空间和时间
    if [ $? -ne 0 ]; then
        echo "错误：repo init 失败。请检查manifest URL、分支或配置文件名是否正确。" >&2
        exit 1
    fi
    echo "repo 初始化完成。"

    # 2. 同步代码
    echo "正在同步代码仓库..."
    # yes | repo sync ...
    repo sync -c -j$(nproc --all) --no-tags
     if [ $? -ne 0 ]; then
        echo "错误：repo sync 失败。" >&2
        echo "可能原因：网络问题，manifest文件错误，或其他repo同步问题。" >&2
        exit 1
    fi
    echo "源码初始化并同步完成"
fi

# 进入 kernel_platform 目录进行后续操作
cd kernel_platform || { echo "错误：无法进入 kernel_platform 目录"; exit 1; }

# 3. 清理保护符号
echo "清理保护符号文件..."
rm -f common/android/abi_gki_protected_exports_*
rm -f msm-kernel/android/abi_gki_protected_exports_*
echo "清理完成。"

# 4. 修复dirty标记
echo "修复构建脚本中的 dirty 标记..."
sed -i 's/ -dirty//g' common/scripts/setlocalversion
sed -i 's/ -dirty//g' msm-kernel/scripts/setlocalversion
echo "修复完成。"

# 检查是否已存在KernelSU目录
if [ -d "KernelSU" ]; then
    echo "检测到KernelSU目录，准备更新..."
    cd KernelSU || { echo "错误：无法进入 KernelSU 目录"; exit 1; }
    git reset --hard
    yes | git pull origin main # yes | git pull 是为了确认可能的合并或rebase提示
    cd .. # 返回 kernel_platform
else
    # SukiSU-Ultra版本
    echo "未检测到KernelSU目录，准备安装SukiSU-Ultra..."
    # 安全警告：通过curl直接执行脚本存在安全风险，请确认脚本来源可信。
    echo "警告：正在通过 curl 执行远程脚本安装 SukiSU-Ultra。请确认您信任源地址。"
    yes | curl -LSs "https://raw.githubusercontent.com/ShirkNeko/SukiSU-Ultra/main/kernel/setup.sh" | bash -s susfs-dev
    if [ $? -ne 0 ]; then
        echo "错误：SukiSU-Ultra 安装脚本执行失败。" >&2
        exit 1
    fi
fi
echo "KernelSU/SukiSU 处理完成。"

# 计算KSU版本
echo "计算 KernelSU 版本..."
cd KernelSU || { echo "错误：无法进入 KernelSU 目录"; exit 1; }
# 使用 git rev-list --count 获取提交数量，并增加基数。expr已弃用，推荐使用 $(( ))
# KSU_VERSION=$(expr $(git rev-list --count main) "+" 10606)
KSU_VERSION=$(( $(git rev-list --count main) + 10606 ))
sed -i "s/DKSU_VERSION=12800/DKSU_VERSION=${KSU_VERSION}/" kernel/Makefile
cd .. # 返回 kernel_platform
echo "KernelSU 版本设置为 DKSU_VERSION=${KSU_VERSION}。"


# 检查并清理旧的补丁目录
echo "清理旧的补丁目录..."
if [ -d "susfs4ksu" ]; then
    rm -rf susfs4ksu
fi
if [ -d "SukiSU_patch" ]; then
    rm -rf SukiSU_patch
fi
echo "清理完成。"

# 克隆补丁仓库
echo "克隆补丁仓库..."
yes | git clone https://gitlab.com/simonpunk/susfs4ksu.git -b gki-$ANDROID_VERSION-$KERNEL_VERSION
if [ $? -ne 0 ]; then echo "错误：克隆 susfs4ksu 失败"; exit 1; fi
yes | git clone https://github.com/ExmikoN/SukiSU_patch.git
if [ $? -ne 0 ]; then echo "错误：克隆 SukiSU_patch 失败"; exit 1; fi
echo "补丁仓库克隆完成。"

# 复制补丁文件
echo "复制补丁文件..."
# 检查源文件/目录是否存在
if [ -f "susfs4ksu/kernel_patches/50_add_susfs_in_gki-$ANDROID_VERSION-$KERNEL_VERSION.patch" ]; then
    cp -v susfs4ksu/kernel_patches/50_add_susfs_in_gki-$ANDROID_VERSION-$KERNEL_VERSION.patch common/
else
    echo "错误：未找到主 SUSFS 补丁文件：susfs4ksu/kernel_patches/50_add_susfs_in_gki-$ANDROID_VERSION-$KERNEL_VERSION.patch" >&2
    exit 1
fi

if [ -d "susfs4ksu/kernel_patches/fs" ]; then
    cp -rv susfs4ksu/kernel_patches/fs/* common/fs/
else
    echo "警告：未找到 susfs4ksu/kernel_patches/fs 目录，跳过复制。"
fi

if [ -d "susfs4ksu/kernel_patches/include/linux" ]; then
    cp -rv susfs4ksu/kernel_patches/include/linux/* common/include/linux/
else
    echo "警告：未找到 susfs4ksu/kernel_patches/include/linux 目录，跳过复制。"
fi
echo "补丁文件复制完成。"


# 应用核心补丁
echo "应用核心补丁..."
cd common || { echo "错误：无法进入 common 目录"; exit 1; }

if [ -d "./../SukiSU_patch/other/lz4k/crypto" ]; then
    cp -rv ./../SukiSU_patch/other/lz4k/crypto/* ./crypto/
else
     echo "警告：未找到 ../SukiSU_patch/other/lz4k/crypto 目录，跳过复制。"
fi
if [ -d "./../SukiSU_patch/other/lz4k/include/linux" ]; then
    cp -rv ./../SukiSU_patch/other/lz4k/include/linux/* ./include/linux/
else
    echo "警告：未找到 ../SukiSU_patch/other/lz4k/include/linux 目录，跳过复制。"
fi
if [ -d "./../SukiSU_patch/other/lz4k/lib" ]; then
    cp -rv ./../SukiSU_patch/other/lz4k/lib/* ./lib/
else
    echo "警告：未找到 ../SukiSU_patch/other/lz4k/lib 目录，跳过复制。"
fi

echo "应用 50_add_susfs_in_gki 补丁..."
if [ -f "50_add_susfs_in_gki-$ANDROID_VERSION-$KERNEL_VERSION.patch" ]; then
    yes | patch -p1 -F 3 < "50_add_susfs_in_gki-$ANDROID_VERSION-$KERNEL_VERSION.patch"
    if [ $? -ne 0 ]; then echo "错误：应用 50_add_susfs_in_gki 补丁失败"; exit 1; fi
else
    echo "错误：未找到要应用的 50_add_susfs_in_gki 补丁文件！" >&2
    exit 1
fi

echo "强制替换 namespace.c 文件..."
if [ -f "./../SukiSU_patch/namespace.c" ]; then
    rm -f fs/namespace.c* # 强制替换关键文件
    cp ./../SukiSU_patch/namespace.c fs/
else
    echo "错误：未找到要复制的 namespace.c 文件！" >&2
    exit 1
fi
echo "namespace.c 替换完成。"

echo "应用 69_hide_stuff.patch 隐藏补丁..."
if [ -f "./../SukiSU_patch/69_hide_stuff.patch" ]; then
    cp ./../SukiSU_patch/69_hide_stuff.patch ./
    yes | patch -p1 -F 3 < 69_hide_stuff.patch
     if [ $? -ne 0 ]; then echo "警告：应用 69_hide_stuff.patch 补丁失败，但这可能不是致命错误。"; fi # 隐藏补丁失败可能是非致命的
else
    echo "警告：未找到 69_hide_stuff.patch 文件，跳过应用。"
fi

# VFS钩子补丁
if [ "$VFS_patch_ENABLED" = "enable" ]; then
    echo "VFS补丁已启用，正在应用..."
    if [ -f "./../SukiSU_patch/hooks/syscall_hooks.patch" ]; then
        cp ./../SukiSU_patch/hooks/syscall_hooks.patch ./
        yes | patch -p1 -F 3 < syscall_hooks.patch
        if [ $? -ne 0 ]; then echo "警告：应用 syscall_hooks.patch 补丁失败，但这可能不是致命错误。"; fi # 钩子补丁失败可能是非致命的
    else
        echo "警告：未找到 syscall_hooks.patch 文件，跳过应用。"
    fi

    if [ -f "./../SukiSU_patch/other/lz4k_patch/$KERNEL_VERSION/lz4kd.patch" ]; then
        cp ./../SukiSU_patch/other/lz4k_patch/$KERNEL_VERSION/lz4kd.patch ./
        yes | patch -p1 -F 3 < lz4kd.patch
        if [ $? -ne 0 ]; then echo "警告：应用 lz4kd.patch 补丁失败，但这可能不是致命错误。"; fi # lz4kd 补丁失败可能是非致命的
    else
        echo "警告：未找到 lz4k_patch/$KERNEL_VERSION/lz4kd.patch 文件，跳过应用。"
    fi
else
    echo "VFS补丁未启用，跳过应用。"
fi
echo "补丁应用完成。"

# 追加SUSFS配置
echo "追加 SUSFS 配置到 arch/arm64/configs/gki_defconfig..."
cat << EOF >> arch/arm64/configs/gki_defconfig

# Added by build script for KSU/SUSFS config
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
# End of build script config
EOF
echo "SUSFS 配置追加完成。"

# 禁用defconfig检查
echo "禁用 defconfig 检查..."
sed -i 's/check_defconfig//' build.config.gki
echo "禁用完成。"

# 修改版本标记 (回到 kernel_platform 目录)
cd ~/kernel_build/kernel_platform || { echo "错误：无法返回 kernel_platform 目录"; exit 1; }
echo "修改版本标记脚本..."
if [[ "$KERNEL_VERSION" == "6.1" || "$KERNEL_VERSION" == "6.6" ]]; then
    sed -i "/stable_scmversion_cmd/s/-maybe-dirty//g" build/kernel/kleaf/impl/stamp.bzl
fi

# 注入自定义名称 (回到 kernel_platform 目录)
# cd common || { echo "错误：无法进入 common 目录"; exit 1; } # 上面已经在common目录了，这里需要先返回
# cd .. # 已经回到 kernel_platform

echo "注入自定义内核名称到 setlocalversion 脚本..."
# 确保只替换最后一行，并且是在 common 目录下的文件
sed -i '$s|echo "$res"|echo "'$KERNEL_NAME'"|' common/scripts/setlocalversion
echo "自定义名称注入完成。"

# 1. 使用LLVM工具链
echo "设置 LLVM-16 工具链路径..."
# 确保路径正确，且 LLVM 16 已安装
export PATH="/usr/lib/llvm-16/bin:$PATH"
echo "LLVM-16 工具链路径设置完成。"

# 2. Bazel编译命令（增加内存限制）
cd ~/kernel_build/kernel_platform || { echo "错误：无法进入 kernel_platform 目录进行编译"; exit 1; }
echo "正在使用 Bazel 编译内核..."
# 这里的 yes | 也是多余的，因为 Bazel 本身是非交互式的，或者BazelWrapper处理了交互
# --config=fast 和 --config=stamp 来自 build.config.gki 或 Bazel 配置
# --lto=thin 启用 ThinLTO
# //common:kernel_aarch64_dist 是 Bazel 目标
# -- --dist_dir=dist 设置输出目录
tools/bazel run --config=fast --config=stamp --lto=thin //common:kernel_aarch64_dist -- --dist_dir=dist
if [ $? -ne 0 ]; then
    echo "错误：Bazel 编译失败！" >&2
    echo "请检查 Bazel 输出的详细错误信息，可能原因包括：代码错误、依赖问题、内存不足等。" >&2
    exit 1
fi
echo "Bazel 编译完成。"


# 3. 处理编译产物
echo "处理编译产物..."
cd dist || { echo "错误：无法进入 dist 目录"; exit 1; }

echo "下载并执行 patch_linux 工具..."
curl -LO https://github.com/ShirkNeko/SukiSU_KernelPatch_patch/releases/download/0.11-beta/patch_linux
if [ $? -ne 0 ]; then echo "错误：下载 patch_linux 失败"; exit 1; fi
chmod +x patch_linux
./patch_linux
if [ $? -ne 0 ]; then echo "错误：执行 patch_linux 失败"; exit 1; fi
mv oImage Image
if [ $? -ne 0 ]; then echo "错误：移动 oImage 到 Image 失败"; exit 1; fi
echo "编译产物处理完成。"


# 1. 准备AnyKernel3
echo "准备 AnyKernel3 打包..."
cd ~/kernel_build || { echo "错误：无法回到 ~/kernel_build 目录"; exit 1; } # 回到编译根目录
yes | git clone https://github.com/WildPlusKernel/AnyKernel3.git --depth=1
if [ $? -ne 0 ]; then echo "错误：克隆 AnyKernel3 失败"; exit 1; }
rm -rf AnyKernel3/.git # 移除git信息，减小打包体积
cp dist/Image AnyKernel3/ # 从 dist 目录复制 Image 到 AnyKernel3 目录

# 2. 验证产物
echo "验证编译产物 Image 文件类型..."
file AnyKernel3/Image  # 应显示"Linux kernel ARM64 executable"

# 3.打包Ak3刷机包
echo "正在打包 AnyKernel3 刷机包..."
cd AnyKernel3/ || { echo "错误：无法进入 AnyKernel3 目录进行打包"; exit 1; }
zip -r A5p_lz4kd.zip *
if [ $? -ne 0 ]; then
    echo "错误：AnyKernel3 打包失败。" >&2
    exit 1
fi
echo "刷机包 A5p_lz4kd.zip 已创建在 $(pwd)/A5p_lz4kd.zip"

# 返回编译根目录方便查看产物
cd ~/kernel_build || { echo "错误：无法返回 ~/kernel_build 目录"; exit 1; }


# 计算并显示总耗时
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
HOURS=$((TOTAL_TIME / 3600))
MINUTES=$(( (TOTAL_TIME % 3600) / 60 ))
SECONDS=$((TOTAL_TIME % 60))
echo "=================================================="
echo "编译过程结束。"
echo "刷机包位于: ~/kernel_build/AnyKernel3/A5p_lz4kd.zip"
echo "总耗时: ${HOURS} 小时 ${MINUTES} 分钟 ${SECONDS} 秒"
echo "=================================================="

exit 0 # 脚本成功完成
