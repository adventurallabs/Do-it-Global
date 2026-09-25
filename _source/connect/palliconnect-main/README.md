# PalliConnect

PalliConnect is a comprehensive school management platform designed for parents, students, and administrators. It features real-time bus tracking, digital ID cards, academic records, and communication tools.

## Features

- **Real-time Bus Tracking:** Track school buses in real-time for improved student safety and convenience.
- **Digital ID Card:** Secure, QR-code based digital identification for students.
- **Academic Records:** Access attendance, marks, and academic performance data.
- **Communication:** Stay updated with school announcements and diary entries.
- **Multilingual Support:** Support for English, Tamil, and more.
- **Secure Backend:** Powered by Supabase for authentication and real-time data synchronization.

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Android Studio / VS Code
- A Supabase project

### Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/palliconnect.git
   cd palliconnect
   ```

2. **Configure Environment Variables:**
   - Copy `.env.example` to `.env`.
   - Fill in your `SUPABASE_URL` and `SUPABASE_ANON_KEY` from your Supabase dashboard.
   ```bash
   cp .env.example .env
   ```

3. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

4. **Run the App:**
   ```bash
   flutter run
   ```

## Build Instructions

### Android

To build a release APK:
```bash
flutter build apk --release --split-per-abi
```

## Security

**Important:** Never commit your `.env` file or any secret keys to public repositories. The `.gitignore` file is pre-configured to exclude sensitive files.

---
© 2026 Adventural PalliConnect
