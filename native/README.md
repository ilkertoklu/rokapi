# Native apps

iOS and Android shells around the web app, built with [Hotwire Native](https://native.hotwired.dev). Every screen is the web app; the shells add a native navigation stack. Both load their navigation rules from Rails at `/hotwire_native/path_configuration.json`, which serves `config/path_configuration.json`.

## iOS

- Xcode 16 or later. The project is generated from `ios/project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen); after changing `project.yml`, run `xcodegen generate` in `ios/`.
- Open `ios/Rokapi.xcodeproj`, pick a simulator and run. Debug builds talk to `http://localhost:3000` (`ROKAPI_URL` in `project.yml`).

## Android

- Android Studio with JDK 17. Open `android/` and run the `app` configuration on an emulator, or `./gradlew installDebug`.
- Debug builds talk to `http://10.0.2.2:3000`, the emulator's address for the host (`ROOT_URL` in `app/build.gradle.kts`).

Start the server with `bin/dev` before launching either app.
