# #hoppers - Text-to-Speech 🦎 🦫 🪵

Simple - Fun project | speak typed emojis | GCP Text-to-Speech | Flutter | Firebase

## 🚀 Key Updates (v1.1.0)
minimise API calls | low latency | cost-efficieny
1. **Local Cache (Hive)**: Instant replay of recently used emojis directly from device storage.
- **Glocal Cache (Firebase Storage)**: Shared cloud storage for pre-generated audio, reducing the need for repeated API hits.
- **Synthesis (Google Cloud TTS)**: Final fallback using the en-US-Chirp-HD-F model for high-quality voice generation.

## 🛠️ Project Structure
- `/lib`: Flutter frontend code.
- `/functions`: Python-based Firebase Cloud Functions (Backend).

## ⚙️ Setup Instructions

### 1. Prerequisites
- Flutter SDK
- Firebase CLI
- Python 3.11+ (for functions)

### 2. Firebase Configuration
```bash

flutterfire configure
