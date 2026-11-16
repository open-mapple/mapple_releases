#!/bin/bash
# Open Mapple for the realme 8i (spaced), put together on your Mac from this release's files and iOS 16.7.16
# (20H392) for the iPhone X. Nothing of Apple's or the phone maker's is in the release: the iOS parts are made here,
# for you only, and the zip reads the phone's firmware on the phone.
#
#   ./release.sh [--ipsw IPSW] [--touch-fw FW]
#	Without --ipsw, iOS is downloaded from Apple's servers (6.2 GB, into work/): running this is your consent to
#	that download. --ipsw: your own copy of iPhone10,3,iPhone10,6_16.7.16_20H392_Restore.ipsw. Either way its
#	size and SHA-256 are checked.
#	--touch-fw (developers): FW_NF_ILI7807S_*.bin into the payload as well; normally the loader takes the copy
#	the zip puts in the tail area
#   The release's files go in assets/ first: gh release download <tag> -D assets (or by hand from the release page).
#   Needs python3, zip and GNU rsync (brew install rsync); building the root asks for sudo (it prints the command).
#   Out: out/root.img (fastboot) and out/mapple-...-PERSONAL.zip (recovery). Then, phone in Android or recovery:
#	adb reboot bootloader; fastboot flash userdata root.img; fastboot reboot recovery
#	in the recovery: adb sideload mapple-...-PERSONAL.zip (or from an SD card or OTG), then reboot
#   Flashing the root erases Android's data.
#
#   The release is checked against its signature: MANIFEST.sig by the key in allowed_signers (ssh-keygen -Y).
#
#   Maintainers:
#   ./release.sh pack OUT TOP TAG [--rehearsal]   assets/, assets/SHA256SUMS and MANIFEST for TAG (spaced-1.0) from an
#	mka build of mapple_spaced_single (OUT, its product directory) of the tree TOP, every project clean and at its
#	origin/main (--rehearsal: any commit, the tag marked as such)
#   ./release.sh sign KEY   MANIFEST.sig with the release key (ssh-keygen asks for its passphrase)
set -euo pipefail
cd "$(dirname "$0")"
H=$PWD A=$H/assets W=$H/work O=$H/out

field() { sed -n "s/^$1 //p" "$H/MANIFEST" | head -1; }
conf() { sed -n "s/^	\{0,1\}$1	//p" "$2" | head -1; }
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }

# every project an mka build of the single product reads (splitboot: its installer verbs go into mapple-install)
projects="build/mapple vendor/mapple device/realme/spaced mapple/loader mapple/splitboot mapple/userland mapple/gpu/mali
	kernel/mediatek/common kernel/mediatek/mt6781"

pack() {
	local out=$1 top=$2 tag=$3 rehearsal=${4:-} f r k d ipsw
	[ ! -d "$top/mapple/manager" ] || projects="$projects mapple/manager"	# the Mapple app, when the tree has it
	[ -z "$rehearsal" ] || tag=$tag-rehearsal
	for r in $projects; do
		[ -z "$(git -C "$top/$r" status --porcelain --untracked-files=no)" ] || { echo "pack: $r has changes" >&2; exit 1; }
		[ -n "$rehearsal" ] || [ "$(git -C "$top/$r" rev-parse HEAD)" = "$(git -C "$top/$r" rev-parse origin/main)" ] ||
			{ echo "pack: $r is not at its origin/main" >&2; exit 1; }
	done
	k=$(python3 - "$out/single/xnup.bin" <<'EOF'
import struct, sys
d, p = open(sys.argv[1], 'rb').read(), 8
while d[p:p + 16].strip(b'\0'):
    name, size = struct.unpack_from('<16sI', d, p)
    if name.rstrip(b'\0') == b'kernel.ver':
        print(d[p + 24:p + 24 + size].rstrip(b'\0').decode())
    p += 24 + (size + 15) // 16 * 16
EOF
)
	[ "$k" = "mapple-$(conf soc "$top/device/realme/spaced/device.conf")-g$(git -C "$top/kernel/mediatek/common" rev-parse --short=8 HEAD)" ] ||
		{ echo "pack: the kernel in $out ($k) is not common's HEAD: mka mapple again" >&2; exit 1; }
	rm -rf "$A"; mkdir -p "$A"
	# the archives name root:wheel as every file's owner, not this Mac's user (rootimage makes them root's anyway)
	# and carry no AppleDouble ._ entries (this Mac's xattrs: provenance, quarantine)
	own="--uid 0 --gid 0 --uname root --gname wheel --no-mac-metadata"
	cp "$out/kernel" "$out/shim.Image" "$out/single/mtkloader.bin" "$out/mapple-install" "$A/"
	tar -C "$out/root" $own -cf "$A/root-overlay.tar" .
	# Mapple's Home shows the release from /usr/share/mapple/release (one line: the version after the device name)
	f=$(mktemp -d)
	mkdir -p "$f/usr/share/mapple"
	echo "${tag#*-}" > "$f/usr/share/mapple/release"
	chmod 644 "$f/usr/share/mapple/release"
	tar -C "$f" $own -rf "$A/root-overlay.tar" ./usr/share/mapple/release
	rm -rf "$f"
	(cd "$top" && tar $own -cf "$A/tools.tar" build/mapple/LICENSE build/mapple/NOTICE \
		build/mapple/tools/{adt,extract-dt,mkadt,mkpayload,mkxnup,rootranges,root-tweaks}.py \
		build/mapple/tools/mkiosroot-macos.sh build/mapple/installer/update-binary \
		mapple/userland/tools/launchd-add.py mapple/loader/mtk/tools/mkilifw.py device/realme/spaced/device.conf)
	# For the cross-platform assembler: the ADT and the payload with /product's Apple properties left out (it puts
	# the IPSW's back in), and the pins of the IPSW members it reads
	ipsw=$top/out/ipsw/$(basename "$(conf ipsw_url "$top/vendor/mapple/config/common.conf")")
	[ -f "$ipsw" ] || { echo "pack: no $ipsw" >&2; exit 1; }
	d=$(mktemp -d)
	python3 "$top/build/mapple/tools/extract-dt.py" "$ipsw" "$d/d22ap.adt" >/dev/null
	# shellcheck disable=SC2046
	D22AP_ADT=$d/d22ap.adt python3 "$top/build/mapple/tools/mkadt.py" "$d/full.adt" $(conf adt "$top/device/realme/spaced/device.conf") >/dev/null
	python3 - "$top/build/mapple/tools" "$d/d22ap.adt" "$d/full.adt" "$A/adt.template" <<'EOF2'
import sys
sys.path.insert(0, sys.argv[1])
import adt
d22ap, _ = adt.parse(open(sys.argv[2], 'rb').read())
apple = {k: v for k, f, v in next(c for c in d22ap.children if c.name == 'product').props
         if not f and k not in ('name', 'AAPL,phandle')}
root, _ = adt.parse(open(sys.argv[3], 'rb').read())
product = next(c for c in root.children if c.name == 'product')
kept = [(k, f, v) for k, f, v in product.props if k in ('name', 'AAPL,phandle') or apple.get(k) != v]
assert all(k in apple for k, _, _ in kept if k not in ('name', 'AAPL,phandle')), 'a /product property not from the IPSW'
product.props = kept
open(sys.argv[4], 'wb').write(adt.serialize(root))
EOF2
	python3 "$top/build/mapple/tools/mkpayload.py" "$out/kernel" "$A/adt.template" "$A/xnu.template" \
		--cmdline "$(cat "$out/single/cmdline")" >/dev/null
	python3 - "$ipsw" > "$d/members" <<'EOF2'
import hashlib, plistlib, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
m = plistlib.loads(z.read('BuildManifest.plist'))['BuildIdentities'][0]['Manifest']
for role, name in (('os', m['OS']['Info']['Path']), ('systemos', m['Cryptex1,SystemOS']['Info']['Path']),
                   ('appos', m['Cryptex1,AppOS']['Info']['Path']), ('devicetree', 'Firmware/all_flash/DeviceTree.d22ap.im4p')):
    h, n = hashlib.sha256(), 0
    with z.open(name) as r:
        for b in iter(lambda: r.read(1 << 20), b''):
            h.update(b)
            n += len(b)
    print('ipsw_member', role, h.hexdigest(), n, name)
EOF2
	{
		echo "release $tag"
		echo "ipsw $(conf ipsw_size "$top/vendor/mapple/config/common.conf") $(conf ipsw_sha256 "$top/vendor/mapple/config/common.conf")"
		echo "ipsw_url $(conf ipsw_url "$top/vendor/mapple/config/common.conf")"
		echo "cmdline $(cat "$out/single/cmdline")"
		for f in adt payload_max root_size; do echo "$f $(conf $f "$top/device/realme/spaced/device.conf")"; done
		echo "kver $k"
		for r in $projects; do
			echo "source $r $(git -C "$top/$r" rev-parse HEAD)"
		done
		cat "$d/members"
		for f in kernel shim.Image mtkloader.bin mapple-install root-overlay.tar tools.tar adt.template xnu.template; do
			echo "file $(sha "$A/$f") $(stat -f %z "$A/$f") $f"
		done
	} > "$H/MANIFEST"
	rm -rf "$d"
	sed -n 's/^file \([0-9a-f]*\) [0-9]* \(.*\)/\1  \2/p' "$H/MANIFEST" > "$A/SHA256SUMS"
	rm -f "$H/MANIFEST.sig"
	cat "$H/MANIFEST"
	echo "Next: ./release.sh sign <the release key>; commit MANIFEST, MANIFEST.sig and notes/$tag.md; tag $tag;"
	echo "gh release create $tag assets/* MANIFEST MANIFEST.sig --notes-file notes/$tag.md"
}

sign() {
	[ -f "$H/MANIFEST" ] || { echo "sign: no MANIFEST: pack first" >&2; exit 1; }
	ssh-keygen -Y sign -f "$1" -n mapple-release "$H/MANIFEST"
	echo "open-mapple-release namespaces=\"mapple-release\" $(cut -d' ' -f1,2 "$1.pub")" > "$H/allowed_signers.new"
	if cmp -s "$H/allowed_signers.new" "$H/allowed_signers"; then rm "$H/allowed_signers.new"
	else echo "allowed_signers.new: the key's line; commit it as allowed_signers if this is the release key"; fi
}

usage() { sed -n '2,28p' "$0"; exit 2; }
case ${1:-} in
pack) [ $# = 4 ] || { [ $# = 5 ] && [ "$5" = --rehearsal ]; } || usage; pack "$2" "$3" "$4" "${5:-}"; exit ;;
sign) [ $# = 2 ] || usage; sign "$2"; exit ;;
esac
ipsw= fw=
while [ $# -gt 0 ]; do
	case $1 in
	--ipsw) [ $# -ge 2 ] || usage; ipsw=$(cd "$(dirname "$2")" && pwd)/$(basename "$2"); shift 2 ;;
	--touch-fw) [ $# -ge 2 ] || usage; fw=$2; shift 2 ;;
	*) usage ;;
	esac
done
[ -f "$H/MANIFEST" ] || { echo "no MANIFEST: this is not a release's checkout" >&2; exit 1; }

[ -f "$H/MANIFEST.sig" ] && [ -f "$H/allowed_signers" ] || { echo "no MANIFEST.sig or allowed_signers: not a signed release" >&2; exit 1; }
ssh-keygen -Y verify -f "$H/allowed_signers" -I open-mapple-release -n mapple-release -s "$H/MANIFEST.sig" \
	< "$H/MANIFEST" >/dev/null || { echo "MANIFEST's signature does not check out" >&2; exit 1; }
echo "checking assets/ against MANIFEST"
sed -n 's/^file //p' "$H/MANIFEST" | while read -r sum size f; do
	[ -f "$A/$f" ] && [ "$(stat -f %z "$A/$f")" = "$size" ] && [ "$(sha "$A/$f")" = "$sum" ] ||
		{ echo "assets/$f is missing or not this release's" >&2; exit 1; }
done
read -r size sum <<< "$(field ipsw)"
if [ -z "$ipsw" ]; then
	url=$(field ipsw_url) ipsw=$W/$(basename "$(field ipsw_url)")
	if [ ! -f "$ipsw" ]; then
		echo "Downloading iOS 16.7.16 (20H392) for the iPhone X from Apple's servers; running this is your consent."
		mkdir -p "$W"
		curl -fL -C - -o "$ipsw.part" "$url"
		mv "$ipsw.part" "$ipsw"
	fi
fi
[ -f "$ipsw" ] || { echo "no $ipsw" >&2; exit 1; }
stamp=$W/ipsw.ok
if [ "$(cat "$stamp" 2>/dev/null)" != "$(stat -f '%z %m' "$ipsw") $ipsw" ]; then
	echo "checking $ipsw"
	[ "$(stat -f %z "$ipsw")" = "$size" ] && [ "$(sha "$ipsw")" = "$sum" ] ||
		{ echo "$ipsw is not iOS 16.7.16 (20H392) for the iPhone X" >&2; exit 1; }
	mkdir -p "$W"; echo "$(stat -f '%z %m' "$ipsw") $ipsw" > "$stamp"
fi
[ -z "$fw" ] || [ -f "$fw" ] || { echo "no $fw" >&2; exit 1; }

T=$W/tree BM=$W/tree/build/mapple
rm -rf "$T" "$W/root"; mkdir -p "$T" "$W/root" "$O"
tar -C "$T" -xf "$A/tools.tar"
tar -C "$W/root" -xpf "$A/root-overlay.tar"
# unpacked by you, root's set-user-ID files lose the bit (Mapple's helper): put it back from the archive's listing
tar -tvf "$A/root-overlay.tar" | awk '$1 ~ /^-..[sS]/ {print $NF}' | while read -r f; do chmod u+s "$W/root/$f"; done
tar -tvf "$A/root-overlay.tar" | awk '$1 ~ /^-.....[sS]/ {print $NF}' | while read -r f; do chmod g+s "$W/root/$f"; done

echo "device tree and payload"
python3 "$BM/tools/extract-dt.py" "$ipsw" "$W/d22ap.adt" >/dev/null
# shellcheck disable=SC2046
D22AP_ADT=$W/d22ap.adt python3 "$BM/tools/mkadt.py" "$W/spaced.adt" $(field adt) >/dev/null
python3 "$BM/tools/mkpayload.py" "$A/kernel" "$W/spaced.adt" "$W/xnu.bin" --cmdline "$(field cmdline)" >/dev/null
[ "$(stat -f %z "$W/xnu.bin")" -lt $(($(field payload_max))) ] || { echo "the payload is too big" >&2; exit 1; }
set -- shim="$A/shim.Image"
if [ -n "$fw" ]; then
	python3 "$T/mapple/loader/mtk/tools/mkilifw.py" "$fw" "$W/ilifw.bin" >/dev/null
	set -- "$@" ilifw="$W/ilifw.bin"
fi
python3 "$BM/tools/mkxnup.py" -o "$W/xnup.bin" --kernel-version "$(field kver)" "$@" xnu="$W/xnu.bin" >/dev/null

# system.img is made once per IPSW and overlay; system.ok remembers which
img=$W/system.img want="$(field ipsw) $(sha "$A/root-overlay.tar")"
if [ ! -f "$img" ] || [ "$(cat "$W/system.ok" 2>/dev/null)" != "$want" ]; then
	echo "The root image needs sudo (owners kept, the image mounted). Run, then ./release.sh again:"
	echo "  rm -f $img; sudo $BM/tools/mkiosroot-macos.sh $ipsw $img $(field root_size) spaced $W/root && echo '$want' > $W/system.ok"
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
echo "Done: $O/root.img and $zip. Keep them to yourself: they carry Apple's files (and with TOUCH_FW, the phone maker's)."
