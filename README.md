# 📒🌺 Poppy

> *where every day finds its petal*

A calm, privacy-first personal diary app for iOS and Android built with Flutter and Supabase. Poppy is designed to be a safe haven for your thoughts, featuring **Zero-Knowledge end-to-end encryption (E2EE)** as standard. Your words stay yours — no one, not even Supabase or the developers, can read your entries.

---

## Screenshots

> Add screenshots here once the app is running.

---

## Features

- **End-to-End Encryption** — Titles and content are encrypted locally using AES-256-GCM before ever leaving your device.
- **Effortless Writing** — A clean, focused editor with support for titles, custom dates, and no character limits.
- **Secure Photos** — Attach up to 10 photos per entry, stored in private storage buckets with time-limited access URLs.
- **Batch Actions** — Long-press entries on the home screen to enter selection mode and delete multiple items at once.
- **Search** — Fast, client-side filtered search by keywords, color tags, or date ranges.
- **Flower Themes** — Five beautiful pastel themes (Poppy, Iris, Lily, Marigold, Lavender) that adapt the entire UI.
- **PIN Lock** — Optional 4-digit PIN protection with secure hashing (`flutter_secure_storage`).
- **Data Ownership** — Export your entire diary to a portable `.poppy` (JSON) backup and restore it on any device.
- **Smart Recovery** — A unique key-wrapping architecture allows password resets via email without losing access to your encrypted data.

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3.x (Dart) |
| **Backend** | Supabase (PostgreSQL, Auth, Storage) |
| **Encryption** | AES-256-GCM (via `cryptography`) |
| **State Management** | Provider |
| **Navigation** | Standard Flutter Navigator (Named Routes) |
| **Icons** | Iconsax |
| **Fonts** | Google Fonts (Lora for content, Inter for UI) |

---

## Security Model (Zero-Knowledge)

Poppy uses a "Zero-Knowledge" architecture to ensure your privacy:
1. **Data Key:** A random 32-byte master key is generated on your device during registration.
2. **Key Wrapping:** This key is encrypted with a key derived from your password (PBKDF2) and stored in the database.
3. **Recovery:** A second copy is wrapped with your unique UID and an app-level pepper, allowing for account recovery without compromising the "zero-knowledge" nature.
4. **Encryption:** Every entry you save is encrypted with your Data Key locally. The cloud only ever stores random-looking ciphertexts.

---

## Project Structure

```
lib/
├── main.dart                        # App entry point
├── app.dart                         # MaterialApp + Auth-driven routing
│
├── core/
│   ├── app_routes.dart              # Named route definitions
│   ├── constants.dart               # DB schemas, storage keys, colors
│   ├── supabase_client.dart         # Supabase client & initialisation
│   └── style/                       # Theming, Iconsax, and typography
│
├── models/
│   ├── entry.dart                   # Diary entry model (handles E2EE mapping)
│   └── photo.dart                   # Photo metadata model
│
├── providers/
│   ├── auth_provider.dart           # Session, PIN lock, and Key state
│   ├── entries_provider.dart        # Entry list and CRUD state
│   └── theme_provider.dart          # Dynamic flower themes
│
├── services/
│   ├── encryption_service.dart      # AES-256-GCM logic & Key Wrapping
│   ├── entries_service.dart         # Encrypted CRUD operations
│   ├── photos_service.dart          # Private storage handling
│   ├── auth_service.dart            # Supabase Auth wrapper
│   └── export_service.dart          # JSON backup / restore logic
│
└── screens/
    ├── auth/                        # Login, Register, Recovery
    ├── home/                        # Entry list with batch selection
    ├── write/                       # The editor (Create & Edit)
    ├── search/                      # Filtered search interface
    ├── settings/                    # Theming, Account, and Security
    └── lock_screen.dart             # PIN entry shield
```

---

## Getting Started

### Prerequisites

- Flutter SDK `>=3.3.0`
- A [Supabase](https://supabase.com) account
- Android Studio or VS Code

### 1. Clone & Install

```bash
git clone https://github.com/sarah-elbahloul/poppy.git
cd poppy
flutter pub get
```

### 2. Supabase Setup

1. Create a project on Supabase.
2. Run the SQL migrations found in `/supabase/migrations` in order (01 to 04).
3. Create a **Private** Storage bucket named `entry-photos`.
4. Enable **Site URL** and **Redirect URLs** in Auth settings for password recovery functionality.

### 3. Environment Variables

Poppy uses `--dart-define` for secrets. 

**Android Studio:** Add to "Additional run args":
`--dart-define=SUPABASE_URL=YOUR_URL --dart-define=SUPABASE_ANON_KEY=YOUR_KEY`

**VS Code (`launch.json`):**
```json
"args": [
  "--dart-define=SUPABASE_URL=YOUR_URL",
  "--dart-define=SUPABASE_ANON_KEY=YOUR_KEY"
]
```

---

## License

Distributed under the MIT License. See `LICENSE` for more information.

---

## Contact

Sarah Elbahloul - sa.albahloul@gmail.com

Project Link: [https://github.com/sarah-elbahloul/poppy](https://github.com/your-username/poppy)
