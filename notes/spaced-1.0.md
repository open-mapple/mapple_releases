# Open Mapple 1.0 for the realme 8i (spaced)

XNU with iOS 16.7.16 (20H392) user space on the realme 8i, as its only system. Installing it **erases Android
and everything on the phone**.

## What you need

- A realme 8i (RMX3151), bootloader unlocked, a recovery that runs zips (TWRP or OrangeFox), adb and fastboot.
- A Mac with python3, zip and GNU rsync (`brew install rsync`), about 30 GB free, and an admin password (the root
  image is built with sudo).
- iOS 16.7.16 (20H392) for the iPhone X: release.sh downloads it from Apple's servers (running it is your consent),
  or takes your own copy with `--ipsw`. Nothing of Apple's is in this release; the iOS parts are made on your Mac.

## Install

1. Back up the phone: whatever you keep from /sdcard, and from the recovery the boot, nvram, nvdata, nvcfg,
   persist, protect1 and protect2 partitions (`adb exec-out dd if=/dev/block/by-name/<name> bs=4M > <name>.img`).
2. On the Mac, in a checkout of this repository's spaced branch: download the release's files into `assets/`
   (`gh release download spaced-1.0 -D assets`), then run `./release.sh` (or `./release.sh --ipsw <your copy>`).
   It checks the files' signature and the IPSW, asks you to run one sudo command for the root image, and leaves
   `out/root.img` and `out/mapple-spaced-1.0-PERSONAL.zip`. Keep both to yourself: they hold iOS.
3. `adb reboot bootloader`, then `fastboot flash userdata out/root.img` (Android's data is gone from here),
   then `fastboot reboot recovery`.
4. In the recovery: `adb sideload out/mapple-spaced-1.0-PERSONAL.zip` (or from an SD card or OTG; not from internal
   storage). It checks the root, copies the phone's own Wi-Fi, Bluetooth and touch firmware, saves the Android boot
   image and chains the loader into boot. Reboot when it says Done.

Until step 4 finishes the phone still boots Android, which then sets up its data anew. After it, the loader starts
iOS when the root checks out, and Android otherwise.

## Works

- Display (the framebuffer LK leaves, 1080x2412), drawn through Metal on the Mali-G57 GPU
- Touch (up to three fingers), power and volume buttons
- Wi-Fi (scan, WPA2 join, Safari, downloads)
- Bluetooth (pairing, LE scan, a keyboard)
- Speaker and main microphone, vibration, the torch (lock screen and Control Center)
- Storage: iOS on the phone's UFS, read-write

## Not yet

- Cellular, camera, sensors, CPU frequency scaling
- Charging control (the battery level is read), earpiece and headset, Bluetooth audio
- The speaker plays well under Android's level; heavy wallpapers can run out of GPU memory; touch is slow on one core

## Back to Android

Flash the boot image you saved (`fastboot flash boot boot.img`), then Format Data in the recovery.
