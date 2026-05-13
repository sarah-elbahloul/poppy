# 🌺 Poppy

> *where every day finds its petal*

A calm, personal diary app for iOS and Android built with Flutter and Supabase. Poppy is designed around one idea: writing should feel effortless. No cluttered toolbars, no social features, no distractions — just you and your words.

---

## Screenshots

> Add screenshots here once the app is running.

---

## Features

- **Write** — Full diary entries with titles, dates, and up to 10,000 words per entry
- **Photos** — Attach up to 10 photos per entry, kept in a dedicated section separate from text
- **Color tags** — Six entry colors (Poppy, Iris, Lily, Marigold, Lavender, Stone) shown as a subtle accent strip
- **Custom date** — Set any past date for an entry; the home list always sorts by entry date
- **Search** — Full-text search across titles and content, filterable by color tag and date range
- **Batch delete** — Long press any entry on the home screen to enter selection mode, then delete multiple entries at once
- **Themes** — Five pastel flower themes: Poppy (default), Iris, Lily, Marigold, Lavender
- **PIN lock** — Optional 4-digit PIN to protect the app on launch
- **Import / Export** — Export your diary to a `.poppy` file and restore it on any device
- **Account management** — Change email or password from within the app
- **Legal** — Privacy policy, terms of use, and open source licenses included

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile framework | Flutter 3.x (Dart) |
| Backend / Auth | Supabase (PostgreSQL + Auth + Storage) |
| State management | Provider |
| Navigation | Flutter Navigator (named routes) |
| Fonts | Google Fonts — Lora (content) + Inter (UI) |
| Secure storage | flutter_secure_storage |
| Image handling | image_picker + flutter_image_compress |
| Export / Import | share_plus + file_picker |

---

## Project Structure

```
lib/
├── main.dart                        # App entry point
├── app.dart                         # MaterialApp + auth routing
│
├── core/
│   ├── app_routes.dart              # All named route constants
│   ├── constants.dart               # DB names, color tags, storage keys
│   ├── error_messages.dart          # Centralised user-friendly errors
│   ├── supabase_client.dart         # Supabase init + helpers
│   │
│   ├── style/
│   │   ├── style.dart               # Barrel export (import this everywhere)
│   │   ├── app_theme.dart           # 5 flower themes + ThemeExtension
│   │   ├── app_colors.dart          # Raw hex palette
│   │   ├── app_text_styles.dart     # All text styles (Lora + Inter)
│   │   ├── app_sizes.dart           # Spacing, radius, icon sizes
│   │   ├── app_icons.dart           # Rounded icon aliases
│   │   ├── app_shadows.dart         # Box shadows
│   │   └── app_durations.dart       # Animation durations + curves
│   │
│   └── widgets/
│       ├── entry_card.dart          # Compact home screen card
│       ├── color_dot.dart           # Color tag dot indicator
│       ├── color_tag_picker.dart    # Tag picker toolbar
│       ├── photo_strip.dart         # Collapsible photo row
│       ├── poppy_logo.dart          # Flower logo (pure canvas)
│       └── pin_pad.dart             # 4-digit PIN pad
│
├── models/
│   ├── entry.dart                   # Diary entry model
│   └── photo.dart                   # Photo model
│
├── providers/
│   ├── auth_provider.dart           # Auth state + PIN lock state
│   ├── entries_provider.dart        # Entry list state
│   └── theme_provider.dart          # Active flower theme
│
├── services/
│   ├── auth_service.dart            # Supabase auth calls
│   ├── entries_service.dart         # Entry CRUD + full-text search
│   ├── photos_service.dart          # Photo upload/fetch (web + mobile)
│   ├── pin_service.dart             # PIN hash + verify
│   └── export_service.dart          # Import / export .poppy files
│
└── screens/
    ├── lock_screen.dart
    ├── auth/
    │   ├── login_screen.dart
    │   └── register_screen.dart
    ├── home/
    │   └── home_screen.dart
    ├── write/
    │   └── write_screen.dart        # Create + edit (no separate detail screen)
    ├── search/
    │   └── search_screen.dart
    └── settings/
        ├── settings_screen.dart
        ├── appearance_screen.dart
        ├── account_screen.dart
        ├── security_screen.dart
        └── legal_screen.dart

supabase/
└── migrations/
    ├── 01_tables.sql                # All table definitions
    ├── 02_indexes.sql               # Performance indexes
    ├── 03_policies.sql              # RLS + storage bucket policy
    └── 04_functions_triggers.sql    # updated_at + new user trigger
```

---

## Getting Started

### Prerequisites

- Flutter SDK `>=3.3.0`
- A [Supabase](https://supabase.com) project
- Android Studio or VS Code with the Flutter plugin

### 1. Clone the repository

```bash
git clone https://github.com/your-username/poppy.git
cd poppy
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Set up Supabase

1. Create a new project at [supabase.com](https://supabase.com)
2. Go to **SQL Editor** and run the migration files in order:
   ```
   supabase/migrations/01_tables.sql
   supabase/migrations/02_indexes.sql
   supabase/migrations/03_policies.sql
   supabase/migrations/04_functions_triggers.sql
   ```
3. Go to **Storage → New bucket**, create a bucket named `entry-photos` with **Public: OFF**
4. Go to **Project Settings → API** and copy your **Project URL** and **anon key**

### 4. Configure credentials

#### Android Studio

1. Open **Run → Edit Configurations**
2. Select your `main.dart` configuration
3. In **Additional run args**, paste:
   ```
   --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key
   ```

#### VS Code

Create `.vscode/launch.json`:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Poppy",
      "request": "launch",
      "type": "dart",
      "args": [
        "--dart-define=SUPABASE_URL=https://your-project.supabase.co",
        "--dart-define=SUPABASE_ANON_KEY=your-anon-key"
      ]
    }
  ]
}
```

### 5. Run the app

```bash
flutter run
```

---

## Import / Export Format

Poppy exports diaries as `.poppy` files (JSON with a custom extension).

```json
{
  "version": "1.0",
  "app": "Poppy",
  "exported_at": "2026-05-13T10:00:00Z",
  "entry_count": 42,
  "entries": [
    {
      "id": "uuid",
      "title": "A slow Sunday walk",
      "content": "The park was...",
      "color_tag": "poppy",
      "word_count": 342,
      "entry_date": "2026-05-04",
      "created_at": "2026-05-04T09:00:00Z",
      "updated_at": "2026-05-04T09:12:00Z",
      "photo_urls": []
    }
  ]
}
```

**Note:** Photos are not included in exports. The export records how many photos an entry had but does not embed the image data. Re-add photos manually after importing on a new device.

---

## Word Limit

Each entry is limited to **10,000 words** (≈ 60,000 characters). This is enforced at two levels:

- **App** — A live word counter in the write screen turns orange at 90% and red at 100%. Saving is blocked when over the limit.
- **Database** — A `CHECK` constraint on the `content` column prevents oversized entries from being stored even if the app check is bypassed.

---

## Color Tags

Each entry can be tagged with one of six colors. The color appears as a 3px accent strip on the left of each entry card — subtle enough not to distract, visible enough to distinguish.

| Tag | Color |
|---|---|
| Poppy | `#C94040` |
| Iris | `#5C7FC4` |
| Lily | `#4FAD74` |
| Marigold | `#B87030` |
| Lavender | `#9050A8` |
| Stone | `#888888` (default) |

---

## Themes

All themes are pastel. Switching themes changes the accent color and surface tints only — backgrounds stay near-white in every theme.

| Theme | Emoji | Accent |
|---|---|---|
| Poppy (default) | 🌺 | `#C94040` |
| Iris | 🪻 | `#5C7FC4` |
| Lily | 🌸 | `#4FAD74` |
| Marigold | 🌼 | `#B87030` |
| Lavender | 💜 | `#9050A8` |

---

## Security

- Passwords are handled entirely by Supabase Auth — never stored in the app
- The optional PIN lock stores only a **SHA-256 hash** of the PIN using `flutter_secure_storage`. The raw PIN is never persisted
- Row Level Security (RLS) is enabled on all database tables — every query is scoped to the authenticated user's own data
- Photo storage is private — signed URLs expire after 1 hour

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes: `git commit -m 'Add your feature'`
4. Push to the branch: `git push origin feature/your-feature`
5. Open a pull request

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Contact

Questions or feedback? Reach out at sa.albahloul@gmail.com