# Empeleitas & Vales

A Flutter application for tracking people, empeleitas (work credits), vales (advances), and running balances. It uses Firebase Authentication for Google sign-in and Cloud Firestore for live data updates.

## Features

- Add people with a name and an initial balance.
- Search people by name.
- Add empeleitas, which increase a person's balance.
- Add vales, which decrease the balance.
- Record a date, amount, and optional description for each movement.
- Filter movements by year, month, and day.
- Delete a movement and reverse its effect on the balance.
- Delete a person and their movements.
- Display amounts in Brazilian reais.

The interface uses Portuguese and English labels.

## What this repository contains

The supplied source contains `lib/` only. It does **not** include the original `pubspec.yaml`, lockfile, platform folders, logo, Firebase rules, indexes, or automated tests. You must supply these files or create a Flutter project as described below. The instructions are a reconstruction guide; this package has not been compiled or run as a complete project.

The public copy replaces original Firebase identifiers and administrator emails with compilation variables. It does not connect to the original company's database by default.

## Requirements

- A current stable Flutter SDK and its bundled Dart SDK.
- Chrome for the initial web run.
- A Firebase project you control.
- Firebase CLI and FlutterFire CLI.
- A Google account matching the email domain you configure.
- Android Studio / Android SDK for Android; macOS and Xcode for iOS.

Start by checking your Flutter installation:

```bash
flutter doctor
```

## 1. Create the Flutter project

If you already have the complete project, work in its root and keep its existing dependency versions. Otherwise:

```bash
flutter create --platforms=web,android,ios empeleitas_app
cd empeleitas_app
```

Replace the generated `lib/` with the supplied `lib/`. Do not put it inside another `lib` folder.

### Fix folder capitalization

The archive uses `lib/UI` and `lib/Services`, but the Dart imports use `ui/` and `services/`. Rename the folders to lowercase before running. On macOS or Windows, use an intermediate name if a case-only rename does not take effect:

```bash
mv lib/UI lib/ui_tmp
mv lib/ui_tmp lib/ui
mv lib/Services lib/services_tmp
mv lib/services_tmp lib/services
```

In Windows PowerShell, use `Rename-Item` or rename these folders in your editor instead.

The resulting structure should contain:

```text
lib/
  main.dart
  firebase_options.dart
  auth_gate.dart
  login_page.dart
  home_page.dart
  person_page.dart
  services/
    auth_service.dart
    people_service.dart
  ui/
    app_theme.dart
    widgets.dart
  models/
    person_models.dart
```

## 2. Install dependencies

For a reconstructed project:

```bash
flutter pub add firebase_core firebase_auth cloud_firestore intl
flutter pub add 'google_sign_in:^6.2.1'
```

The existing source uses the Google Sign-In 6.x API (`GoogleSignIn().signIn()` and `googleUser.authentication`). Do not install version 7.x without migrating that code. Exact original dependency versions are unknown because the original manifest and lockfile were not supplied. Commit the generated `pubspec.yaml` and `pubspec.lock` after you resolve and test the dependencies.

The theme uses `Color.withValues`, so older Flutter SDKs may fail to compile it. Upgrade Flutter if this method is unavailable.

## 3. Add the logo

Create `assets/logo.png` using your own logo. The login screen references this exact path. Add this under the existing `flutter:` section of `pubspec.yaml`; do not create a second `flutter:` section:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/logo.png
```

Then run:

```bash
flutter pub get
```

## 4. Connect your Firebase project

1. Create a project in the [Firebase Console](https://console.firebase.google.com/).
2. Create a Cloud Firestore database. Select its location carefully and start with restricted access.
3. Open **Authentication → Sign-in method** and enable **Google**, supplying the required support email.
4. Install the [Firebase CLI](https://firebase.google.com/docs/cli) if needed.
5. Run the following from the Flutter project root:

```bash
firebase login
dart pub global activate flutterfire_cli
flutterfire configure
```

Choose **your own Firebase project** and the platforms you intend to run. Let FlutterFire generate `lib/firebase_options.dart`, replacing the sanitized version. This removes the need to supply the Firebase compilation variables present in the public template.

If `flutterfire` is not found, add the Dart global executable directory to your PATH, as reported by the activation command. Run `flutterfire configure` again when adding a platform or a service that requires extra configuration.

### Web sign-in

In Firebase Authentication settings, add `localhost` to **Authorized domains** if it is not already present. Add your hosting domain when deploying. Allow the browser's sign-in popup.

### Android sign-in

Register the Android package ID for your generated project and add its signing certificate SHA-1 to the Firebase Android app settings. Use the debug certificate for local development and the appropriate release certificate for a release build. Re-run configuration and ensure the Android Firebase configuration belongs to your project.

### iOS sign-in

Register your actual bundle ID and configure the Google Sign-In URL scheme in the Runner target using the reversed client ID from your Firebase iOS configuration. Follow the package's platform setup instructions. iOS builds require macOS and Xcode.

Start with web; this guide does not claim that the supplied source has been tested on every native platform. Linux is explicitly unsupported by the original Firebase platform selector.

## 5. Configure the organization and administrators

Copy `app_config.example.json` from this package to `app_config.json` in the project root and replace its example values:

```json
{
  "ALLOWED_EMAIL_DOMAIN": "@your-company.com",
  "ADMIN_EMAIL_1": "admin@your-company.com",
  "ADMIN_EMAIL_2": "second-admin@your-company.com"
}
```

Use lowercase emails. Include the leading `@` in the domain. Both administrator accounts must also pass the domain restriction. If you only need one administrator, leave the second value empty.

This configuration is read using `String.fromEnvironment` at build time. Editing the JSON requires restarting or rebuilding with `--dart-define-from-file`; hot reload alone does not apply new compilation values.

The same administrator values are used by `services/auth_service.dart`, `home_page.dart`, and `person_page.dart`. Do not configure only one of those locations in an unsanitized version of the code.

Add this entry to the root `.gitignore`:

```gitignore
/app_config.json
```

These values are compiled into the client. They configure the interface and login checks; they are not server-side authorization or secret storage.

## 6. Configure Firestore access

The archive does not contain the original rules. You must configure access before the application can read or write data. Never use unrestricted public access for real financial records.

### Initial administrator-only setup

For an initial setup with an administrator and disposable sample data, the following baseline allows verified, explicitly listed administrators to access the paths used by the app. Replace the example emails with the **same** administrator emails as your local JSON. Publish these rules in **Firestore Database → Rules**:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAdmin() {
      return request.auth != null
        && request.auth.token.email_verified == true
        && request.auth.token.email in [
          'admin@your-company.com',
          'second-admin@your-company.com'
        ];
    }

    match /people/{personId} {
      allow read, write: if isAdmin();

      match /movements/{movementId} {
        allow read, write: if isAdmin();
      }
    }
  }
}
```

This is an administrator-only baseline, not the original production policy or complete financial validation. Employees will receive permission errors with these rules. Add schema validation and a reviewed employee policy before using employee accounts or real records.

### Actual employee behavior in this source

| Action | Administrator UI | Employee UI |
| --- | --- | --- |
| List people and balances | Yes | Yes |
| Add a person | Yes | Yes |
| View empeleitas | Yes | Yes |
| View vales | Yes | No |
| Add/delete empeleitas | Yes | Yes |
| Add/delete vales | Yes | No |

Person deletion is also available from the people list without an administrator guard. The server rules must enforce your intended permissions.

There is no owner UID or account-to-person mapping in the supplied person documents. Employees are **not restricted to their own person record** by this code. The people query requests the entire collection; employee movement queries filter only by `type == "empeleita"`.

If you want each employee to access only their own records, add an ownership field, constrain the queries, and implement matching Firestore rules. Rules cannot simply filter out unauthorized results from the current unrestricted people query. Also review whether employees should see balances that include hidden vales.

## 7. Run the app

From the complete project's root, after configuring Firebase and the asset:

```bash
flutter pub get
flutter analyze
flutter run -d chrome --web-port=5050 --dart-define-from-file=app_config.json
```

For a connected Android device or iOS simulator:

```bash
flutter devices
flutter run -d YOUR_DEVICE_ID --dart-define-from-file=app_config.json
```

Replace `YOUR_DEVICE_ID` with an ID from `flutter devices`.

## 8. Verify the first run

Use your administrator account and sample data:

1. Sign in with Google.
2. Add a person named `Demo Person` with an initial balance of `0`.
3. Add an empeleita of `100`; the balance should become `R$ 100,00`.
4. Add a vale of `30`; the balance should become `R$ 70,00`.
5. Check the date filters.
6. Delete the vale; the balance should return to `R$ 100,00`.
7. Sign out and sign in again; confirm the data remains available.

No manual collection seeding is needed: the administrator's first successful write creates the records.

## Data model

| Path / field | Type | Meaning |
| --- | --- | --- |
| `people/{personId}.name` | string | Display name |
| `people/{personId}.value` | number | Stored running balance |
| `people/{personId}.createdAt` | timestamp | Creation timestamp |
| `people/{personId}/movements/{movementId}.type` | string | `empeleita` or `vale` |
| `…/movements/{movementId}.amount` | number | Positive movement amount |
| `…/movements/{movementId}.description` | string or null | Optional description |
| `…/movements/{movementId}.date` | timestamp | Selected movement date |

Adding and deleting movements updates the balance in a Firestore transaction. Initial balance is stored on the person document, without creating an initial movement. The older `models/person_models.dart` uses debit/credit names; the active Firestore UI uses `empeleita` and `vale`.

If Firestore returns a missing-index error for movement queries, follow its console link to create the requested index. The employee query combines a `type` equality filter with descending `date` ordering.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Import file not found | Rename `UI` and `Services` to lowercase; check the project is not nested under `lib/lib`. |
| Logo missing | Supply `assets/logo.png` and declare it in `pubspec.yaml`. |
| `GoogleSignIn` or `signIn` API errors | Use Google Sign-In 6.x with this source, or migrate to the newer API. |
| `withValues` not found | Update the Flutter SDK. |
| Login rejects the account | Confirm the configured domain, administrator emails, and build command. |
| Google provider disabled | Enable Google in Firebase Authentication. |
| Unauthorized domain / popup blocked | Add the actual hostname to Firebase authorized domains and allow popups. |
| Firestore `permission-denied` | Review server rules and the signed-in account; the baseline intentionally denies employee access. |
| Firestore `failed-precondition` with an index link | Create the index requested by Firestore. |
| Firebase initialization fails | Regenerate `firebase_options.dart` for your own project and selected platform. |
| Android Google sign-in fails | Check package ID, signing SHA-1, provider, and Firebase configuration. |
| Linux unsupported | Use a configured platform; the original platform selector rejects Linux. |

## Build for web

After a successful local verification:

```bash
flutter build web --dart-define-from-file=app_config.json
```

The output is `build/web/`. Before hosting it, configure the hosting domain for Google authentication and review Firestore permissions.

## References

- [Flutter installation](https://docs.flutter.dev/install)
- [Firebase setup for Flutter](https://firebase.google.com/docs/flutter/setup)
- [Firebase federated authentication](https://firebase.google.com/docs/auth/flutter/federated-auth)
- [Google Sign-In 6.x documentation](https://pub.dev/packages/google_sign_in/versions/6.3.0)
- [Firestore rules and queries](https://firebase.google.com/docs/firestore/security/rules-query)

## Project status

Source reviewed from the provided `lib` archive. A full build, native sign-in, deployed Firestore permissions, and dependency compatibility have not been verified. Use your own Firebase environment and sample data for the first run.
