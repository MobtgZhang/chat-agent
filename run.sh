#!/bin/bash

# 开启“遇到错误立刻停止”模式
set -e

# ==========================================
# 1. 变量配置
# ==========================================
# 你的 Qt 安装路径
QT_INSTALL_DIR="/home/mobtgzhang/Qt/6.10.2/gcc_64"
BUILD_DIR="build"
EXECUTABLE_NAME="appAIChat"

echo "========================================"
echo "🚀 开始构建项目..."
echo "Qt 路径: ${QT_INSTALL_DIR}"
echo "========================================"

# ==========================================
# 2. 准备构建目录
# ==========================================
if [ ! -d "$BUILD_DIR" ]; then
    mkdir -p "$BUILD_DIR"
fi
cd "$BUILD_DIR"

# ==========================================
# 3. 执行 CMake 配置
# ==========================================
echo "⚙️  正在配置 CMake..."
# 核心：使用 CMAKE_PREFIX_PATH 告诉 CMake 去哪里找你的 Qt6
cmake -DCMAKE_PREFIX_PATH="${QT_INSTALL_DIR}" \
      -DCMAKE_BUILD_TYPE=Release \
      ..

# ==========================================
# 4. 编译项目
# ==========================================
echo "🔨 正在编译..."
# 使用全部 CPU 核心加速编译
cmake --build . --parallel $(nproc)

# ==========================================
# 5. 运行程序
# ==========================================
echo "✅ 编译成功！准备运行..."
echo "========================================"

# 设置环境变量，确保运行时加载的是你安装的 Qt 动态库，而不是系统库
export LD_LIBRARY_PATH="${QT_INSTALL_DIR}/lib:${LD_LIBRARY_PATH}"
export QML2_IMPORT_PATH="${QT_INSTALL_DIR}/qml:${QML2_IMPORT_PATH}"

# 执行编译出的程序
QT_IM_MODULE=fcitx5 ./${EXECUTABLE_NAME}
