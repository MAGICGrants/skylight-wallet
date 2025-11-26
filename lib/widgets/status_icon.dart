import 'package:flutter/material.dart';

enum StatusIconStatus { loading, complete, fail }

class StatusIcon extends StatelessWidget {
  const StatusIcon({super.key, required this.child, required this.status});

  final Widget child;
  final StatusIconStatus status;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDarkTheme = brightness == Brightness.dark;

    return SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        fit: StackFit.loose,
        children: [
          child,
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
                  ? Icon(
                      Icons.check_circle_rounded,
                      size: 12,
                      color: Colors.teal,
                    )
                  : status == StatusIconStatus.fail
                  ? Icon(Icons.cancel, size: 12, color: Colors.red)
                  : CircularProgressIndicator(
                      strokeWidth: 2,
                      padding: EdgeInsets.all(2),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
