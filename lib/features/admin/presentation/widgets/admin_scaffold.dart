import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_navigation_bar.dart';
import '../../../../core/theme/app_theme.dart';

class AdminScaffold extends StatelessWidget {
  const AdminScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle = 'ADMINISTRACIÓN',
    this.isBusy = false,
    this.showNavigationBar = true,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final bool isBusy;
  final bool showNavigationBar;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !isBusy,
    child: Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: isBusy
              ? null
              : () => context.canPop() ? context.pop() : context.go('/profile'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              style: TextStyle(color: context.appColors.primary, fontSize: 10),
            ),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: child,
          ),
        ),
      ),
      bottomNavigationBar: showNavigationBar
          ? IgnorePointer(
              ignoring: isBusy,
              child: const AppNavigationBar(selectedIndex: 3),
            )
          : null,
    ),
  );
}

class AdminInfo extends StatelessWidget {
  const AdminInfo(this.message, {super.key, this.warning = false});
  final String message;
  final bool warning;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: warning
          ? context.statusColors.pendingContainer
          : context.appColors.primaryContainer,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline,
          size: 18,
          color: warning
              ? context.statusColors.pending
              : context.appColors.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: warning
                  ? context.statusColors.pending
                  : context.appColors.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}

class AdminLoadError extends StatelessWidget {
  const AdminLoadError({
    super.key,
    required this.message,
    required this.onRetry,
  });
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    ),
  );
}
