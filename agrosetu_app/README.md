# AgroSetu Flutter App

Mobile client for the AgroSetu smart farming platform.

## Requirements
- Flutter 3.x
- Dart 3.x
- iOS 14+ / Android 8+

## Getting Started

```bash
flutter pub get
flutter run --dart-define=API_HOST=<your-backend-ip>
```

## Project Structure

```
lib/
  screens/       # All UI screens (27 screens)
  services/      # API, auth, weather, disease history services
  widgets/       # Reusable UI components
  l10n/          # English + Nepali translations
```

## Build

```bash
# Android APK
flutter build apk --release --dart-define=API_HOST=<ip>

# iOS
flutter build ios --release
```
