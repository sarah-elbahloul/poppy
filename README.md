# 📒🌺 Poppy

> *where every day finds its petal*

Poppy is a calm, privacy-first personal diary app for iOS and Android, meticulously crafted with Flutter and Supabase. It serves as a digital sanctuary, combining a minimalist aesthetic with a heavy emphasis on data sovereignty and security.

Built for users who value peace of mind, Poppy features **Zero-Knowledge end-to-end encryption (E2EE)** as its foundation. Your words are yours alone — not even the developers or the database providers can peek into your inner world.

---

## 📸 Visuals

### 1. The Welcome Experience
*Clean, inviting onboarding focusing on security from the first tap.*
> **Screenshot Idea:** The Signup or Login screen showing the `PasswordRulesChecker`.

### 2. A Canvas for Your Thoughts
*The Home screen adapts to your personal style. Here are three different moods created using the internal Design Studio:*
*   **Classic Poppy:** Soft pinks (#F8E8E8) and warm corals, using *Lora* for titles.
*   **Midnight Garden:** Deep charcoal backgrounds (#121212) with vibrant neon-purple accents (#BB86FC).
*   **Nordic Mist:** Minimalist cool greys and slate blues (#E3F2FD) with *Inter* for a clean, modern feel.
> **Screenshot Idea:** Three side-by-side Home screens showcasing 7+ entries each in these distinct color palettes.

### 3. The Design Studio
*Empowering users to be the architect of their own experience.*
> **Screenshot Idea:** The Appearance screen showing the Font Pair selection and the Hex/Wheel Color Picker in action.

---

## ✨ Key Features

- **🔐 Zero-Knowledge Security** — Titles and content are encrypted locally using AES-256-GCM. Keys are derived via PBKDF2 and wrapped securely, ensuring data is indecipherable before it ever leaves the device.
- **🎨 Infinite Personalization** — Gone are static themes. Poppy's new **Design Studio** allows you to customize every primary and secondary color slot via a hex-code picker and live-preview canvas. Choose between sophisticated Serif and Sans-Serif font pairings.
- **☁️ Offline-First Sync** — Seamlessly write entries and attach photos without a connection. Changes are cached in a local SQLite database and synchronized to Supabase automatically when online.
- **🖼️ Private Photo Vault** — Attach up to 10 photos per entry. Photos are stored in private Supabase buckets, accessed only via time-limited, signed URLs generated on-the-fly.
- **🛡️ PIN Ready** — Secure your diary with an optional 4-digit PIN, managed via `flutter_secure_storage` to prevent unauthorized physical access.
- **📦 Data Ownership** — Export your entire history to a portable `.JSON` backup. You own your data; move it wherever you like.

---

## 🛠️ Technical Excellence

Poppy is built with a focus on clean architecture, performance, and modern Dart practices.

| Layer | Technology | Engineering Highlights |
|---|---|---|
| **Framework** | Flutter 3.x | Custom UI components, smooth animations, and responsive layouts. |
| **Backend** | Supabase | Real-time Postgres sync, Edge Functions ready, and secure Storage buckets. |
| **Persistence** | SQLite (`sqflite`) | Robust offline-first caching layer for low-latency interactions. |
| **Encryption** | AES-256-GCM | Industry-standard cryptography for hardware-accelerated security. |
| **State** | Provider | Reactive state management for real-time theme and entry updates. |
| **Storage** | Secure Storage | Sensitive keys and PINs never touch the disk in plain text. |

### Architecture
The project follows a modular service-oriented architecture:
- **`lib/services/`**: Encapsulates business logic (Encryption, Sync, Auth) for high testability.
- **`lib/providers/`**: Manages app state and acts as a bridge between services and UI.
- **`lib/core/`**: Centralized design system (tokens, icons, typography) and utility constants.

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK `>=3.3.0`
- A [Supabase](https://supabase.com) project

### 1. Installation
```bash
git clone https://github.com/sarah-elbahloul/poppy.git
cd poppy
flutter pub get
```

### 2. Environment Configuration
Poppy uses `--dart-define` to inject secrets safely.

**Example Command:**
```bash
flutter run --dart-define=SUPABASE_URL=YOUR_URL --dart-define=SUPABASE_ANON_KEY=YOUR_KEY
```

---

## 📄 License
Distributed under the MIT License.

## ✉️ Contact
Sarah Elbahloul - [sa.albahloul@gmail.com](mailto:sa.albahloul@gmail.com)
Project Link: [https://github.com/sarah-elbahloul/poppy](https://github.com/sarah-elbahloul/poppy)
