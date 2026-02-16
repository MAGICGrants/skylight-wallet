import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum StatusIconStatus { loading, complete, fail }

class StatusIcon extends StatelessWidget {
  const StatusIcon({super.key, required this.status, required this.torIsEnabled});

  final StatusIconStatus status;
  final bool torIsEnabled;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDarkTheme = brightness == Brightness.dark;

    if (!torIsEnabled) {
      return status == StatusIconStatus.complete
          ? Icon(Icons.check_circle_rounded, size: 26, color: Colors.teal)
          : status == StatusIconStatus.fail
          ? Icon(Icons.cancel, size: 26, color: Colors.red)
          : SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(padding: EdgeInsets.all(3), strokeWidth: 2),
            );
    }

    return Stack(
      fit: StackFit.loose,
      children: [
        if (torIsEnabled) SvgPicture.asset('assets/icons/tor.svg', width: 22, height: 22),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isDarkTheme ? Colors.grey[900] : Colors.white,
              shape: BoxShape.circle,
            ),
            child: status == StatusIconStatus.complete
                ? Icon(Icons.check_circle_rounded, size: 12, color: Colors.teal)
                : status == StatusIconStatus.fail
                ? Icon(Icons.cancel, size: 12, color: Colors.red)
                : CircularProgressIndicator(strokeWidth: 2, padding: EdgeInsets.all(2)),
          ),
        ),
      ],
    );
  }
}
