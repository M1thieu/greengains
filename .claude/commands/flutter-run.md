Run the Flutter app on the connected Android device with the required dart defines.

Run this command:
```
/c/Users/mathi/flutter/bin/flutter run --device-id 29081FDH200BGW --debug --dart-define-from-file=dart_defines.json
```

If the device is not found, first run `adb devices` to check what's connected and use the correct device ID.
