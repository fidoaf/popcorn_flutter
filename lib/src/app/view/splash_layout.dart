import 'package:flutter/widgets.dart';

class SplashLayout extends StatelessWidget {
  const SplashLayout({super.key, required this.assetPath, required this.titleWidget, required this.subtitleWidget});

  final String assetPath;
  final Widget titleWidget;
  final Widget subtitleWidget;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 320,
            height: 320,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                assetPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(child: Text('Unable to load splash animation'));
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          titleWidget,
          const SizedBox(height: 8),
          subtitleWidget,
        ],
      ),
    );
  }
}
