# UI/UX principles for Body Composition Flutter

Source of inspiration: [ceorkm/mobile-app-ui-design](https://github.com/ceorkm/mobile-app-ui-design) (MIT-licensed guidance). This document adapts its principles to this Flutter app rather than copying implementation code.

## Product goal and tone
This is a health/wellness companion: help a person connect a Xiaomi scale, take a reading, understand trends, and leave reassured and informed. Prioritize trust, accessibility, clarity, and calm feedback over futuristic decoration.

## Required design review checklist
- **Purpose first:** identify the primary task, core content, and primary CTA for every screen.
- **Hierarchy:** weight and progress values lead; explanatory labels are secondary. Keep a small, consistent typography scale (up to four roles, two typical weights), and use tabular numerals for measurements.
- **Color balance:** approximate 60% neutral foundation / 30% supporting surfaces and text / 10% accent. Do not let violet/blue gradients compete with measurements or warnings.
- **Spacing:** 4/8-point grid, baseline paddings of 16/24/32; related elements grouped, separate sections clearly distinguished.
- **Reachability:** primary 'Measure' action must be easily reached in the lower thumb zone; avoid placing a primary action behind a toolbar or extra tap.
- **Platform fidelity:** iOS 26+ native Liquid Glass navigation and system controls via `adaptive_platform_ui` where supported; older iOS Cupertino, Android Material 3. Do not label blurred Flutter cards as native Liquid Glass.
- **Contrast and legibility:** opaque or sufficiently contrast-safe dialogs, text fields and overlays. Check dynamic text size, dark system appearance, and WCAG-style contrast. Never render white text on light/translucent surfaces.
- **Accessibility:** touch targets at least 44x44 logical pixels; voice labels, correct focus order, reduced-motion support, and color-independent state indications.
- **Complete states:** onboarding, no measurements, discovering scale, connecting, reading, success, denied Bluetooth permission, connection lost, invalid impedance, storage errors.
- **Motion:** deliberate, short transitions that explain state changes. For the 'peak moment' of a successful reading, acknowledge completion without medical judgments or excessive celebration.
- **Health-specific trust:** label impedance-derived values as estimates; show timestamp and units; do not imply a weight or body-fat change is inherently good or bad.
- **Performance:** avoid large repeated backdrop filters, particularly behind scrolling charts; measure real-device frame times.
- **Responsive layout:** handle narrow phones, large phones, landscape, keyboard and text scaling; avoid clipped dialog content.
- **Review loop:** visually inspect iOS and Android screens in loading, populated, empty, denied, and error states before treating UI as complete.

## Priority applied to current app
1. Fix profile, manual reading, and permission dialogs: Cupertino presentation on iOS and contrast-safe Material on Android.
2. Unify semantic color and typography tokens across chart, measurement view and dialogs.
3. Keep native navigation; make the measurement CTA reachable, explicit and consistent.
4. Add thoughtful measurement success and Bluetooth recovery states.
5. Check physical-device accessibility, responsiveness and performance.

Reference: https://github.com/ceorkm/mobile-app-ui-design
