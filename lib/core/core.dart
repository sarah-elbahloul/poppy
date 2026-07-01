/// Poppy — Core Barrel Export
///
/// Single entry point for the app's shared, cross-feature foundation:
/// routing constants, app/db/storage constants, generic error helpers,
/// the design system (`style/`), infrastructure services, and shared
/// "chrome" widgets (dialogs, snackbars, the logo).
///
/// Reuse note: `style/` is the most portable part of this barrel — see
/// `style/style.dart` for which files are generic vs. app-specific.
/// `services/` and `widgets/` are this app's shared infrastructure and UI
/// chrome; they're cross-feature within Poppy but not all framework-agnostic
/// (see the per-file notes in `services/sync_service.dart` and
/// `widgets/dialogs.dart`/`widgets/app_snackbar.dart`).
export 'app_routes.dart';
export 'constants.dart';
export 'error_messages.dart';
export 'style/style.dart';
export 'services/services.dart';
export 'widgets/widgets.dart';