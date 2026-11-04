import 'dart:math' as math;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import '../body_tokens.dart';

/// Rounded, opaque surface used for cards and panels.
///
/// These are plain Flutter surfaces, not native Liquid Glass.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(BodySpace.card),
    this.radius = BodyRadius.card,
    this.color,
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final colors = BodyColors.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? colors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: colors.border) : null,
      ),
      child: child,
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = BodyColors.of(context);
    return Text(
      text.toUpperCase(),
      style: BodyType.overline.copyWith(color: colors.secondaryInk),
    );
  }
}

enum NoticeTone { info, success, danger }

/// Feedback shown after an action, always with icon + text so state is not
/// conveyed by color alone.
class DashboardNotice {
  const DashboardNotice({
    required this.tone,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final NoticeTone tone;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
}

class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key, required this.notice});

  final DashboardNotice notice;

  @override
  Widget build(BuildContext context) {
    final colors = BodyColors.of(context);
    final accent = switch (notice.tone) {
      NoticeTone.info => colors.accentText,
      NoticeTone.success => colors.success,
      NoticeTone.danger => colors.danger,
    };
    final icon = switch (notice.tone) {
      NoticeTone.info => Icons.info_outline_rounded,
      NoticeTone.success => Icons.check_circle_outline_rounded,
      NoticeTone.danger => Icons.error_outline_rounded,
    };
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(BodySpace.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(BodyRadius.compact),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 24),
            const SizedBox(width: BodySpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.title,
                    style: BodyType.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: BodySpace.xs),
                  Text(
                    notice.message,
                    style: BodyType.caption.copyWith(color: colors.secondaryInk),
                  ),
                  if (notice.actionLabel != null && notice.onAction != null) ...[
                    const SizedBox(height: BodySpace.sm),
                    AdaptiveButton(
                      onPressed: notice.onAction,
                      label: notice.actionLabel!,
                      style: AdaptiveButtonStyle.plain,
                      size: AdaptiveButtonSize.large,
                      minSize: const Size(0, BodySpace.minimumTapTarget),
                      // Native iOS 26 title buttons with a zero min width
                      // render without a tappable area.
                      useNative: false,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animates notice changes, but only when motion is enabled.
class NoticeSlot extends StatelessWidget {
  const NoticeSlot({super.key, required this.notice});

  final DashboardNotice? notice;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final current = notice;
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : BodyMotion.fast,
      child: current == null
          ? const SizedBox.shrink()
          : Padding(
              key: ValueKey(current),
              padding: const EdgeInsets.only(top: BodySpace.lg),
              child: NoticeCard(notice: current),
            ),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    this.caption,
    this.badge,
    this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final String? caption;
  final String? badge;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = BodyColors.of(context);
    final content = SurfaceCard(
      radius: BodyRadius.compact,
      padding: const EdgeInsets.all(BodySpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const Spacer(),
              if (badge != null)
                Text(
                  badge!.toUpperCase(),
                  style: BodyType.overline.copyWith(
                    fontSize: 10,
                    color: colors.secondaryInk,
                  ),
                ),
            ],
          ),
          const SizedBox(height: BodySpace.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: BodyType.title.copyWith(
                fontSize: 22,
                color: colors.ink,
              ),
            ),
          ),
          const SizedBox(height: BodySpace.xs),
          Text(label, style: BodyType.caption.copyWith(color: colors.secondaryInk)),
          if (caption != null) ...[
            const SizedBox(height: BodySpace.xs),
            Text(
              caption!,
              style: BodyType.caption.copyWith(
                fontSize: 11,
                color: colors.secondaryInk,
              ),
            ),
          ],
        ],
      ),
    );
    return Semantics(
      container: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: content,
    );
  }
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = BodyColors.of(context);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.accentText, size: 28),
          const SizedBox(height: BodySpace.md),
          Text(
            title,
            style: BodyType.title.copyWith(fontSize: 17, color: colors.ink),
          ),
          const SizedBox(height: BodySpace.xs),
          Text(
            message,
            style: BodyType.caption.copyWith(color: colors.secondaryInk),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: BodySpace.md),
            AdaptiveButton(
              onPressed: onAction,
              label: actionLabel!,
              style: AdaptiveButtonStyle.plain,
              size: AdaptiveButtonSize.large,
              minSize: const Size(0, BodySpace.minimumTapTarget),
              // Native iOS 26 title buttons with a zero min width render
              // without a tappable area.
              useNative: false,
            ),
          ],
        ],
      ),
    );
  }
}

class LoadingPanel extends StatelessWidget {
  const LoadingPanel({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = BodyColors.of(context);
    return SurfaceCard(
      child: Row(
        children: [
          Icon(Icons.hourglass_empty_rounded, color: colors.secondaryInk),
          const SizedBox(width: BodySpace.md),
          Expanded(
            child: Text(
              message,
              style: BodyType.caption.copyWith(color: colors.secondaryInk),
            ),
          ),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = BodyColors.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final labelWidget = Text(
      label,
      style: BodyType.body.copyWith(color: colors.secondaryInk),
    );
    final valueWidget = Text(
      value,
      style: BodyType.body.copyWith(
        fontWeight: FontWeight.w700,
        color: colors.ink,
      ),
    );

    if (scale > 1.3) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: BodySpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: colors.secondaryInk, size: 20),
                  const SizedBox(width: BodySpace.md),
                ],
                Flexible(child: labelWidget),
              ],
            ),
            const SizedBox(height: 2),
            Padding(
              padding: EdgeInsets.only(left: icon == null ? 0 : 32),
              child: valueWidget,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BodySpace.sm),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: colors.secondaryInk, size: 20),
            const SizedBox(width: BodySpace.md),
          ],
          Expanded(child: labelWidget),
          valueWidget,
        ],
      ),
    );
  }
}

/// Scrollable tab content with a readable maximum width on tablets and
/// landscape, plus clearance for the native tab bar.
class BodyListView extends StatelessWidget {
  const BodyListView({
    super.key,
    required this.storageKey,
    required this.children,
    this.top = BodySpace.lg,
    this.bottom = 120,
  });

  final PageStorageKey<String> storageKey;
  final List<Widget> children;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = math.max(
          BodySpace.screen,
          (constraints.maxWidth - BodySpace.maxContentWidth) / 2,
        );
        return ListView(
          key: storageKey,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom),
          children: children,
        );
      },
    );
  }
}
