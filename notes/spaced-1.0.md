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
   iOS, and in a minute or two after the download leaves `out/root.img`, `out/mapple-spaced-1.0-PERSONAL.zip` and
   the dual boot's two zips (below). Keep root.img and the PERSONAL zips to yourself: they hold iOS. The install guide on the website has the steps for each system.
3. `adb reboot bootloader`, then `fastboot flash userdata out/root.img` (Android's data is gone from here),
   then `fastboot reboot recovery`.
4. In the recovery: `adb sideload out/mapple-spaced-1.0-PERSONAL.zip` (or from an SD card or OTG; not from internal
   storage). If the recovery asks for your Android passcode you may cancel: the zip needs nothing from your data. It checks the root, copies the phone's own Wi-Fi, Bluetooth and touch firmware, saves the Android boot
   image and chains the loader into boot. Reboot when it says Done.

Until step 4 finishes the phone still boots Android, which then sets up its data anew. After it, the loader starts
iOS when the root checks out, and Android otherwise.

## Dual boot (SplitBoot)

SplitBoot keeps Android and puts iOS beside it, on a 22 GiB partition (xnusys) taken from the end of Android's data.
Android's system stays, but its data is erased: back up first, as in step 1.

1. In the recovery: `adb sideload out/mapple-spaced-1.0-split-PERSONAL.zip`. This first pass carves xnusys off
   userdata's end; Android still starts.
2. `adb reboot bootloader`, then `fastboot flash xnusys out/root.img` (the same root.img), then
   `fastboot reboot recovery`.
3. The same zip again: it checks the root, copies the phone's firmware, saves Android's boot image and puts the menu
   in front of it.

At every start a boot menu offers Android and iOS (volume keys to choose, Power to start); with no key pressed,
Android starts after 15 s. After an Android update, run the split zip once more to bring the menu back; iOS's data
stays. `out/mapple-spaced-1.0-uninstall.zip` gives the space back to Android and puts its boot and partition table
back as they were (both systems' data is erased). The full guide: https://open-mapple.pages.dev/splitboot/

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
- Wallpapers, partly: Colour and lighter wallpapers work. Heavy wallpapers, like photo wallpapers and most of the
  Collections set, may not work yet (release 2).
- Mapple, the settings app, with Sileo for packages

Release 1 loads one small library into fileproviderd so Files can use the phone's storage.

## Not yet

- Cellular, camera, CPU frequency scaling
- Charging control (the battery level is read), headset, Bluetooth audio, a Bluetooth headset's microphone
- Low Power Mode: this release has no bridge for it yet
- App Store: the front page loads, nothing installs
- The speaker plays well under Android's level; heavy wallpapers can run out of GPU memory; touch is slow on one core

## Back to Android

Flash the boot image you saved (`fastboot flash boot boot.img`), then Format Data in the recovery.

## Credits

Sileo 2.5.1 (BSD 4-Clause, Copyright (c) 2021, the Sileo Project), built with Open Mapple's fix for its root file
moves; this product includes software developed by the Sileo Team. The libraries built into it are under their own
licences (MIT, Apache 2.0, BSD 2-Clause), whose texts are in Sileo.app/Licenses.

Mapple's tweakloader.dylib: from HakiOS (github.com/oosexgang/hakios-xnu-kernel, userland/src/inject_tweaks.c),
with Open Mapple's changes. MIT:

Copyright (c) 2025-2026 the HakiOS authors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

mapplehelper: Zstandard's decompressor (github.com/facebook/zstd, v1.5.6, lib/common and lib/decompress, unmodified).
BSD licence:

BSD License

For Zstandard software

Copyright (c) Meta Platforms, Inc. and affiliates. All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

 * Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

 * Neither the name Facebook, nor Meta, nor the names of its contributors may
   be used to endorse or promote products derived from this software without
   specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## Licences

- mapple-install and the boot loaders (mtkloader.bin, mtkloader-split.bin) contain SplitBoot and the boot menu, so
  they are GPL-3.0-only as a whole. Source: [mapple_splitboot](https://github.com/open-mapple/mapple_splitboot),
  [mapple_build](https://github.com/open-mapple/mapple_build) and [mapple_loader](https://github.com/open-mapple/mapple_loader),
  at the commits listed in MANIFEST.
- Mapple and mapple-assemble: Copyright (c) 2026 Pritish Joshi (DrtSinX98), all rights reserved, free to use with
  Open Mapple. mapple-assemble only carries the GPL files above into the zips it makes; `mapple-assemble licenses`
  prints the licences of the libraries built into it.
- Turning on packages in Mapple downloads Procursus's bootstrap (suite 1900, `bootstrap-iphoneos-arm64.tar.zst`, SHA-256
  8354c3aa1ecdad8ebc47d9a76dfca6f830a2b757278068bd33b98bf1d638a9cb) from apt.procurs.us; it is not part of this
  release. Its GNU and Debian tools are GPL: apt 2.9.4, dpkg 1.22.6, debianutils 5.17, bash 5.2.21, coreutils 9.5,
  diffutils 3.10, findutils 4.9.0, grep 3.11, sed 4.9, tar 1.35 and gpgv 2.4.5; several of its libraries are LGPL.
  Their sources are those upstream releases with Procursus's makefiles and patches
  ([ProcursusTeam/Procursus](https://github.com/ProcursusTeam/Procursus)).
