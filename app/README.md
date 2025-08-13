# Open and save PDF files from and to local device storage in Flutter

This repository contains an example that demonstrates how to open and save PDF files from and to local device storage using the Syncfusion&reg; Flutter PDF Viewer.

## Ubuntu 25 Setup and Requirements

### Prerequisites
- Ubuntu 25 (25.04 or later)
- Flutter SDK (stable channel)
- Android SDK (for Android development)
- Chrome/Chromium (for web development)

### Installation Steps

1. **Update system packages:**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. **Install required dependencies:**
   ```bash
   sudo apt install -y curl git unzip xz-utils zip libglu1-mesa
   sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev
   sudo apt install -y liblzma-dev libstdc++-12-dev
   ```

3. **Install Flutter:**
   ```bash
   # Download Flutter SDK
   cd ~/
   wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.32.0-stable.tar.xz
   tar xf flutter_linux_3.32.0-stable.tar.xz
   
   # Add Flutter to PATH
   echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
   source ~/.bashrc
   ```

4. **Verify Flutter installation:**
   ```bash
   flutter doctor
   ```

5. **Accept Android licenses (if developing for Android):**
   ```bash
   flutter doctor --android-licenses
   ```

### Running the Project

1. **Navigate to the project directory:**
   ```bash
   cd /path/to/flutter-test/app
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the application:**
   ```bash
   # For web (Chrome required)
   flutter run -d chrome
   
   # For Android (device/emulator required)
   flutter run -d android
   
   # For Linux desktop
   flutter run -d linux
   ```

### Troubleshooting Ubuntu 25

- **If you encounter GTK errors:** Install additional GTK development packages
  ```bash
  sudo apt install -y libgtk-3-dev libgtk-4-dev
  ```

- **For web development:** Ensure Chrome/Chromium is installed
  ```bash
  sudo apt install -y chromium-browser
  ```

- **Android development:** Install Android Studio or standalone Android SDK
