# #hoppers - TTS 🦎 🦫 🪵

A Flutter application that translates text (specifically emojis) on go using Google Cloud Text-to-Speech and Firebase Cloud Functions.

## 🚀 Current Features (v1.0.0)
- **Real-time TTS**: Triggers a voice response on every character typed.
- **Emoji Support**: Demojizes emojis to speak their names (e.g., 🦎 becomes "Lizard").
- **Smart Caching**: Uses Firebase Storage to cache generated `.mp3` files to save API costs and improve speed.
- **Cross-Platform**: Works on Web and Mobile via Flutter.
- **Local Emulators**: Pre-configured for local testing with Firebase Emulators.

## 🛠️ Project Structure
- `/lib`: Flutter frontend code.
- `/functions`: Python-based Firebase Cloud Functions (Backend).
- `/.gitignore`: Configured to protect sensitive Firebase config files.

## ⚙️ Setup Instructions

### 1. Prerequisites
- Flutter SDK
- Firebase CLI
- Python 3.11+ (for functions)

### 2. Firebase Configuration
Since `firebase_options.dart` is ignored for security, you must generate it yourself:
```bash
flutterfire configure
