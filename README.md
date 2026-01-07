# BPI-R4 Mediatek (OpenWrt 25.12/Kernel 6.12)

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

Please note - this build is for testing the Alpha Release which may contain bugs. If you want stability use Openwrt 24.10 instead.

## **Notes**

To adjust the tx power values you also need to add sku_idx '0' to your wireless config
```
config wifi-device 'radio0'

 * option sku_idx '0'
```
