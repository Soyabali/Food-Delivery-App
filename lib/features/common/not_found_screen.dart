import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_routes.dart';
import '../../core/widgets/common.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, required this.location, this.message});

  final Uri location;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.white),
      body: Center(
        child: SingleChildScrollView(
          child: EmptyState(
            icon: Icons.explore_off_outlined,
            title: 'Page not found',
            message: message ?? 'Nothing lives at ${location.path}.',
            actionLabel: 'Go to Home',
            // Redirect sends signed-out users to login instead.
            onAction: () => context.go(AppRoutes.home),
          ),
        ),
      ),
    );
  }
}
