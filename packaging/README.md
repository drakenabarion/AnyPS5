# Packaging the Quake AppImage

These are the scripts that built `AnyPS5-0.2.0-x86_64.AppImage`.

- `anyps5-launch.sh`: the launcher (becomes `AppRun` inside the AppImage): finds or asks for the dump, converts it once per AnyPS5 version, remembers the game and the fullscreen choice, and starts it.
- `Containerfile`: Ubuntu 24.04 build image (GCC 13), so the result runs on glibc 2.38 and newer.
- `build.sh`: builds the relinker and system libraries in that container with Podman.
- `package.sh`: assembles the AppImage with appimagetool, including third-party licences.
- `VERSION`: release number used in the AppImage name.

The scripts expect this layout:

```
<any folder>/
  upstream/   this repository, checked out at quake-0.2
  releases/   a copy of this packaging folder
```

Then run `releases/build.sh` followed by `releases/package.sh`. The AppImage is written to `releases/out/`.
