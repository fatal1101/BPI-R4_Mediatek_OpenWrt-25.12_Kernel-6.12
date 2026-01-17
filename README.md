# $$\color{blue}\Huge{\textbf{BPI-R4\ Mediatek\ (OpenWrt\ 25.12/Kernel\ 6.12)}}$$

Script to Build (Openwrt 25.12/kernel 6.12) with the mtk-openwrt-feeds...

## **To build with the Mediatek (OpenWrt 25.12/Kernel 6.12)**

1. If you want to build with the latest openwrt-25.12/kernels 6.12 and the latest mtk commits leave both OPENWRT_COMMIT="" & MTK_FEEDS_COMMIT="" empty.

2. If you want to target a specific commit use the full commit hash e.g... OPENWRT_COMMIT="2acfd9f8ab12e4f353a0aa644d9adf89588b1f0f"

3. Error Checks - All scripts and patches will be auto chacked with dos2unix and corrected if needed if they are not in the correct EOL format.

## Compile Environment Requirement

- Minimum requirement: Ubuntu 22.04

##### Toolchain

- Installs essential development tools and libraries, including compilers, build tools. Please refer to https://openwrt.org/docs/guide-developer/toolchain/install-buildsystem for more detail
```
sudo apt update
sudo apt install build-essential clang flex bison g++ gawk \
gcc-multilib g++-multilib gettext git libncurses-dev libssl-dev \
python3-distutils python3-setuptools rsync swig unzip zlib1g-dev file wget \
u-boot-tools dos2unix
```
## **How to Use**

1. **Clone repo**:
   * Clone repo:   
     `git clone https://github.com/Gilly1970/BPI-R4_Mediatek_OpenWrt-25.12_Kernel-6.12.git`
     
   * Update permissions:   
     `sudo chmod 775 -R BPI-R4_Mediatek_OpenWrt-25.12_Kernel-6.12`

2. **Run the Script**:  
   * Make the script executable:  
     `chmod +x mtk-openwrt_25.12_build.sh`
     
   * Execute the script:  
     `./mtk-openwrt_25.12_build.sh`

## **Filogic 880/850 WiFi7 4.3 Alpha Release (2025-12-31)**
> [!WARNING]
> This build is for testing the Alpha Release which may contain bugs so if you want stability please use Openwrt 24.10 instead.
>
## **Troubleshooting Build Errors**

If you encounter errors during compilation, they are often caused by recent patches released by MediaTek (this is less common with OpenWrt patches).

To resolve this, you have two options:

**1. Pin a specific commit:** Identify the last working commit before the update that broke the build. Change the MTK_FEEDS_COMMIT variable to that specific hash.

- **Change:** `readonly MTK_FEEDS_COMMIT=""`

- **To:** `readonly MTK_FEEDS_COMMIT="5dcc2867b180400f93664d6ed343d32b1ce06428"`

**2. Wait for a fix:** Wait for MediaTek to release a subsequent patch that resolves the issue.

To check MediaTek patches releases - https://git01.mediatek.com/plugins/gitiles/openwrt/feeds/mtk-openwrt-feeds/+log

## **Notes**
> [!NOTE]
> Currently no bananapi_bpi-r4-sdcard.img.gz is created with this build. MediaTek's new boot flow (using FIP/U-Boot 2024.x) which relies heavily on the FIT images (.itb) for both recovery and system upgrade, effectively deprecating the old "raw SD card image" method for this specific branch. If you haven't updated to MediaTek's u-boot then you will need to force update using "openwrt-mediatek-filogic-bananapi_bpi-r4-squashfs-sysupgrade.itb" to upgrade.
<img width="597" height="540" alt="force update" src="https://github.com/user-attachments/assets/2af6f8fa-2f30-4421-be0e-2415ea2268c2" />

> [!NOTE]
>Temp removing '999-ppe-29-netfilter-add-xfrm-offload.patch' and 3 other related patches to fix compile error 'struct dst_entry has no member named xfrm'. This patch tries to add code that accesses dst->xfrm. Since OpenWrt 25.12 (Kernel 6.12) has removed or currently refactored that member from the kernel structure, applying this patch breaks the networking stack compilation.

> [!NOTE]
>To adjust the tx power values you also need to add sku_idx '0' to your wireless config
```
config wifi-device 'radio0'

 * option sku_idx '0'
```
