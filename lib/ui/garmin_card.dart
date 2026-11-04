import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import '../models/garmin_account.dart';
import 'body_tokens.dart';
import 'widgets/body_surface.dart';

/// Garmin Connect connection status and sync controls, shown on the profile
/// tab. All network work is owned by the dashboard; this widget is purely
/// presentational.
class GarminCard extends StatelessWidget {
  const GarminCard({
    super.key,
    required this.account,
    required this.loading,
    required this.busy,
    required this.pendingReadings,
    this.syncCompleted,
    this.syncTotal,
    this.onConnect,
    this.onSync,
    this.onDisconnect,
  });

  final GarminAccount? account;
  final bool loading;
  final bool busy;
  final int pendingReadings;
  final int? syncCompleted;
  final int? syncTotal;
  final VoidCallback? onConnect;
  final VoidCallback? onSync;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    final colors = BodyColors.of(context);
    final connected = account != null;

    return Semantics(
      container: true,
      liveRegion: busy,
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.watch_outlined, color: colors.accentText, size: 24),
                const SizedBox(width: BodySpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Garmin Connect',
                        style: BodyType.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: BodySpace.xs),
                      Text(
                        connected
                            ? 'Weight and body-composition readings can be sent '
                                  'to your Garmin account.'
                            : 'Send weight and body-composition readings to '
                                  'Garmin Connect.',
                        style: BodyType.caption.copyWith(
                          color: colors.secondaryInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: BodySpace.lg),
            if (loading)
              Text(
                'Checking Garmin connection…',
                style: BodyType.caption.copyWith(color: colors.secondaryInk),
              )
            else if (!connected) ...[
              SizedBox(
                width: double.infinity,
                child: AdaptiveButton(
                  onPressed: onConnect ?? () {},
                  enabled: !busy && onConnect != null,
                  label: 'Connect Garmin',
                  style: AdaptiveButtonStyle.filled,
                  color: colors.accent,
                  textColor: colors.onAccent,
                  size: AdaptiveButtonSize.large,
                  minSize: const Size(0, 48),
                ),
              ),
            ] else ...[
              _ConnectedAccount(email: account!.email),
              if (busy) ...[
                const SizedBox(height: BodySpace.sm),
                _SyncProgress(completed: syncCompleted, total: syncTotal),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: BodySpace.xs),
                  child: Text(
                    pendingReadings == 0
                        ? 'All readings are synced.'
                        : '$pendingReadings '
                              '${pendingReadings == 1 ? 'reading is' : 'readings are'} '
                              'ready to send.',
                    style: BodyType.caption.copyWith(
                      color: colors.secondaryInk,
                    ),
                  ),
                ),
              const SizedBox(height: BodySpace.lg),
              SizedBox(
                width: double.infinity,
                child: AdaptiveButton(
                  onPressed: onSync ?? () {},
                  enabled: !busy && pendingReadings > 0 && onSync != null,
                  label: busy
                      ? 'Syncing…'
                      : pendingReadings == 0
                      ? 'Sync readings'
                      : 'Sync $pendingReadings '
                            '${pendingReadings == 1 ? 'reading' : 'readings'}',
                  style: AdaptiveButtonStyle.filled,
                  color: colors.accent,
                  textColor: colors.onAccent,
                  size: AdaptiveButtonSize.large,
                  minSize: const Size(0, 48),
                ),
              ),
              const SizedBox(height: BodySpace.xs),
              SizedBox(
                width: double.infinity,
                child: AdaptiveButton(
                  onPressed: onDisconnect ?? () {},
                  enabled: !busy && onDisconnect != null,
                  label: 'Disconnect',
                  style: AdaptiveButtonStyle.plain,
                  size: AdaptiveButtonSize.large,
                  minSize: const Size(0, BodySpace.minimumTapTarget),
                  // Native iOS 26 title buttons with a zero min width render
                  // without a tappable area.
                  useNative: false,
                ),
              ),
            ],
            const SizedBox(height: BodySpace.sm),
            Text(
              "Uses Garmin Connect's mobile sign-in. Readings are sent only "
              'when you tap Sync, and your Garmin session is stored securely '
              'on this device.',
              style: BodyType.caption.copyWith(color: colors.secondaryInk),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectedAccount extends StatelessWidget {
  const _ConnectedAccount({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final colors = BodyColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BodySpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.mail_outline_rounded,
            color: colors.secondaryInk,
            size: 20,
          ),
          const SizedBox(width: BodySpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connected',
                  style: BodyType.body.copyWith(color: colors.secondaryInk),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: BodyType.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
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

class _SyncProgress extends StatelessWidget {
  const _SyncProgress({required this.completed, required this.total});

  final int? completed;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final colors = BodyColors.of(context);
    final totalValue = total;
    final completedValue = completed;
    final progress = totalValue != null && totalValue > 0
        ? ((completedValue ?? 0) / totalValue).clamp(0.0, 1.0)
        : null;
    final label = totalValue == null || totalValue <= 0
        ? 'Signing in to Garmin…'
        : 'Uploading ${(completedValue ?? 0).clamp(0, totalValue)} '
              'of $totalValue…';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: BodyType.caption.copyWith(color: colors.secondaryInk),
        ),
        const SizedBox(height: BodySpace.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            backgroundColor: colors.border,
            color: colors.accent,
          ),
        ),
      ],
    );
  }
}
