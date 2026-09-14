unset ADB_SERVER_SOCKET
adb kill-server
adb start-server
adb connect 192.168.178.21:5555
adb devices

adb -s 192.168.178.21:5555 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s 192.168.178.21:5555 shell am start -n io.nachbar.jellyfinity/.MainActivity
