# RideMatch scripts for this repo

These scripts are designed to live inside the repo:

```text
ridematch/
├── .venv/                  # created by setup_env
├── scripts/
├── AdminWebpage/
├── RiderWebpage/
├── DriverWebpage/
├── ridermobile/
├── drivermobile/
└── ...
```

## First-time setup

Open a terminal in the `ridematch` folder, then run the setup script for your OS.

### macOS

```bash
chmod +x scripts/*.sh
./scripts/setup_env.sh
```

Then activate it.
### Windows PowerShell

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\setup_env.ps1
```

This will:
- create the virtual environment at `ridematch/.venv`
- install Python packages
- run `flutter pub get` for both mobile apps when Flutter is installed
- run `pod install` for iOS if CocoaPods is installed on macOS

## Main commands

### macOS

```bash
./scripts/run_admin.sh
./scripts/run_rider_web.sh
./scripts/run_driver_web.sh
./scripts/start_all_web.sh
./scripts/open_repo.sh
```

### Windows PowerShell

```powershell
.\scripts\run_admin.ps1
.\scripts\run_rider_web.ps1
.\scripts\run_driver_web.ps1
.\scripts\start_all_web.ps1
.\scripts\open_repo.ps1
```

## Mobile apps

### Rider mobile

```bash
./scripts/run_rider_mobile.sh ios-simulator
./scripts/run_rider_mobile.sh iphone
./scripts/run_rider_mobile.sh android-emulator
./scripts/run_rider_mobile.sh samsung
```

### Driver mobile

```bash
./scripts/run_driver_mobile.sh ios-simulator
./scripts/run_driver_mobile.sh iphone
./scripts/run_driver_mobile.sh android-emulator
./scripts/run_driver_mobile.sh samsung
```

## Mobile host modes

The mobile scripts automatically rewrite `device.env` before launching:

- `ios-simulator` → `API_HOST=127.0.0.1`
- `iphone` → `API_HOST=<your Mac's current LAN IP>`
- `android-emulator` → `API_HOST=10.0.2.2`
- `samsung` → `API_HOST=<your Mac's current LAN IP>`

You can also pass a custom IP instead of one of those names:

```bash
./scripts/run_rider_mobile.sh 192.168.1.25
```

You can optionally pass a Flutter device id as the second argument:

```bash
./scripts/run_rider_mobile.sh android-emulator emulator-5554
./scripts/run_driver_mobile.sh samsung R58N123456A
```

## Good to know

- Because `.venv` lives in `ridematch/`, it stays outside Git.
- These scripts assume you run them from the repo root.
- Real phones need your phone and Mac on the same Wi-Fi.
