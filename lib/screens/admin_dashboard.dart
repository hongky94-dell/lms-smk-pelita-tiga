import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_users_page.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

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
        title: const Text('🎛️ Admin Dashboard'),
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
      drawer: _buildSidebar(context),
      body: _buildContent(),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF1e3a8a)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.admin_panel_settings, size: 40, color: Colors.white),
                SizedBox(height: 8),
                Text('Admin Panel', style: TextStyle(color: Colors.white, fontSize: 18)),
                Text('SMK Pelita Tiga', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          _buildMenuItem(context, Icons.dashboard, 'Dashboard', '/admin'),
          _buildMenuItem(context, Icons.people, 'Kelola User', '/admin/users'),
          _buildMenuItem(context, Icons.school, 'Mata Pelajaran', '/admin/subjects'),
          _buildMenuItem(context, Icons.class_, 'Kelola Kelas', '/admin/classes'),
          _buildMenuItem(context, Icons.announcement, 'Pengumuman', '/admin/announcements'),
          _buildMenuItem(context, Icons.receipt_long, 'Administrasi', '/admin/docs'),
          _buildMenuItem(context, Icons.bar_chart, 'Laporan', '/admin/reports'),
          _buildMenuItem(context, Icons.settings, 'Settings', '/admin/settings'),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, String route) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1e3a8a)),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        
        // Navigasi ke route yang sesuai
        if (route == '/admin/users') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AdminUsersPage()),
          );
        } else if (route == '/admin') {
          // Tetap di dashboard
          return;
        } else {
          // Untuk menu lain yang belum dibuat
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Menu $title akan segera tersedia!')),
          );
        }
      },
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('👋 Selamat Datang, Admin!', 
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Kelola seluruh sistem LMS dari panel ini.',
            style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildStatCard('👥 Total User', '124', Colors.blue),
                _buildStatCard('👨‍🏫 Guru', '18', Colors.green),
                _buildStatCard('👨‍🎓 Siswa', '98', Colors.orange),
                _buildStatCard('📚 Materi', '45', Colors.purple),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}