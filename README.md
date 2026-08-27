# Jellyfinity

**The Open Source Jellyfin Client that makes your Media Server feel not-self hosted.**

Jellyfinity is a free and open-source Flutter client for Jellyfin, built primarily for Android and iOS.

> Jellyfinity is currently in early development. The development environment and project foundation are being established before application development begins.

## Development Setup

Jellyfinity uses a repository-owned **VS Code Dev Container** to provide a reproducible development environment.

The container includes the Flutter SDK, Dart, Android build toolchain, JDK, Node.js, Claude Code, and Codex CLI. You do not need to install these individually on your development machine.

### Prerequisites

The currently supported development workflow uses:

* Windows 11
* WSL2
* Docker Desktop with WSL2 integration
* VS Code
* VS Code Dev Containers extension
* Android Studio for the Android emulator and host-side Android tooling

Other host environments may work, but the Windows + WSL2 workflow is the currently established development setup.

### 1. Prepare WSL2

Install an Ubuntu 24.04 WSL2 distribution if you do not already have a suitable development distribution.

For example:

```powershell
wsl --install Ubuntu-24.04
```

Verify it with:

```powershell
wsl -l -v
```

The distribution should be running as WSL version 2.

For developers who maintain separate work and personal environments, using a dedicated personal-development WSL distribution is recommended.

For example:

```powershell
wsl --install Ubuntu-24.04 --name PersonalDev --location C:\WSL\PersonalDev
```

### 2. Enable Docker Desktop WSL Integration

Open:

**Docker Desktop → Settings → Resources → WSL Integration**

Enable integration for the WSL distribution you intend to use for Jellyfinity.

Do not install a second Docker Engine inside that WSL distribution.

Verify Docker from WSL:

```bash
docker --version
docker compose version
docker run --rm hello-world
```

### 3. Clone Jellyfinity

Keep the repository in the native WSL filesystem rather than under `/mnt/c`.

For example:

```bash
mkdir -p ~/projects
cd ~/projects

git clone git@github.com:BenGroll/Jellyfinity.git
cd Jellyfinity
```

If you use a custom SSH host alias, use the corresponding clone URL instead.

The resulting repository should live somewhere similar to:

```text
/home/<user>/projects/Jellyfinity
```

### 4. Open the Repository in VS Code

From the WSL terminal:

```bash
cd ~/projects/Jellyfinity
code .
```

VS Code should initially indicate that the repository is open through WSL.

Install the **Dev Containers** extension if VS Code does not already have it.

Open the Command Palette with:

```text
Ctrl+Shift+P
```

and select:

```text
Dev Containers: Reopen in Container
```

VS Code will build the Jellyfinity development container.

The first build can take several minutes because the Flutter SDK, Android toolchain, JDK, Node.js, and other development tools need to be downloaded.

### 5. Verify the Development Container

Open a VS Code terminal after the container starts.

It should resemble:

```text
vscode ➜ /workspace (main) $
```

Verify the toolchain:

```bash
flutter --version
dart --version
java -version
node --version
adb version
claude --version
codex --version
```

Then run:

```bash
flutter doctor -v
```

The Android toolchain should be available without installing an Android SDK inside the container manually.

The repository's `.devcontainer` configuration is the source of truth for the exact development-tool versions.

### Persistent Development State

Jellyfinity uses a dedicated Docker volume for `/home/vscode`.

This allows private container state and development caches to survive normal container rebuilds, including state under locations such as:

```text
/home/vscode/.claude
/home/vscode/.codex
/home/vscode/.config
/home/vscode/.pub-cache
/home/vscode/.gradle
```

A normal **Dev Containers: Rebuild Container** preserves this volume.

Do not casually run:

```bash
docker compose down -v
```

and do not manually delete the `jellyfinity-home` Docker volume.

Doing so can permanently delete persistent development state and authenticated CLI sessions.

Credentials and authentication tokens must never be committed to the repository.

## Android Development

The Android emulator runs on the **Windows host**, not inside the Dev Container.

The intended architecture is:

```text
Windows
└── Android Studio
    └── Android Emulator

WSL2
└── VS Code
    └── Jellyfinity Dev Container
        ├── Flutter
        └── Android build toolchain
```

### Android Studio

Install Android Studio on Windows and ensure the following components are available through the SDK Manager:

* Android SDK Platform
* Android SDK Build-Tools
* Android SDK Platform-Tools
* Android Emulator
* Android SDK Command-line Tools

Create an Android Virtual Device using a stable Android system image.

A lightweight Pixel profile with a stable x86_64 Google APIs image is recommended for everyday development.

Physical Android devices can also be used, including through wireless ADB.

### Verify the Emulator

With an emulator running, verify it from Windows PowerShell:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" devices
```

The emulator should appear as a connected device.

The Dev Container must also be able to reach the host ADB server before Flutter can use the Windows-hosted emulator.

Once configured, verify from the Dev Container with:

```bash
adb devices
flutter devices
```

## iOS Development

Jellyfinity targets iOS, but Apple's final iOS compilation and signing toolchain requires macOS and Xcode.

A Mac is **not required for normal Jellyfinity development or Android builds**.

The intended workflow is eventually:

```text
Local Windows/Linux development
        ↓
Git push
        ↓
Hosted macOS CI
        ↓
iOS compilation and validation
```

Real iOS-specific runtime testing will eventually require access to Apple hardware.

## Project Documentation

Before making significant changes, contributors should familiarize themselves with:

* `CONTEXT.md` — compact project context and current direction
* `ROADMAP.md` — planned milestones and release scope
* `PHILOSOPHY.md` — product, UX, privacy, architecture, and engineering principles
* `OUTLOOK.md` — ideas intentionally deferred beyond the current roadmap

The current development milestone is **v0.0.1 — Repository & Project Foundation**.

## Repository Structure

At this stage, the repository contains the project documentation and reproducible development environment:

```text
Jellyfinity/
├── .devcontainer/
├── CONTEXT.md
├── OUTLOOK.md
├── PHILOSOPHY.md
├── README.md
└── ROADMAP.md
```

The Flutter application itself will be added as part of the project foundation.

## License

Jellyfinity is intended to be free and open source.

License details will be documented as the project foundation is completed.
