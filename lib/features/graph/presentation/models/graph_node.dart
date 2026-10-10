import 'package:flutter/material.dart';

import '../../../../shared/tokens/app_colors.dart';
import '../../data/graph_models.dart';

export '../../data/graph_models.dart' show GraphNodeType;

/// Node type drives node color per `architecture-and-spec.md` §5 and web's
/// `nodeBaseColor`: document = violet, image = teal, sealed = amber. Amber is
/// reserved exclusively for sealed nodes — see `CLAUDE.md` naming/color
/// discipline.
extension GraphNodeTypeX on GraphNodeType {
  Color get color {
    switch (this) {
      case GraphNodeType.document:
        return AppColors.accentPrimary;
      case GraphNodeType.image:
        return AppColors.accentSecondary;
      case GraphNodeType.sealed:
        return AppColors.accentLocked;
    }
  }

  String get label {
    switch (this) {
      case GraphNodeType.document:
        return 'document';
      case GraphNodeType.image:
        return 'image';
      case GraphNodeType.sealed:
        return 'sealed';
    }
  }

  /// Visual dot radius in logical pixels (document 10, image 9, sealed 7).
  double get baseRadius {
    switch (this) {
      case GraphNodeType.document:
        return 10;
      case GraphNodeType.image:
        return 9;
      case GraphNodeType.sealed:
        return 7;
    }
  }
}
