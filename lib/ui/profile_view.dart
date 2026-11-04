import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import '../models/garmin_account.dart';
import '../models/user_profile.dart';
import 'body_format.dart';
import 'body_tokens.dart';
import 'garmin_card.dart';
import 'widgets/body_surface.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({
    super.key,
    required this.profile,
    required this.loadingProfile,
    required this.notice,
    required this.onProfile,
    required this.bottomClearance,
    this.garminAccount,
    this.garminLoading = false,
    this.garminBusy = false,
    this.garminPendingReadings = 0,
    this.garminSyncCompleted,
    this.garminSyncTotal,
    this.onGarminConnect,
    this.onGarminSync,
    this.onGarminDisconnect,
  });

  final UserProfile? profile;
  final bool loadingProfile;
  final DashboardNotice? notice;
  final VoidCallback onProfile;
  final double bottomClearance;
  final GarminAccount? garminAccount;
  final bool garminLoading;
  final bool garminBusy;
  final int garminPendingReadings;
  final int? garminSyncCompleted;
  final int? garminSyncTotal;
  final VoidCallback? onGarminConnect;
  final VoidCallback? onGarminSync;
  final VoidCallback? onGarminDisconnect;

  @override
  Widget build(BuildContext context) {
    final colors = BodyColors.of(context);
    final current = profile;

    return BodyListView(
      storageKey: const PageStorageKey<String>('profile'),
      bottom: bottomClearance,
      children: [
        NoticeSlot(notice: notice),
        if (loadingProfile)
          const LoadingPanel(message: 'Loading your profile…')
        else if (current == null)
          EmptyPanel(
            icon: Icons.person_outline_rounded,
            title: 'Set up your profile',
            message:
                'Height, age and sex let the app estimate body composition from impedance. Weight readings work without a profile.',
            actionLabel: 'Set up profile',
            onAction: onProfile,
          )
        else
          SurfaceCard(
            child: Column(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: colors.accentText,
                    size: 38,
                  ),
                ),
                const SizedBox(height: BodySpace.md),
                Text(
                  'Your profile',
                  style: BodyType.title.copyWith(color: colors.ink),
                ),
                const SizedBox(height: BodySpace.xs),
                Text(
                  'Used to estimate body composition from your scale readings.',
                  textAlign: TextAlign.center,
                  style: BodyType.caption.copyWith(color: colors.secondaryInk),
                ),
                const SizedBox(height: BodySpace.lg),
                Divider(height: 1, color: colors.border),
                const SizedBox(height: BodySpace.sm),
                InfoRow(
                  icon: Icons.height_rounded,
                  label: 'Height',
                  value: formatHeight(current.heightCm),
                ),
                InfoRow(
                  icon: Icons.cake_outlined,
                  label: 'Age',
                  value: '${current.ageYears} years',
                ),
                InfoRow(
                  icon: Icons.wc_rounded,
                  label: 'Sex',
                  value: formatSex(current.sex),
                ),
                const SizedBox(height: BodySpace.lg),
                SizedBox(
                  width: double.infinity,
                  child: AdaptiveButton(
                    onPressed: onProfile,
                    label: 'Edit profile',
                    style: AdaptiveButtonStyle.filled,
                    color: colors.accent,
                    textColor: colors.onAccent,
                    size: AdaptiveButtonSize.large,
                    minSize: const Size(0, 48),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: BodySpace.lg),
        GarminCard(
          account: garminAccount,
          loading: garminLoading,
          busy: garminBusy,
          pendingReadings: garminPendingReadings,
          syncCompleted: garminSyncCompleted,
          syncTotal: garminSyncTotal,
          onConnect: onGarminConnect,
          onSync: onGarminSync,
          onDisconnect: onGarminDisconnect,
        ),
        const SizedBox(height: BodySpace.lg),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('About estimates'),
              const SizedBox(height: BodySpace.sm),
              Text(
                'Body composition values are estimates derived from impedance. '
                'They are not medical diagnoses.',
                style: BodyType.caption.copyWith(color: colors.secondaryInk),
              ),
              const SizedBox(height: BodySpace.sm),
              Text(
                'Profile data stays on this device.',
                style: BodyType.caption.copyWith(color: colors.secondaryInk),
              ),
            ],
          ),
        ),
        const SizedBox(height: BodySpace.lg),
        SurfaceCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.bluetooth_rounded, color: colors.accentText, size: 24),
              const SizedBox(width: BodySpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bluetooth',
                      style: BodyType.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: BodySpace.xs),
                    Text(
                      'Bluetooth access is requested only while you measure. '
                      'If access was denied, enable it in system settings and try again.',
                      style: BodyType.caption.copyWith(
                        color: colors.secondaryInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
