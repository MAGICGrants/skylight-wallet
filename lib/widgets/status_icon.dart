import 'package:flutter/material.dart';

enum StatusIconStatus { loading, complete }

class StatusIcon extends StatelessWidget {
  final Widget child;
  final StatusIconStatus status;

  const StatusIcon({super.key, required this.child, required this.status});

  @override
  Widget build(BuildContext context) {
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
              // padding: EdgeInsetsGeometry.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: status == StatusIconStatus.loading
                  ? CircularProgressIndicator(strokeWidth: 2)
                  : Icon(
                      Icons.check_circle_rounded,
                      size: 12,
                      color: Colors.teal,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
