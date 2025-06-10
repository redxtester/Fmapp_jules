import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fmapp/src/features/auth/presentation/state/auth_controller.dart';
import 'package:fmapp/src/features/auth/presentation/screens/login_screen.dart';
import 'package:fmapp/src/core/presentation/widgets/loading_indicator.dart';
// Import the new DashboardScreen
import 'package:fmapp/src/features/dashboard/presentation/screens/dashboard_screen.dart';


class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          // User is logged in
          // TODO: Check if email is verified if Supabase is configured for it.
          return const DashboardScreen(); // Navigate to actual DashboardScreen
        }
        // User is null, not logged in
        return const LoginScreen(); // Navigate to login screen
      },
      loading: () => const Scaffold(body: LoadingIndicator(message: 'Checking authentication...')),
      error: (error, stackTrace) {
        print('AuthGate Error: $error \n$stackTrace'); // Log error for debugging
        return const LoginScreen();
      },
    );
  }
}
