# 🌺 Poppy

> **A privacy-first cross-platform journaling application built with Flutter.**

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)
![Supabase](https://img.shields.io/badge/Backend-Supabase-3ECF8E?logo=supabase)
![SQLite](https://img.shields.io/badge/Database-SQLite-003B57?logo=sqlite)
![Provider](https://img.shields.io/badge/State-Provider-orange)
![License](https://img.shields.io/badge/License-MIT-green)

Poppy is a modern cross-platform journaling application that prioritizes privacy, security, and personalization. Built with Flutter, it combines client-side encryption, offline-first data management, cloud synchronization, and a highly customizable interface while following a modular feature-based architecture.

The project was developed as a software engineering portfolio project to demonstrate modern Flutter development practices, scalable application architecture, secure mobile development, and backend integration using Supabase.

---

# 📱 Screenshots

> These placeholders are gonna be replaced with actual screenshots.

| Login | Home | Journal |
|------|------|------|
| ![](screenshots/login.png) | ![](screenshots/home.png) | ![](screenshots/journal.png) |

| Editor | Appearance | Security |
|------|------|------|
| ![](screenshots/editor.png) | ![](screenshots/settings.png) | ![](screenshots/security.png) |

---

# 🎥 Demo

A short demonstration GIF will be added here.

```md
![Demo](screenshots/demo.gif)
```

Recommended demo sequence:

- Login
- Create a journal entry
- Attach an image
- Change theme colors
- Work offline
- Reconnect and synchronize

---

# ✨ Features

## 🔐 Privacy & Security

- Secure authentication with Supabase
- Client-side encryption using AES-256-GCM
- PBKDF2-based encryption key derivation
- Secure local credential storage
- Optional PIN protection
- Privacy-focused journal storage

---

## 📝 Journaling

- Create journal entries
- Edit journal entries
- Delete journal entries
- Attach images to entries
- Color-tag journal entries
- Offline editing and storage

---

## ☁️ Data Synchronization

- Offline-first architecture
- Local SQLite persistence
- Automatic synchronization with Supabase
- Connectivity-aware syncing
- Secure cloud media storage

---

## 🎨 Personalization

- Dynamic application colors
- Custom typography
- Google Fonts integration
- Material 3 design
- Light & Dark themes
- User-configurable appearance

---

## 🔔 Productivity

- Local reminders & notifications
- Import journal data
- Export journal data
- Responsive cross-platform interface

---

# 🛠 Technology Stack

### Framework

- Flutter
- Dart
- Material 3

### Backend & Cloud

- Supabase
    - Authentication
    - PostgreSQL Database
    - Storage

### State Management

- Provider

### Local Storage & Offline Support

- SQLite (`sqflite`)
- `flutter_secure_storage`
- `connectivity_plus`

### Security & Cryptography

- AES-256-GCM (`cryptography`)
- PBKDF2 Key Derivation
- SHA Hashing (`crypto`)

### Media & File Management

- `image_picker`
- `cached_network_image`
- `flutter_image_compress`
- `file_picker`
- `share_plus`

### Notifications

- `flutter_local_notifications`
- `timezone`
- `flutter_timezone`

### User Interface

- Material 3
- `google_fonts`
- `flutter_svg`
- `iconsax`
- `modal_bottom_sheet`
- `dropdown_button2`
- `shimmer`
- `gap`
- `flutter_bidi_text`

### Utilities

- `intl`
- `uuid`
- `path`
- `path_provider`
- `package_info_plus`
- 
---

# 🏗 Architecture

Poppy follows a **feature-based modular architecture** that separates the application into independent feature modules while centralizing shared functionality within the `core` package.

This architecture improves:

- Maintainability
- Scalability
- Separation of concerns
- Feature isolation
- Code reuse

```text
lib/
│
├── core/
│   ├── constants/
│   ├── services/
│   ├── style/
│   ├── utils/
│   └── widgets/
│
├── features/
│   ├── auth/
│   ├── journal/
│   └── settings/
│       ├── data/
│       │   ├── models/
│       │   └── services/
│       └── presentation/
│           ├── providers/
│           ├── screens/
│           └── widgets/
│
├── app.dart
└── main.dart
```

> **Note:** Each feature follows the same internal organization, separating data management from presentation logic to promote consistency and simplify future development.

| Directory | Purpose |
|-----------|---------|
| **core** | Shared widgets, services, styling, constants, and utilities used throughout the application. |
| **features** | Self-contained feature modules (Authentication, Journal, Settings), each following the same `data` and `presentation` structure. |
| **data** | Feature-specific models and services responsible for data access, persistence, and business operations. |
| **presentation** | UI components including screens, widgets, and state management (`Provider`) for each feature. |

---
# ⚙️ Engineering Highlights

Poppy was designed as a software engineering project rather than simply a mobile application. Throughout its development, emphasis was placed on building a maintainable, secure, and scalable codebase.

### Key Engineering Decisions

- Modular feature-oriented architecture
- Offline-first synchronization strategy
- Local-first persistence with SQLite
- Client-side encryption before cloud synchronization
- Secure authentication with Supabase
- Configurable application appearance
- Separation of concerns
- Reusable UI components
- Responsive Material 3 design

---

# 🔒 Security

Privacy is one of the primary goals of this project.

Journal content is encrypted on the client before being synchronized with the backend. Encryption keys are derived locally using PBKDF2, and sensitive credentials are stored using secure platform storage.

Security measures include:

- Client-side encryption
- AES-256-GCM authenticated encryption
- PBKDF2 key derivation
- Secure credential storage
- PIN protection
- Secure authentication
- Encrypted cloud synchronization

---

# 🚀 Getting Started

## Prerequisites

Before running the project, ensure you have:

- Flutter SDK (latest stable)
- Dart SDK
- Android Studio or Visual Studio Code
- A Supabase project

---

## Clone the repository

```bash
git clone https://github.com/sarah-elbahloul/poppy.git

cd poppy
```

---

## Install dependencies

```bash
flutter pub get
```

---

## Configure Supabase

Create a Supabase project and configure the application using your project credentials.

You can supply them using Dart defines.

```text
SUPABASE_URL=YOUR_SUPABASE_URL
SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

---

## Run the application

```bash
flutter run \
--dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
--dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

---

## Build Release APK

```bash
flutter build apk --release
```

---

## Build App Bundle

```bash
flutter build appbundle
```

---

## Build for iOS

```bash
flutter build ios
```

---

# 💾 Offline-First Design

Poppy is designed around an offline-first workflow.

Journal entries are stored locally using SQLite, allowing users to continue writing without an internet connection. When connectivity becomes available, the application synchronizes local changes with Supabase.

This approach provides:

- Faster application startup
- Reduced dependency on network availability
- Improved responsiveness
- Better user experience during connectivity interruptions

---

# 🎨 Design Philosophy

The application emphasizes personalization while maintaining consistency.

Users can customize various aspects of the interface, including colors and typography, without affecting the underlying functionality.

The design system is built around Material 3 principles and reusable UI components to ensure a consistent user experience throughout the application.

---

# 🧩 State Management

Poppy uses **Provider** for application state management.

Provider was selected because it offers:

- Lightweight architecture
- Reactive UI updates
- Easy dependency injection
- Clear separation between UI and business logic
- Excellent integration with Flutter

---

# ☁️ Backend

Supabase provides the backend infrastructure for the application.

Services include:

- User authentication
- Cloud database
- Media storage
- Data synchronization

The backend integrates with local persistence to support the offline-first workflow while keeping user data synchronized across sessions.

---
# 🎯 Project Goals

Poppy was developed as an independent software engineering project to explore modern Flutter application development beyond traditional CRUD applications.

The project was designed to demonstrate and integrate multiple software engineering concepts within a single production-oriented application, including:

- Secure mobile application development
- Client-side encryption
- Offline-first architecture
- Cloud backend integration with Supabase
- Feature-based modular architecture
- State management with Provider
- Local data persistence using SQLite
- Responsive Material 3 user interface
- User interface customization
- Scalable and maintainable application design

Rather than focusing solely on journaling functionality, Poppy emphasizes the engineering practices and architectural decisions involved in building a secure, scalable, and maintainable cross-platform mobile application.

---

# 🎯 Learning Outcomes

Developing Poppy provided practical experience with:

- Designing scalable Flutter applications
- Structuring feature-based projects
- Implementing secure authentication
- Working with Supabase services
- Designing offline-first synchronization workflows
- Managing local and remote data
- Building reusable UI components
- Implementing configurable application themes
- Applying secure storage and encryption techniques
- Writing maintainable, modular code

---

# 📈 Future Improvements

Potential future enhancements include:

### Quality

- Unit testing
- Widget testing
- Integration testing
- Improved error reporting

### Infrastructure

- Continuous Integration (CI)
- Continuous Deployment (CD)
- Automated code quality checks

### Features

- Advanced filtering
- Calendar view
- Rich text editing
- Improved reminder scheduling
- Enhanced search capabilities

### Platforms

- Flutter Web support
- Desktop support (Windows, macOS, Linux)

---

# 🤝 Contributing

Contributions, suggestions, and feedback are welcome.

If you'd like to contribute:

1. Fork the repository.
2. Create a feature branch.

```bash
git checkout -b feature/my-feature
```

3. Commit your changes.

```bash
git commit -m "Add my feature"
```

4. Push the branch.

```bash
git push origin feature/my-feature
```

5. Open a Pull Request.

---

# 📋 Roadmap

- [x] Secure authentication
- [x] Client-side encryption
- [x] Offline-first architecture
- [x] SQLite local persistence
- [x] Supabase synchronization
- [x] Image attachments
- [x] Theme customization
- [x] Font customization
- [x] Import & export
- [x] Local notifications
- [ ] Comprehensive automated testing
- [ ] Continuous Integration
- [ ] Desktop support
- [ ] Flutter Web support

---

# 🏛 Software Engineering Principles

The project emphasizes several software engineering practices throughout the codebase.

### Modularity

Features are organized into self-contained modules, reducing coupling and improving maintainability.

### Separation of Concerns

Presentation, state management, services, and models are separated to keep responsibilities clear.

### Reusability

Shared widgets, utilities, and styling are centralized within the `core` package to avoid duplication.

### Maintainability

The architecture allows new features to be introduced with minimal impact on existing modules.

### Scalability

The feature-based organization is intended to support future growth while keeping the project easy to navigate.

---

# 📚 Resources

## Flutter

https://flutter.dev

## Dart

https://dart.dev

## Supabase

https://supabase.com

## Provider

https://pub.dev/packages/provider

## SQLite

https://sqlite.org

---

# 📄 License

This project is licensed under the MIT License.

See the [LICENSE](LICENSE) file for additional details.

---

# 👩‍💻 Author

**Sarah Elbahloul**

Computer Science Graduate (2025)

Poppy was developed as a personal software engineering project to demonstrate modern Flutter development, application architecture, secure mobile engineering, offline-first data management, and backend integration with Supabase.

---

## ⭐ If you found this project interesting, consider giving it a star!

Feedback and suggestions are always appreciated.