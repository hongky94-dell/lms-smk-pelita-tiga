import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _loginIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _loginType = 'email';
  int _tapCount = 0;

  @override
  void dispose() {
    _loginIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);

    try {
      String email = '';
      final loginId = _loginIdController.text.trim();

      // Cari email berdasarkan login type
      if (_loginType == 'email') {
        email = loginId;
      } else if (_loginType == 'kode_guru') {
        final result = await Supabase.instance.client
            .from('profiles')
            .select('email')
            .eq('kode_guru', loginId)
            .maybeSingle();
        
        if (result == null) {
          throw Exception('Kode Guru tidak ditemukan');
        }
        email = result['email'];
      } else if (_loginType == 'kode_tu') {
        final result = await Supabase.instance.client
            .from('profiles')
            .select('email')
            .eq('kode_tu', loginId)
            .maybeSingle();
        
        if (result == null) {
          throw Exception('Kode TU tidak ditemukan');
        }
        email = result['email'];
      } else if (_loginType == 'nisn') {
        final result = await Supabase.instance.client
            .from('profiles')
            .select('email')
            .eq('nisn', loginId)
            .maybeSingle();
        
        if (result == null) {
          throw Exception('NISN tidak ditemukan');
        }
        email = result['email'];
      }

      // Login dengan email
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        // Get profile
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('*')
            .eq('id', response.user!.id)
            .single();

        if (mounted) {
          // Redirect berdasarkan role
          final role = profile['role'];
          if (role == 'admin') {
            // Admin tidak boleh login dari halaman ini
            await Supabase.instance.client.auth.signOut();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Admin silakan login di halaman khusus Administrator.'),
                backgroundColor: Colors.orange,
              ),
            );
            setState(() => _isLoading = false);
          } else if (role == 'guru') {
            Navigator.pushReplacementNamed(context, '/guru');
          } else if (role == 'siswa') {
            Navigator.pushReplacementNamed(context, '/siswa');
          } else if (role == 'tata_usaha') {
            Navigator.pushReplacementNamed(context, '/tu');
          } else {
            Navigator.pushReplacementNamed(context, '/home');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login gagal: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // Hidden admin login - triple tap on logo
  void _handleLogoTap() {
    _tapCount++;
    if (_tapCount == 3) {
      _tapCount = 0;
      Navigator.pushNamed(context, '/admin-login');
    }
    // Reset tap count after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      _tapCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo with hidden admin access
                  GestureDetector(
                    onTap: _handleLogoTap,
                    child: const Icon(
                      Icons.school,
                      size: 80,
                      color: Color(0xFF1e3a8a),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'LMS SMK Pelita Tiga',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1e3a8a),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Login Type Selector (TANPA ADMIN)
                  DropdownButtonFormField<String>(
                    value: _loginType,
                    decoration: const InputDecoration(
                      labelText: 'Login Sebagai',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'email', child: Text('Orang Tua (Email)')),
                      DropdownMenuItem(value: 'kode_guru', child: Text('Guru (Kode Guru)')),
                      DropdownMenuItem(value: 'kode_tu', child: Text('Tata Usaha (Kode TU)')),
                      DropdownMenuItem(value: 'nisn', child: Text('Siswa (NISN)')),
                    ],
                    onChanged: (value) {
                      setState(() => _loginType = value!);
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Login ID Input
                  TextField(
                    controller: _loginIdController,
                    decoration: InputDecoration(
                      labelText: _loginType == 'email' 
                          ? 'Email' 
                          : _loginType == 'nisn' 
                              ? 'NISN' 
                              : _loginType == 'kode_tu'
                                  ? 'Kode TU'
                                  : 'Kode Guru',
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(
                        _loginType == 'email' 
                            ? Icons.email 
                            : _loginType == 'nisn' 
                                ? Icons.credit_card
                                : _loginType == 'kode_tu'
                                    ? Icons.badge
                                    : Icons.badge,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Password Input
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1e3a8a),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'LOGIN',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Forgot Password
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/forgot-password');
                    },
                    child: const Text('Lupa Password?'),
                  ),
                  const SizedBox(height: 8),
                  
                  
                  // Footer
                  Text(
                    '© 2024 LMS SMK Pelita Tiga',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}