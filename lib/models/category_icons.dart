import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Mirror of `categoryIconFor()` in taskpoint/lib/models/job.dart.
///
/// Duplicated rather than shared because the two apps are separate Flutter
/// packages with no common dependency — the same reason
/// `lib/theme/app_theme.dart` is a copy. Keep this in step with the mobile
/// version so the icon an admin picks in the Categories module is the icon
/// seekers actually see on their home grid.
IconData categoryIconFor(String categoryNameOrKey) {
  switch (categoryNameOrKey.toLowerCase()) {
    case 'plumber':
    case 'plumbing':
      return Symbols.plumbing_rounded;
    case 'electrician':
    case 'electrical':
      return Symbols.bolt_rounded;
    case 'carpenter':
    case 'carpentry':
      return Symbols.carpenter_rounded;
    case 'painter':
    case 'painting':
      return Symbols.palette_rounded;
    case 'mason':
      return Symbols.layers_rounded;
    case 'cleaner':
    case 'cleaning':
      return Symbols.mop_rounded;
    case 'ac repair':
      return Symbols.ac_unit_rounded;
    case 'appliance repair':
      return Symbols.build_circle_rounded;
    case 'gardener':
      return Symbols.yard_rounded;
    case 'mover/shifting':
    case 'mover':
      return Symbols.local_shipping_rounded;
    case 'pest control':
      return Symbols.pest_control_rounded;
    case 'car wash':
      return Symbols.local_car_wash_rounded;
    default:
      return Symbols.handyman_rounded;
  }
}
