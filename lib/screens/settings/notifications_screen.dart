import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:poppy/core/core.dart';
import 'package:provider/provider.dart';
import 'package:poppy/providers/providers.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Notifications Screen
//  Location: lib/screens/settings/notifications_screen.dart
//
//  Manages writing reminder preferences. The actual scheduling
//  is handled by flutter_local_notifications (add to pubspec
//  when ready to implement — see TODO below).
//
//  TODO: to activate real notifications:
//    1. Add `flutter_local_notifications: ^17.0.0` to pubspec.yaml
//    2. Add Android permissions to AndroidManifest.xml:
//         <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
//         <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
//    3. Add iOS permissions to Info.plist (NSUserNotificationUsageDescription)
//    4. Implement NotificationService and replace the _save() stub below.
//
//  Until then: preferences are persisted to secure storage so
//  the UI is fully functional and ready for the integration.
// ─────────────────────────────────────────────────────────────

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _storage = const FlutterSecureStorage();

  bool      _enabled    = false;
  TimeOfDay _reminderAt = const TimeOfDay(hour: 21, minute: 0);
  bool      _loading    = true;

  static const _kEnabled    = 'poppy_notif_enabled';
  static const _kHour       = 'poppy_notif_hour';
  static const _kMinute     = 'poppy_notif_minute';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _storage.read(key: _kEnabled);
    final hour    = await _storage.read(key: _kHour);
    final minute  = await _storage.read(key: _kMinute);

    if (mounted) {
      setState(() {
        _enabled    = enabled == 'true';
        _reminderAt = TimeOfDay(
          hour:   int.tryParse(hour   ?? '21') ?? 21,
          minute: int.tryParse(minute ?? '0')  ?? 0,
        );
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    await _storage.write(key: _kEnabled,    value: _enabled.toString());
    await _storage.write(key: _kHour,       value: _reminderAt.hour.toString());
    await _storage.write(key: _kMinute,     value: _reminderAt.minute.toString());

    // TODO: schedule / cancel local notification here using
    // flutter_local_notifications. Example:
    //   if (_enabled) {
    //     await NotificationService.scheduleDailyReminder(_reminderAt);
    //   } else {
    //     await NotificationService.cancelReminders();
    //   }
  }

  Future<void> _onToggle(bool value) async {
    setState(() => _enabled = value);
    await _save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value
            ? 'Reminder set for ${_reminderAt.format(context)}.'
            : 'Reminders turned off.'),
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderAt,
      helpText:    'Choose reminder time',
    );
    if (picked == null || !mounted) return;
    setState(() => _reminderAt = picked);
    await _save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reminder updated to ${picked.format(context)}.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.back,
              size: AppIconSize.xs, color: t.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Notifications',
            style: AppTextStyles.titleLarge(t.textPrimary, fp)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [

          // ── Daily reminder toggle ───────────────
          Container(
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius:
              BorderRadius.circular(AppRadius.md),
              border: Border.all(
                  color: t.border,
                  width: AppStroke.hairline),
            ),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical:   AppSpacing.xs,
              ),
              title: Text('Daily writing reminder',
                  style:
                  AppTextStyles.titleSmallSans(t.textPrimary,fp)),
              subtitle: Text(
                'A gentle nudge to write in your diary.',
                style: AppTextStyles.labelLargeSans(
                    t.textTertiary,fp),
              ),
              value:       _enabled,
              activeColor: t.accent,
              onChanged:   _onToggle,
            ),
          ),

          // ── Time picker — only when enabled ────
          if (_enabled) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius:
                BorderRadius.circular(AppRadius.md),
                border: Border.all(
                    color: t.border,
                    width: AppStroke.hairline),
              ),
              child: InkWell(
                onTap: _pickTime,
                borderRadius:
                BorderRadius.circular(AppRadius.md),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical:   AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Icon(AppIcons.time,
                          size:  AppComponentSize.settingsIconCol,
                          color: t.textTertiary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text('Reminder time',
                                style:
                                AppTextStyles.titleSmallSans(
                                    t.textPrimary,fp)),
                            const SizedBox(height: 2),
                            Text(
                              _reminderAt.format(context),
                              style:
                              AppTextStyles.labelLargeSans(
                                  t.accent,fp),
                            ),
                          ],
                        ),
                      ),
                      Icon(AppIcons.chevronRight,
                          size:  AppIconSize.xs,
                          color: t.textTertiary),
                    ],
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),

          // ── Info note ───────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: t.accentLight,
              borderRadius:
              BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: t.accent.withOpacity(0.2),
                width: AppStroke.hairline,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(AppIcons.info,
                    size: AppIconSize.xs, color: t.accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Your device must allow notifications from Poppy. '
                        'You can manage this in your system settings.',
                    style: AppTextStyles.labelLargeSans(
                        t.accent,fp),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}