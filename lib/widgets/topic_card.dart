import 'package:flutter/material.dart';
import '../utils/responsive.dart';

class TopicCard extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const TopicCard({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final w = width ?? Responsive.cardWidth(context);
    final h = height ?? Responsive.cardHeight(context);
    final iconSize = Responsive.topicIconSize(context);
    final fontSize = Responsive.topicLabelSize(context);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: const AssetImage('assets/images/frame.png'),
              fit: BoxFit.fill,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('FRAME LOAD ERROR: $error');
                return const ColoredBox(color: Colors.red);
              },
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: icon,
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
