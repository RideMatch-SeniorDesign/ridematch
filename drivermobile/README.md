# RideMatch Driver Mobile

Flutter app for the driver side of RideMatch.

## Run On An Android Emulator

The app defaults to the Android emulator host, so this usually works with:

```powershell
flutter run
```

## Run On A Samsung Or Other Physical Android Device

When you run on a real phone, `10.0.2.2` will not work because that address only points back to your computer from the Android emulator. For a Samsung device, set the app to use your computer's Wi-Fi IP address instead.

### 1. Find your computer's IP address

In PowerShell, run:

```powershell
ipconfig
```

Look for the `Wireless LAN adapter Wi-Fi` section and copy the `IPv4 Address`.

Example:

```text
IPv4 Address. . . . . . . . . . . : 192.168.4.38
```

### 2. Update `device.env`

Open `device.env` and set `API_HOST` to that IP address:

```env
API_HOST=192.168.4.38
```

### 3. Start the driver backend

Make sure the driver backend is running on port `8002`.

### 4. Connect your Samsung

- Connect the phone and your computer to the same Wi-Fi network.
- Enable Developer Options and USB debugging on the Samsung device.
- Confirm any USB debugging prompt on the phone.

### 5. Run the app

From the `drivermobile` folder, run:

```powershell
flutter run --dart-define-from-file=device.env
```

## Notes

- If your Wi-Fi IP changes, update `device.env` again.
- If requests still fail on the phone, check that Windows Firewall allows inbound connections to port `8002`.
- `device.env` is meant for local machine setup and usually should not be committed with your personal IP address.
