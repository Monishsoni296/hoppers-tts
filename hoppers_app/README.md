# Hoppers App - Frontend

The Flutter interface for the Lizard TTS project.

## 🛠 Features
- **Real-time Emoji Detection**: Listens to text input to trigger translations.
- **Audio Playback**: Uses `audioplayers` to play cached `.mp3` files from Firebase Storage.
- **Anonymous Auth**: Silently signs in users to allow secure Storage access.

## 🏗 Setup
1. Ensure you have the Flutter SDK installed.
2. Run `flutter pub get` to install dependencies.
3. Use `flutterfire configure` to link your local environment to the Firebase project.

## 🧪 Testing
To test with the local emulator:
```bash
# Ensure emulators are running in the background
flutter run -d chrome --web-port=5000