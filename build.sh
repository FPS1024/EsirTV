#!/bin/bash
#
# EsirTV 编译 + TrollStore（巨魔商店）IPA 打包脚本
#
# 用法:
#   ./build.sh          # 编译并打包
#   ./build.sh clean    # 清理 build 目录后重新编译打包
#
# 输出:
#   build/ipa/EsirTV-<版本号>-arm64.ipa
#
# TrollStore 安装: 将 ipa 传到设备后用巨魔商店安装即可。
# 若安装失败，请安装 ldid 后对包体签名: brew install ldid
#

set -euo pipefail

# ---------- 可配置项 ----------
PROJECT_NAME="EsirTV"
SCHEME="EsirTV"
CONFIGURATION="Release"
SDK="iphoneos"
ARCH="arm64"

# ---------- 路径 ----------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_PATH="${SCRIPT_DIR}/${PROJECT_NAME}.xcodeproj"
BUILD_ROOT="${SCRIPT_DIR}/build"
DERIVED_DATA="${BUILD_ROOT}/DerivedData"
PAYLOAD_DIR="${BUILD_ROOT}/Payload"
PRODUCTS_DIR="${DERIVED_DATA}/Build/Products/${CONFIGURATION}-${SDK}"
APP_NAME="${PROJECT_NAME}.app"
APP_PATH="${PRODUCTS_DIR}/${APP_NAME}"
IPA_DIR="${BUILD_ROOT}/ipa"

# ---------- 工具函数 ----------
die() {
    echo "错误: $*" >&2
    exit 1
}

info() {
    echo "==> $*"
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "未找到命令: $1"
}

# 查找完整 Xcode（Command Line Tools 无法编译 iOS 真机包）
setup_xcode_developer_dir() {
    local candidates=(
        "${DEVELOPER_DIR:-}"
        "/Applications/Xcode.app/Contents/Developer"
        "$HOME/Applications/Xcode.app/Contents/Developer"
    )
    local xcode_dev=""

    for dir in "${candidates[@]}"; do
        [[ -n "${dir}" && -x "${dir}/usr/bin/xcodebuild" ]] || continue
        xcode_dev="${dir}"
        break
    done

    if [[ -z "${xcode_dev}" ]]; then
        cat >&2 <<'EOF'
错误: 未找到完整版 Xcode.app

当前系统只有 Command Line Tools，无法编译 iphoneos / arm64 真机包。

请按以下步骤操作:
  1. 从 Mac App Store 安装 Xcode（约 12GB+）
  2. 打开 Xcode 一次，同意许可并完成组件安装
  3. 在终端执行（按实际安装路径选择，需输入密码）:
       sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
     或（若装在用户目录）:
       sudo xcode-select -s ~/Applications/Xcode.app/Contents/Developer
  4. 重新运行: ./build.sh clean

若不想改 xcode-select，可直接运行:
       ./build.sh clean
     （脚本会自动检测 ~/Applications/Xcode.app）
EOF
        exit 1
    fi

    export DEVELOPER_DIR="${xcode_dev}"
    local active
    active="$(xcode-select -p 2>/dev/null || echo "未知")"
    if [[ "${active}" != "${xcode_dev}" ]]; then
        info "使用 Xcode: ${xcode_dev}"
        info "提示: 当前 xcode-select 指向「${active}」，脚本已临时切换 DEVELOPER_DIR"
        info "      建议执行: sudo xcode-select -s ${xcode_dev}"
    fi
}

clean_build() {
    info "清理 build 目录..."
    rm -rf "${BUILD_ROOT}"
}

sign_app_for_trollstore() {
    local app="$1"
    local binary="${app}/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${app}/Info.plist" 2>/dev/null || echo "${PROJECT_NAME}")"

    if command -v ldid >/dev/null 2>&1; then
        info "使用 ldid 为 TrollStore 签名..."
        # 签名主程序
        ldid -S "${binary}"
        # 签名内嵌 Framework（如有）
        if [[ -d "${app}/Frameworks" ]]; then
            find "${app}/Frameworks" \( -name "*.dylib" -o -name "*.framework" \) 2>/dev/null | while read -r item; do
                if [[ -d "${item}" && "${item}" == *.framework ]]; then
                    fw_bin="${item}/$(basename "${item}" .framework)"
                    [[ -f "${fw_bin}" ]] && ldid -S "${fw_bin}" || true
                elif [[ -f "${item}" ]]; then
                    ldid -S "${item}" || true
                fi
            done
        fi
        return 0
    fi

    echo "警告: 未安装 ldid，跳过假签名。若巨魔商店无法安装，请执行: brew install ldid" >&2
    return 0
}

verify_arm64() {
    local binary="$1"
    [[ -f "${binary}" ]] || die "找不到可执行文件: ${binary}"

    if command -v lipo >/dev/null 2>&1; then
        local archs
        archs="$(lipo -info "${binary}" 2>/dev/null | sed 's/.*: //' || true)"
        info "可执行文件架构: ${archs:-未知}"

        if [[ -n "${archs}" ]] && [[ "${archs}" != *"arm64"* ]]; then
            die "产物不包含 arm64，请检查 xcodebuild 参数（当前应为 iphoneos + arm64）"
        fi
        if [[ -n "${archs}" ]] && [[ "${archs}" == *"x86_64"* || "${archs}" == *"i386"* ]]; then
            die "检测到模拟器架构，请勿使用 iphonesimulator SDK 编译"
        fi
    fi
}

package_ipa() {
    local version="$1"
    local ipa_path="${IPA_DIR}/${PROJECT_NAME}-${version}-arm64.ipa"

    rm -rf "${PAYLOAD_DIR}"
    mkdir -p "${PAYLOAD_DIR}" "${IPA_DIR}"

    info "创建 Payload 并复制 .app ..."
    ditto "${APP_PATH}" "${PAYLOAD_DIR}/${APP_NAME}"

    sign_app_for_trollstore "${PAYLOAD_DIR}/${APP_NAME}"

    info "打包 IPA: ${ipa_path}"
    rm -f "${ipa_path}"
    (
        cd "${BUILD_ROOT}"
        zip -qr "$(basename "${ipa_path}")" Payload
    )
    mv "${BUILD_ROOT}/$(basename "${ipa_path}")" "${ipa_path}"
    rm -rf "${PAYLOAD_DIR}"

    info "完成: ${ipa_path}"
    ls -lh "${ipa_path}"
}

# ---------- 主流程 ----------
main() {
    if [[ "${1:-}" == "clean" ]]; then
        clean_build
    fi

    setup_xcode_developer_dir
    require_cmd zip
    require_cmd ditto

    [[ -d "${PROJECT_PATH}" ]] || die "找不到工程: ${PROJECT_PATH}"

    mkdir -p "${BUILD_ROOT}" "${IPA_DIR}"

    info "开始编译 (${CONFIGURATION} / ${SDK} / ${ARCH}) ..."
    "${DEVELOPER_DIR}/usr/bin/xcodebuild" \
        -project "${PROJECT_PATH}" \
        -scheme "${SCHEME}" \
        -configuration "${CONFIGURATION}" \
        -sdk "${SDK}" \
        -arch "${ARCH}" \
        ONLY_ACTIVE_ARCH=NO \
        -derivedDataPath "${DERIVED_DATA}" \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        AD_HOC_CODE_SIGNING_ALLOWED=YES \
        build

    [[ -d "${APP_PATH}" ]] || die "未找到编译产物: ${APP_PATH}"

    local executable
    executable="${APP_PATH}/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${APP_PATH}/Info.plist")"
    verify_arm64 "${executable}"

    local version build_num
    version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP_PATH}/Info.plist" 2>/dev/null || echo "1.0")"
    build_num="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${APP_PATH}/Info.plist" 2>/dev/null || echo "1")"
    version="${version}-${build_num}"

    info "当前包 Build 号: ${build_num}（安装后请在「设置-关于」确认）"
    if ! /usr/libexec/PlistBuddy -c 'Print :NSAppTransportSecurity:NSAllowsArbitraryLoads' "${APP_PATH}/Info.plist" 2>/dev/null | grep -q true; then
        echo "警告: 产物 Info.plist 未包含 ATS 放行，HTTP 配置链接将无法加载" >&2
    fi

    package_ipa "${version}"
    info "若仍提示 ATS 安全连接错误，请先删除手机上的旧版 EsirTV，再安装本 IPA"
}

main "$@"
