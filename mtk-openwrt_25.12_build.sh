#!/bin/bash
# ==================================================================================
# BPI-R4 - OpenWrt 25.12 (SDK 4.3 Alpha) Build Script
# ==================================================================================

set -euo pipefail

# --- Main Configuration ---
readonly OPENWRT_REPO="https://git.openwrt.org/openwrt/openwrt.git"
#readonly OPENWRT_REPO="/home/user/repo/openwrt"
readonly OPENWRT_BRANCH="openwrt-25.12"
readonly OPENWRT_COMMIT="" 

readonly MTK_FEEDS_REPO="https://git01.mediatek.com/openwrt/feeds/mtk-openwrt-feeds"
#readonly MTK_FEEDS_REPO="/home/user/repo/mtk-openwrt-feeds"
readonly MTK_FEEDS_BRANCH="master"
readonly MTK_FEEDS_COMMIT="" 

# --- Directory Configuration ---
readonly SOURCE_DEFAULT_CONFIG_DIR="config"
readonly SOURCE_OPENWRT_PATCH_DIR="openwrt-patches"
readonly SOURCE_MTK_FEEDS_PATCH_DIR="mtk-patches"
readonly SOURCE_CUSTOM_FILES_DIR="files"
readonly OPENWRT_ADD_LIST="$SOURCE_OPENWRT_PATCH_DIR/openwrt-add-patch"
readonly MTK_ADD_LIST="$SOURCE_MTK_FEEDS_PATCH_DIR/mtk-add-patch"
readonly OPENWRT_REMOVE_LIST="$SOURCE_OPENWRT_PATCH_DIR/openwrt-remove"
readonly MTK_REMOVE_LIST="$SOURCE_MTK_FEEDS_PATCH_DIR/mtk-remove"

readonly OPENWRT_DIR="openwrt"
readonly MTK_FEEDS_DIR="mtk-feeds"
readonly SCRIPT_EXECUTABLE_NAME=$(basename "$0")

readonly RULES_FILE="$MTK_FEEDS_DIR/autobuild/unified/rules"
readonly AUTOBUILD_SCRIPT="$MTK_FEEDS_DIR/autobuild/unified/autobuild.sh"
readonly BUILD_PROFILE="filogic-mac80211-mt798x_rfb-wifi7_nic"

# --- Functions ---

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] - $1" >&2
}

check_dependencies() {
    log "--- Checking System Dependencies ---"
    local missing=0
    declare -A tools=( 
        ["git"]="git" ["make"]="build-essential" ["awk"]="gawk"
        ["dos2unix"]="dos2unix" ["rsync"]="rsync" ["patch"]="patch"
        ["mkimage"]="u-boot-tools" ["dtc"]="device-tree-compiler"
        ["python3"]="python3"
    )
    for cmd in "${!tools[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log "ERROR: Command '$cmd' not found. Please install '${tools[$cmd]}'."
            missing=1
        fi
    done
    if [ "$missing" -eq 1 ]; then exit 1; fi
    log "All dependencies met."
}

get_latest_commit_hash() {
    local repo_url=$1
    local branch=$2
    local commit_hash
    commit_hash=$(git ls-remote "$repo_url" "refs/heads/$branch" | awk '{print $1}')
    [ -z "$commit_hash" ] && exit 1
    echo "$commit_hash"
}

setup_repo() {
    local repo_url=$1
    local branch=$2
    local commit_hash=$3
    local target_dir=$4
    if [ -d "$target_dir" ]; then rm -rf "$target_dir"; fi
    git clone --branch "$branch" "$repo_url" "$target_dir"
    (cd "$target_dir" && git checkout "$commit_hash")
}

prepare_source_directory() {
    local source_dir=$1
    if [ ! -d "$source_dir" ]; then return; fi
    find "$source_dir" -type f -name ".gitkeep" -delete
    find "$source_dir" -type f -exec dos2unix {} +
    find "$source_dir" -type d -exec chmod 755 {} +
    find "$source_dir" -type f -exec chmod 644 {} +
}

remove_files_from_list() {
    local list_file=$1
    local target_dir=$2
    if [ ! -f "$list_file" ]; then return; fi
    log "Removing files listed in $list_file from $target_dir..."
    while IFS= read -r relative_path; do
        relative_path=$(echo "$relative_path" | tr -d '\r' | sed 's|^/||')
        [ -z "$relative_path" ] && continue
        if [ -e "$target_dir/$relative_path" ]; then
             log "  [Remove] $relative_path"
             rm -rf "$target_dir/$relative_path"
        fi
    done < <(grep -v -E '^\s*#|^\s*$' "$list_file")
}

apply_files_from_list() {
    local list_file=$1
    local source_dir=$2
    local target_dir=$3
    if [ ! -f "$list_file" ]; then
        log "Warning: List file '$list_file' not found. Skipping."
        return
    fi
    log "--- Applying patches from '$list_file' to '$target_dir' ---"
    while IFS= read -r line; do
        [[ "$line" =~ ^\s*# ]] || [ -z "$line" ] && continue
        local src dest
        if [[ "$line" == *":"* ]]; then
            src=$(echo "$line" | cut -d':' -f1 | tr -d '[:space:]')
            dest=$(echo "$line" | cut -d':' -f2- | tr -d '[:space:]' | sed 's|^/||')
        else
            dest=$(echo "$line" | tr -d '[:space:]' | sed 's|^/||')
            src=$(basename "$dest")
        fi
        if [ ! -f "$source_dir/$src" ]; then
            log "ERROR: Source file '$src' missing in '$source_dir'. Cannot copy to '$dest'."
            continue
        fi
        mkdir -p "$(dirname "$target_dir/$dest")"
        cp "$source_dir/$src" "$target_dir/$dest"
        log "  [Copy] $src -> $dest"
    done < <(grep -v -E '^\s*#|^\s*$' "$list_file")
}

copy_custom_files() {
    local source_dir="$SOURCE_CUSTOM_FILES_DIR"
    local target_dir="$OPENWRT_DIR/files"
    if [ -d "$source_dir" ]; then
        log "Copying custom runtime files from $source_dir..."
        mkdir -p "$target_dir"
        rsync -a "$source_dir/" "$target_dir/"
    fi
}

configure_build() {
    local defconfig_src="$SOURCE_DEFAULT_CONFIG_DIR/defconfig"
    local defconfig_dest="$MTK_FEEDS_DIR/autobuild/unified/filogic/25.12/"
    
    if [ -f "$defconfig_src" ]; then
        log "Applying custom defconfig..."
        mkdir -p "$defconfig_dest"
        cp "$defconfig_src" "$defconfig_dest"
    fi
    
}

create_feed_revision() {
    local openwrt_feeds="$OPENWRT_DIR/feeds.conf.default"
    local mtk_revision_file="$MTK_FEEDS_DIR/autobuild/unified/feed_revision"
    
    get_exact_hash() {
        local feed_name=$1
        local line
        line=$(grep -E "^src-.* $feed_name " "$openwrt_feeds" | head -n 1)
        if [ -z "$line" ]; then return 1; fi
        if [[ "$line" == *"^"* ]]; then echo "$line" | cut -d'^' -f2; return 0; fi
        if [[ "$line" == *";"* ]]; then
            local url branch resolved_hash
            url=$(echo "$line" | awk '{print $3}' | cut -d';' -f1)
            branch=$(echo "$line" | cut -d';' -f2)
            resolved_hash=$(git ls-remote "$url" "refs/heads/$branch" | awk '{print $1}')
            [ -n "$resolved_hash" ] && echo "$resolved_hash" && return 0
        fi
        return 1
    }

    > "$mtk_revision_file"
    
    log "--- Syncing Feed Revisions ---"
    awk '{print $2}' "$openwrt_feeds" | while read -r feed_name; do
        [[ -z "$feed_name" || "$feed_name" == "mtk" ]] && continue
        
        hash=$(get_exact_hash "$feed_name")
        if [ -n "$hash" ]; then
            echo "$feed_name $hash" >> "$mtk_revision_file"
            log "  - Locked $feed_name to $hash"
        else
            log "  - Warning: Could not find hash for $feed_name"
        fi
    done
}

rename_release_images() {
    local release_dir="$OPENWRT_DIR/autobuild_release"
    
    if [ ! -d "$release_dir" ]; then
        log "Warning: Release directory '$release_dir' not found. Renaming skipped."
        return
    fi

    find "$release_dir" -name "*bananapi_bpi-r4-squashfs-sysupgrade*.itb" -print0 | while IFS= read -r -d '' file; do
        local new_name="$release_dir/openwrt-mediatek-filogic-bananapi_bpi-r4-squashfs-sysupgrade.itb"
        mv "$file" "$new_name"
        log "autobuild_release: $(basename "$file") -> $(basename "$new_name")"
    done

    find "$release_dir" -name "*bananapi_bpi-r4-initramfs-recovery*.itb" -print0 | while IFS= read -r -d '' file; do
        local new_name="$release_dir/openwrt-mediatek-filogic-bananapi_bpi-r4-initramfs-recovery.itb"
        mv "$file" "$new_name"
        log "autobuild_release: $(basename "$file") -> $(basename "$new_name")"
    done

    find "$release_dir" -name "*openwrt-mediatek-filogic-bananapi_bpi-r4-sdcard.img*.gz" -print0 | while IFS= read -r -d '' file; do
        local new_name="$release_dir/openwrt-mediatek-filogic-bananapi_bpi-r4-sdcard.img.gz"
        mv "$file" "$new_name"
        log "autobuild_release: $(basename "$file") -> $(basename "$new_name")"
    done
}

prompt_for_custom_build() {
    local custom_choice=""
    read -t 10 -p "Build Custom Image? (y/n) [10s]: " custom_choice || true
    if [[ "${custom_choice,,}" == "y"* ]]; then
        ./scripts/feeds update -a && ./scripts/feeds install -a
        make menuconfig
        rm -f bin/targets/mediatek/filogic/*
        make -j"$(nproc)"
    fi
}

main() {
    check_dependencies
    
    openwrt_commit=$( [ -n "$OPENWRT_COMMIT" ] && echo "$OPENWRT_COMMIT" || get_latest_commit_hash "$OPENWRT_REPO" "$OPENWRT_BRANCH" )
    setup_repo "$OPENWRT_REPO" "$OPENWRT_BRANCH" "$openwrt_commit" "$OPENWRT_DIR" "OpenWrt"
    mtk_feeds_commit=$( [ -n "$MTK_FEEDS_COMMIT" ] && echo "$MTK_FEEDS_COMMIT" || get_latest_commit_hash "$MTK_FEEDS_REPO" "$MTK_FEEDS_BRANCH" )
    setup_repo "$MTK_FEEDS_REPO" "$MTK_FEEDS_BRANCH" "$mtk_feeds_commit" "$MTK_FEEDS_DIR" "MTK Feeds"

    (
        cd "$OPENWRT_DIR"
        if ! grep -q "src-link mtk" feeds.conf.default; then
            echo "src-link mtk ../$MTK_FEEDS_DIR" >> feeds.conf.default
        fi
    )

    prepare_source_directory "$SOURCE_OPENWRT_PATCH_DIR"
    prepare_source_directory "$SOURCE_MTK_FEEDS_PATCH_DIR"
    prepare_source_directory "$SOURCE_CUSTOM_FILES_DIR"
    
    remove_files_from_list "$OPENWRT_REMOVE_LIST" "$OPENWRT_DIR"
    remove_files_from_list "$MTK_REMOVE_LIST" "$MTK_FEEDS_DIR"
    apply_files_from_list "$OPENWRT_ADD_LIST" "$SOURCE_OPENWRT_PATCH_DIR" "$OPENWRT_DIR"
    apply_files_from_list "$MTK_ADD_LIST" "$SOURCE_MTK_FEEDS_PATCH_DIR" "$MTK_FEEDS_DIR"
    
    copy_custom_files
    configure_build
    create_feed_revision

    log "--- Applying Patches to SDK Scripts (Syntax Safety) ---"
    if [ -f "$RULES_FILE" ]; then
        sed -i 's/ V=\${verbose}//' "$RULES_FILE"
    fi
    if [ -f "$AUTOBUILD_SCRIPT" ]; then
        sed -i 's/\${.*_rfb.*}_nic_set=yes/true/' "$AUTOBUILD_SCRIPT" || true
    fi

    # --- Refined Feed Management ---
    log "--- Updating and Installing Feeds ---"
    (
        cd "$OPENWRT_DIR"
		
		 log "Applying protocol fixes to feeds.conf.default..."
        sed -i 's|https://git.openwrt.org|git://git.openwrt.org|g' feeds.conf.default
        sed -i '/video/s|git://|https://|g' feeds.conf.default

        # 1. Update the feed indexes with a retry loop for network stability
        for i in {1..3}; do
            log "  - Feed update attempt $i..."
            ./scripts/feeds update -a && break || {
                log "  - Attempt $i failed. Retrying in 15s..."
                sleep 15
            }
        done

        ./scripts/feeds install -a
    )

    log "--- Cleaning Autobuild Cache ---"
    (
        cd "$OPENWRT_DIR"
        bash "../$MTK_FEEDS_DIR/autobuild/unified/autobuild.sh" "$BUILD_PROFILE" clean
    )

    log "--- Starting Full Autobuild (Prepare & Build) ---"
    (
        cd "$OPENWRT_DIR"
        bash "../$MTK_FEEDS_DIR/autobuild/unified/autobuild.sh" "$BUILD_PROFILE" filogic log_file=make
    )

    rename_release_images

    echo ""
    echo "=========================================================================="
    echo "   Build is complete! "
    echo "   Images are in: $OPENWRT_DIR/autobuild_release/"
    echo "=========================================================================="
    echo ""
    
    ( cd "$OPENWRT_DIR" && prompt_for_custom_build )
}

main "$@"
exit 0
