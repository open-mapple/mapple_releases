# mapple_releases

Open Mapple's releases, one branch per device (`spaced`: the realme 8i). A branch holds the release script, the
notes of each release, and the signed MANIFEST of the latest one; the files themselves are on the release page.

To install a release, follow the install guide on the website: download the release's files, run `mapple-assemble`
for your computer (Windows, Linux, Termux, macOS), then flash its `root.img` and the recovery zip.

Every release is signed: `ssh-keygen -Y verify -f allowed_signers -I open-mapple-release -n mapple-release
-s MANIFEST.sig < MANIFEST`, and MANIFEST lists every file's SHA-256.

Maintainers: `./release.sh pack OUT TOP TAG` from an `mka` build, then `./release.sh sign KEY` (`./release.sh` with no
arguments is the Mac-only way to assemble a release).
