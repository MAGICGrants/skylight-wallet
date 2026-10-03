import 'package:skylight_wallet/util/platform.dart';

/// How many steps the desktop onboarding numbers. The password is the last one,
/// and only a desktop OS sets it: the iOS build on a Mac shows this layout but
/// keeps the mobile wallet password, so its onboarding ends at the seed.
int get desktopOnboardingSteps => isDesktopOS ? 6 : 5;
