import 'package:flutter/material.dart';

const EdgeInsets kScreenPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
const double kSectionSpacing = 20;
const double kGridSpacing = 12;

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.childAspectRatio = 1.6,
  });

  final List<Widget> children;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width > 600;

    return GridView.count(
      crossAxisCount: isTablet ? 3 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: kGridSpacing,
      mainAxisSpacing: kGridSpacing,
      childAspectRatio: childAspectRatio,
      children: children,
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class InsightBanner extends StatelessWidget {
  const InsightBanner({
    super.key,
    required this.message,
    required this.textColor,
    required this.backgroundColor,
    this.icon,
  });

  final String message;
  final Color textColor;
  final Color backgroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: textColor, size: 18),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
