# Fix: "Operation not permitted" networking errors on macOS desktop

If you run the app with `flutter run` and pick the **macOS (desktop)**
target (option shown as `[1]: macOS (macos)`), macOS's App Sandbox blocks
*all* outgoing network connections by default — including calls to your
ASP.NET API on localhost and (previously) Google Fonts. That's the
`ClientException ... Operation not permitted, errno = 1` error.

**Fix:** copy both files in this folder over the generated ones at:

    macos/Runner/DebugProfile.entitlements
    macos/Runner/Release.entitlements

(these only exist after you've run `flutter create .`)

Then stop and re-run:

    flutter run -d macos

**Easier alternative:** just run on the iOS Simulator or an Android
emulator instead of macOS desktop — neither has this sandboxing
restriction, so no entitlements editing is needed at all:

    open -a Simulator
    flutter run --dart-define=API_BASE_URL=http://localhost:5000
