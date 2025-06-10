import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fmapp/supabase_options.dart';
import 'package:fmapp/src/features/auth/presentation/screens/auth_gate.dart';
import 'package:fmapp/src/core/data/isar_service.dart';
import 'package:isar/isar.dart';

// Global navigator key
final navigatorKey = GlobalKey<NavigatorState>();

// Provider for Supabase client
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  final isarService = IsarService();
  await isarService.init();

  runApp(
    ProviderScope(
      overrides: [
        isarInstanceProvider.overrideWithValue(isarService.instance),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'fmapp',
      debugShowCheckedModeBanner: false, // Hiding debug banner for cleaner look
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.teal[700],
          foregroundColor: Colors.white,
          elevation: 2,
          titleTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: Colors.teal[700],
          unselectedItemColor: Colors.grey[600],
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          // unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500), // Optional
        ),
      ),
      home: const AuthGate(),
    );
  }
}
