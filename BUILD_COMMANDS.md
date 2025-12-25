# Build Commands

## Web Application (Unified Portal)

The web version provides a unified portal where users can choose between Doctor and Patient login.

### Run in debug mode (Chrome)
```bash
flutter run -d chrome
```

### Run on specific port
```bash
flutter run -d chrome --web-port=8080
```

### Build for production
```bash
flutter build web --release
```

### Build with custom base href (for subdirectory deployment)
```bash
flutter build web --release --base-href /healthcare/
```

### Deploy
After building, the output will be in the `build/web` directory. Deploy this to your web server or hosting platform (Firebase Hosting, Netlify, Vercel, etc.).

---

## Doctor App (Mobile)

### Run in debug mode
```bash
flutter run --flavor doctor --target lib/main_doctor.dart
```

### Build APK
```bash
flutter build apk --flavor doctor --target lib/main_doctor.dart
```

### Build release APK
```bash
flutter build apk --release --flavor doctor --target lib/main_doctor.dart
```

### Build iOS
```bash
flutter build ios --flavor doctor --target lib/main_doctor.dart
```

---

## Patient App (Mobile)

### Run in debug mode
```bash
flutter run --flavor patient --target lib/main_patient.dart
```

### Build APK
```bash
flutter build apk --flavor patient --target lib/main_patient.dart
```

### Build release APK
```bash
flutter build apk --release --flavor patient --target lib/main_patient.dart
```

### Build iOS
```bash
flutter build ios --flavor patient --target lib/main_patient.dart
```

---

## Generate Code

Run freezed and json_serializable code generation:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Watch mode for continuous generation:
```bash
flutter pub run build_runner watch --delete-conflicting-outputs
```

---

## Install Dependencies

```bash
flutter pub get
```

---

## Testing

### Run all tests
```bash
flutter test
```

### Run with coverage
```bash
flutter test --coverage
```

---

## Common Tasks

### Clean build artifacts
```bash
flutter clean
flutter pub get
```

### Analyze code
```bash
flutter analyze
```

### Format code
```bash
flutter format .
```

---

## Deployment Guide

### Web Deployment

1. Build the web app:
   ```bash
   flutter build web --release
   ```

2. Deploy the `build/web` directory to your hosting platform:

   **Firebase Hosting:**
   ```bash
   firebase deploy --only hosting
   ```

   **Netlify:**
   - Drag and drop the `build/web` folder to Netlify dashboard
   - Or use Netlify CLI: `netlify deploy --prod --dir=build/web`

   **Vercel:**
   ```bash
   vercel --prod build/web
   ```

### Mobile Deployment

**Android:**
1. Build release APK or AAB:
   ```bash
   flutter build appbundle --release --flavor doctor --target lib/main_doctor.dart
   ```
2. Upload to Google Play Console

**iOS:**
1. Build iOS app:
   ```bash
   flutter build ios --release --flavor doctor --target lib/main_doctor.dart
   ```
2. Archive in Xcode and upload to App Store Connect
