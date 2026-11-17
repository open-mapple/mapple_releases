# Open Mapple 1.0 for the realme 8i (spaced)

XNU with iOS 16.7.16 (20H392) user space on the realme 8i, as its only system. Installing it **erases Android
and everything on the phone**.

## What you need

- A realme 8i (RMX3151), bootloader unlocked, a recovery that runs zips (TWRP or OrangeFox), adb and fastboot.
- A computer with Windows (x64, or ARM through its emulation), Linux (x64 or arm64), macOS, or a 64-bit Android
  phone with Termux (not the realme): about 21 GB free (15 GB with your own copy of iOS), under 2 GB of memory.
- iOS 16.7.16 (20H392) for the iPhone X: mapple-assemble downloads the parts it needs from Apple's servers (running
  it is your consent), or reads your own copy with `-ipsw`. Nothing of Apple's is in this release; the iOS parts are
  put together on your computer.

## Install

1. Back up your data from Android before installing (photos, files, app data, as you usually keep them): the
   install erases it. A copy of the userdata partition (an mtkclient dump, for instance) is not a backup of your
   data: it is encrypted with the phone's own keys. Then, from the recovery, keep the boot, nvram, nvdata, nvcfg,
   persist, protect1 and protect2 partitions (`adb exec-out dd if=/dev/block/by-name/<name> bs=4M > <name>.img`).
2. Download the release's files into one folder (`gh release download spaced-1.0 -D mapple`, or by hand: MANIFEST,
   MANIFEST.sig, allowed_signers, every file MANIFEST lists but the other systems' mapple-assemble). In that folder run
   `mapple-assemble-windows-amd64.exe`, `./mapple-assemble-linux-amd64` (arm64 and Termux: `-linux-arm64`) or
   `./mapple-assemble-macos`, with `-ipsw <your copy>` to use your own IPSW. It checks the files' signature and
   iOS, and in a minute or two after the download leaves `out/root.img` and `out/mapple-spaced-1.0-PERSONAL.zip`.
   Keep both to yourself: they hold iOS. The install guide on the website has the steps for each system.
3. `adb reboot bootloader`, then `fastboot flash userdata out/root.img` (Android's data is gone from here),
   then `fastboot reboot recovery`.
4. In the recovery: `adb sideload out/mapple-spaced-1.0-PERSONAL.zip` (or from an SD card or OTG; not from internal
   storage). If the recovery asks for your Android passcode you may cancel: the zip needs nothing from your data. It checks the root, copies the phone's own Wi-Fi, Bluetooth and touch firmware, saves the Android boot
   image and chains the loader into boot. Reboot when it says Done.

Until step 4 finishes the phone still boots Android, which then sets up its data anew. After it, the loader starts
iOS when the root checks out, and Android otherwise.

## Works

- Display (the framebuffer LK leaves, 1080x2412), drawn through Metal on the Mali-G57 GPU
- Touch (up to three fingers), power and volume buttons
- Wi-Fi (scan, WPA2 join, Safari, downloads)
- Bluetooth (pairing, LE scan, a keyboard)
- Speaker and main microphone, vibration, the torch (lock screen and Control Center)
- Earpiece (the speakerphone button does not move the sound to the speaker yet)
- Sensors, partly: rotation works; the other sensors are release 2
- Storage: iOS on the phone's UFS, read-write
- Photos: the grid and thumbnails
- Files: "On My iPhone"
- Video (converted on the CPU for now)
- Wallpapers, partly: Colour and one of the Collections
- Mapple, the settings app, with Sileo for packages

Release 1 loads one small library into fileproviderd so Files can use the phone's storage.

## Not yet

- Cellular, camera, CPU frequency scaling
- Charging control (the battery level is read), headset, Bluetooth audio, a Bluetooth headset's microphone
- Low Power Mode: this release has no bridge for it yet
- The photo wallpaper and the rest of the Collections wallpapers (release 2)
- App Store: the front page loads, nothing installs
- The speaker plays well under Android's level; heavy wallpapers can run out of GPU memory; touch is slow on one core

## Back to Android

Flash the boot image you saved (`fastboot flash boot boot.img`), then Format Data in the recovery.

## Credits

Sileo 2.5.1 (BSD 4-Clause, Copyright (c) 2021, the Sileo Project), built with Open Mapple's fix for its root file
moves; this product includes software developed by the Sileo Team. The libraries built into it are under their own
licences (MIT, Apache 2.0, BSD 2-Clause), whose texts are in Sileo.app/Licenses.
