#!/bin/bash
# Open Mapple for the realme 8i (spaced), put together on your Mac from this release's files, your own copy of
# iOS 16.7.16 (20H392) for the iPhone X, and your phone's touch firmware. Nothing of Apple's or the phone maker's is
# in the release: those parts are made here, for you only.
#
#   ./release.sh IPSW TOUCH_FW
#	IPSW      iPhone10,3,iPhone10,6_16.7.16_20H392_Restore.ipsw (its size and SHA-256 are checked)
#	TOUCH_FW  FW_NF_ILI7807S_*.bin from your phone (pull-firmware.sh in the release's tools gets it; needs root)
#   The release's files go in assets/ first: gh release download <tag> -D assets (or by hand from the release page).
#   Needs python3, zip and GNU rsync (brew install rsync); building the root asks for sudo (it prints the command).
#   Out: out/root.img (fastboot) and out/mapple-...-PERSONAL.zip (recovery). Then, phone in Android or recovery:
#	adb reboot bootloader; fastboot flash userdata root.img; fastboot reboot recovery
#	in the recovery: adb sideload mapple-...-PERSONAL.zip (or from an SD card or OTG), then reboot
#   Flashing the root erases Android's data.
#
#   ./release.sh pack OUT TOP TAG   (maintainers) assets/ and MANIFEST for TAG (spaced-1.0) from mka's product
#	directory OUT and the tree TOP
set -euo pipefail
cd "$(dirname "$0")"
H=$PWD A=$H/assets W=$H/work O=$H/out

field() { sed -n "s/^$1 //p" "$H/MANIFEST" | head -1; }
conf() { sed -n "s/^	\{0,1\}$1	//p" "$2" | head -1; }
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }

pack() {
	local out=$1 top=$2 tag=$3 f
	rm -rf "$A"; mkdir -p "$A"
	cp "$out/kernel" "$out/shim.Image" "$out/mtkloader.bin" "$out/mapple-install" "$A/"
	tar -C "$out/root" -cf "$A/root-overlay.tar" .
	(cd "$top" && tar -cf "$A/tools.tar" build/mapple/LICENSE build/mapple/NOTICE \
		build/mapple/tools/{adt,extract-dt,mkadt,mkpayload,mkxnup,rootranges,root-tweaks}.py \
		build/mapple/tools/mkiosroot-macos.sh build/mapple/installer/update-binary \
		mapple/userland/tools/launchd-add.py mapple/loader/mtk/tools/mkilifw.py \
		vendor/mapple/config/common.conf device/realme/spaced/device.conf device/realme/spaced/pull-firmware.sh)
	{
		echo "release $tag"
		echo "ipsw $(conf ipsw_size "$top/vendor/mapple/config/common.conf") $(conf ipsw_sha256 "$top/vendor/mapple/config/common.conf")"
		python3 - "$out/xnup.bin" <<'EOF'
import struct, sys
d, p = open(sys.argv[1], 'rb').read(), 8
while d[p:p + 16].strip(b'\0'):
    name, size = struct.unpack_from('<16sI', d, p)
    if name.rstrip(b'\0') == b'kernel.ver':
        print('kver', d[p + 24:p + 24 + size].rstrip(b'\0').decode())
    p += 24 + (size + 15) // 16 * 16
EOF
		for r in build/mapple vendor/mapple device/realme/spaced mapple/loader mapple/userland mapple/gpu/mali \
			kernel/mediatek/common kernel/mediatek/mt6781; do
			echo "source $r $(git -C "$top/$r" rev-parse HEAD)"
		done
		for f in kernel shim.Image mtkloader.bin mapple-install root-overlay.tar tools.tar; do
			echo "file $(sha "$A/$f") $(stat -f %z "$A/$f") $f"
		done
	} > "$H/MANIFEST"
	cat "$H/MANIFEST"
}

[ "${1:-}" != pack ] || { [ $# = 4 ] || { sed -n '2,20p' "$0"; exit 2; }; pack "$2" "$3" "$4"; exit; }
[ $# = 2 ] || { sed -n '2,20p' "$0"; exit 2; }
ipsw=$(cd "$(dirname "$1")" && pwd)/$(basename "$1") fw=$2
[ -f "$H/MANIFEST" ] || { echo "no MANIFEST: this is not a release's checkout" >&2; exit 1; }

echo "checking assets/ against MANIFEST"
sed -n 's/^file //p' "$H/MANIFEST" | while read -r sum size f; do
	[ -f "$A/$f" ] && [ "$(stat -f %z "$A/$f")" = "$size" ] && [ "$(sha "$A/$f")" = "$sum" ] ||
		{ echo "assets/$f is missing or not this release's" >&2; exit 1; }
done
read -r size sum <<< "$(field ipsw)"
stamp=$W/ipsw.ok
if [ "$(cat "$stamp" 2>/dev/null)" != "$(stat -f '%z %m' "$ipsw") $ipsw" ]; then
	echo "checking $ipsw"
	[ "$(stat -f %z "$ipsw")" = "$size" ] && [ "$(sha "$ipsw")" = "$sum" ] ||
		{ echo "$ipsw is not iOS 16.7.16 (20H392) for the iPhone X" >&2; exit 1; }
	mkdir -p "$W"; echo "$(stat -f '%z %m' "$ipsw") $ipsw" > "$stamp"
fi
[ -f "$fw" ] || { echo "no $fw" >&2; exit 1; }

T=$W/tree BM=$W/tree/build/mapple DC=$W/tree/device/realme/spaced/device.conf
rm -rf "$T" "$W/root"; mkdir -p "$T" "$W/root" "$O"
tar -C "$T" -xf "$A/tools.tar"
tar -C "$W/root" -xf "$A/root-overlay.tar"

echo "device tree and payload"
python3 "$BM/tools/extract-dt.py" "$ipsw" "$W/d22ap.adt" >/dev/null
# shellcheck disable=SC2046
D22AP_ADT=$W/d22ap.adt python3 "$BM/tools/mkadt.py" "$W/spaced.adt" $(conf adt "$DC") >/dev/null
cmdline="$(conf cmdline "$T/vendor/mapple/config/common.conf") $(conf cmdline "$DC")"
python3 "$BM/tools/mkpayload.py" "$A/kernel" "$W/spaced.adt" "$W/xnu.bin" --cmdline "$cmdline" >/dev/null
[ "$(stat -f %z "$W/xnu.bin")" -lt $(($(conf payload_max "$DC"))) ] || { echo "the payload is too big" >&2; exit 1; }
python3 "$T/mapple/loader/mtk/tools/mkilifw.py" "$fw" "$W/ilifw.bin" >/dev/null
python3 "$BM/tools/mkxnup.py" -o "$W/xnup.bin" --kernel-version "$(field kver)" \
	shim="$A/shim.Image" ilifw="$W/ilifw.bin" xnu="$W/xnu.bin" >/dev/null

# system.img is made once per IPSW and overlay; system.ok remembers which
img=$W/system.img want="$(field ipsw) $(sha "$A/root-overlay.tar")"
if [ ! -f "$img" ] || [ "$(cat "$W/system.ok" 2>/dev/null)" != "$want" ]; then
	echo "The root image needs sudo (owners kept, the image mounted). Run, then ./release.sh again:"
	echo "  rm -f $img; sudo $BM/tools/mkiosroot-macos.sh $ipsw $img $(conf root_size "$DC") spaced $W/root && echo '$want' > $W/system.ok"
	exit 2
fi
echo "root.img (a few minutes)"
python3 "$BM/tools/rootranges.py" "$img" "$O/root.img" "$W/root.ranges"

Z=$W/zip
rm -rf "$Z"; mkdir -p "$Z/META-INF/com/google/android"
cp "$BM/installer/update-binary" "$Z/META-INF/com/google/android/"
echo "#dummy" > "$Z/META-INF/com/google/android/updater-script"
cp "$A/mapple-install" "$A/mtkloader.bin" "$W/xnup.bin" "$W/root.ranges" "$Z/"
(cd "$Z" && shasum -a 256 mapple-install mtkloader.bin xnup.bin root.ranges > SHA256SUMS)
zip=$O/mapple-$(sed -n 's/^release //p' "$H/MANIFEST")-PERSONAL.zip
rm -f "$zip"
(cd "$Z" && zip -q -X -r "$zip" META-INF mapple-install mtkloader.bin xnup.bin root.ranges SHA256SUMS)
rm -rf "$W/tree" "$W/root" "$Z"
echo "Done: $O/root.img and $zip. Keep them to yourself: they carry Apple's and the phone maker's files."
