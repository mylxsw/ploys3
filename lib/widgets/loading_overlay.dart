import 'package:flutter/material.dart';

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final Widget? loadingWidget;
  final Color? barrierColor;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.loadingWidget,
    this.barrierColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: Container(
              color:
                  barrierColor ??
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
              child: Center(
                child: loadingWidget ?? const CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }
}
