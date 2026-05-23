# Flatpak Packaging for Flutter Apps

Instructions for adding Flatpak support to a Flutter Linux desktop project.

## Prerequisites

- Flutter Linux desktop already enabled (`flutter config --enable-linux-desktop`)
- Linux release built at least once (`flutter build linux --release`)

## Setup

### 1. Pick a reverse-domain app ID

Examples: `com.andersklint.hankan_chinese_reader`, `org.example.myapp`

### 2. Update Linux app ID

In `linux/CMakeLists.txt`, change:

```cmake
set(APPLICATION_ID "com.example.myapp")  →  set(APPLICATION_ID "com.yourid.myapp")
```

### 3. Create flatpak/ directory

```
flatpak/
├── com.yourid.myapp.yml
├── com.yourid.myapp.desktop
├── com.yourid.myapp.png
└── com.yourid.myapp.metainfo.xml
```

### 4. Create flatpak manifest

`flatpak/com.yourid.myapp.yml`:

```yaml
app-id: com.yourid.myapp
runtime: org.freedesktop.Platform
runtime-version: '24.08'
sdk: org.freedesktop.Sdk
command: myapp
appstream-compose: false

finish-args:
  - --share=ipc
  - --share=network
  - --socket=fallback-x11
  - --socket=wayland
  - --device=dri
  - --filesystem=host:rw
  - --socket=session-bus

modules:
  - name: myapp
    buildsystem: simple
    build-commands:
      - mkdir -p /app /app/bin
      - cp -r build/linux/x64/release/bundle/* /app/
      - chmod +x /app/{{binary_name}}
      - printf '#!/bin/sh\nexec /app/{{binary_name}} "$@"' > /app/bin/{{binary_name}}
      - chmod +x /app/bin/{{binary_name}}
      - install -Dm644 flatpak/com.yourid.myapp.desktop
        /app/share/applications/com.yourid.myapp.desktop
      - install -Dm644 flatpak/com.yourid.myapp.png
        /app/share/icons/hicolor/256x256/apps/com.yourid.myapp.png
      - install -Dm644 flatpak/com.yourid.myapp.metainfo.xml
        /app/share/metainfo/com.yourid.myapp.metainfo.xml
      - install -Dm644 LICENSE
        /app/share/licenses/com.yourid.myapp/LICENSE
    sources:
      - type: dir
        path: ..
```

Replace `{{binary_name}}` with the actual binary name (defined in `linux/CMakeLists.txt` as `BINARY_NAME`).

### 5. Create desktop entry

`flatpak/com.yourid.myapp.desktop`:

```ini
[Desktop Entry]
Name=My App
Comment=Description of my app
Exec=myapp
Type=Application
Categories=Utility;
Icon=com.yourid.myapp
Terminal=false
StartupNotify=true
```

### 6. Add icon

Copy a 256x256 PNG icon to `flatpak/com.yourid.myapp.png`.

### 7. Create AppStream metadata

`flatpak/com.yourid.myapp.metainfo.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop">
  <id>com.yourid.myapp</id>
  <name>My App</name>
  <summary>App description</summary>
  <project_license>MIT</project_license>
  <description>
    <p>Longer description.</p>
  </description>
  <url type="homepage">https://github.com/you/myapp</url>
  <categories>
    <category>Utility</category>
    <category>Education</category>
  </categories>
  <releases>
    <release version="1.0.0" date="2025-01-01"/>
  </releases>
</component>
```

### 8. Add to .gitignore

```
/.flatpak-builder/
/build-dir/
/repo/
*.flatpak
```

## Build

```bash
flutter build linux --release
flatpak-builder --repo=repo build-dir flatpak/com.yourid.myapp.yml --force-clean
flatpak build-bundle repo myapp.flatpak com.yourid.myapp
flatpak install myapp.flatpak
```

## Makefile (optional)

```makefile
APP_ID := com.yourid.myapp
MANIFEST := flatpak/$(APP_ID).yml
BUNDLE := myapp.flatpak

.PHONY: flatpak clean

flatpak:
	flutter build linux --release
	flatpak-builder --repo=repo build-dir $(MANIFEST) --force-clean
	flatpak build-bundle repo $(BUNDLE) $(APP_ID)
	flatpak install $(BUNDLE)

clean:
	rm -rf build-dir repo .flatpak-builder $(BUNDLE)
```

## Key details

- Binary goes in `/app/` (not `/app/bin/`) so `$ORIGIN/lib` resolves correctly for bundled native libs
- A wrapper script in `/app/bin/` points Flatpak's `command` to the real binary
- `appstream-compose: false` skips AppStream validation (only needed for Flathub)
- Adjust `finish-args` based on your app's needs (network, filesystem, audio, etc.)
