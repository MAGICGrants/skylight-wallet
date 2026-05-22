import 'package:flutter/material.dart';

enum ConnectionIndicatorState { ok, loading, error }

/// Compact connection status shown next to a coin title (wallet home rows)
/// or in coin home header: invisible when OK, spinner when connecting, red
/// warning (same logical size as the fiat API triangle) when problematic.
class ConnectionStatusIndicator extends StatelessWidget {
  /// Matches [Icons.warning_rounded] in total balance fiat error indicator.
  static const double indicatorSize = 18;

  const ConnectionStatusIndicator({
    super.key,
    required this.state,
    required this.tooltipMessage,
  });

  final ConnectionIndicatorState state;
  final String tooltipMessage;

  @override
  Widget build(BuildContext context) {
    if (state == ConnectionIndicatorState.ok) {
      return SizedBox.shrink();
    }

    final Widget indicator = state == ConnectionIndicatorState.loading
        ? SizedBox(
            width: indicatorSize,
            height: indicatorSize,
            child: Padding(
              padding: EdgeInsets.all(2),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : Icon(Icons.warning_rounded, size: indicatorSize, color: Colors.red);

    return Tooltip(
      message: tooltipMessage,
      child: indicator,
    );
  }
}
