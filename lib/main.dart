import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'login_page.dart';
import 'admin_login_page.dart';
import 'screens/admin_dashboard.dart';
import 'screens/admin_users_page.dart';
import 'screens/guru_dashboard.dart';
import 'screens/siswa_dashboard.dart';
import 'screens/tu_dashboard.dart';
import 'screens/ortu_dashboard.dart';
import 'forgot_password_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const LMSApp());
}

class LMSApp extends StatelessWidget {
  const LMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LMS SMK Pelita Tiga',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/': (context) => const LoginPage(),
        '/login': (context) => const LoginPage(),
        '/admin-login': (context) => const AdminLoginPage(),
        '/home': (context) => const OrtuDashboard(),
        '/admin': (context) => const AdminDashboard(),
        '/admin/users': (context) => const AdminUsersPage(),
        '/guru': (context) => const GuruDashboard(),
        '/siswa': (context) => const SiswaDashboard(),
        '/tu': (context) => const TUDashboard(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

// ============================================
// HomePage Placeholder (untuk fallback)
// ============================================
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard LMS'),
        backgroundColor: const Color(0xFF1e3a8a),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, size: 80, color: Color(0xFF1e3a8a)),
            SizedBox(height: 16),
            Text(
              'Selamat Datang di LMS SMK Pelita Tiga!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Silakan pilih menu di bawah',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}