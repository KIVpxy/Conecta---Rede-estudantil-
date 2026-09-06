import 'package:flutter/material.dart';

import 'tokens.dart';

/// Página placeholder usada no scaffold inicial.
/// Será substituída pela implementação real de cada feature.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(subtitle!,
                  style: const TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
