import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:csv/csv.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _filterRole = 'all';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      var query = Supabase.instance.client.from('profiles').select('*');

      if (_filterRole != 'all') {
        query = query.eq('role', _filterRole);
      }

      final data = await query;

      setState(() {
        _users = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    return _users.where((user) {
      final email = (user['email'] ?? '').toString().toLowerCase();
      final nama = (user['nama'] ?? '').toString().toLowerCase();
      final nisn = (user['nisn'] ?? '').toString().toLowerCase();
      final kodeGuru = (user['kode_guru'] ?? '').toString().toLowerCase();
      final kodeTu = (user['kode_tu'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return email.contains(query) || nama.contains(query) || 
             nisn.contains(query) || kodeGuru.contains(query) || kodeTu.contains(query);
    }).toList();
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import User dari Excel/CSV'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pilih file Excel (.xlsx) atau CSV (.csv)'),
            const SizedBox(height: 16),
            const Text(
              'Format file harus memiliki kolom:\n'
              '- Email\n'
              '- Nama\n'
              '- Password\n'
              '- Role (guru/siswa/ortu/tata_usaha/admin)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '💡 NISN diisi manual untuk siswa. Kode Guru, TU & Ortu auto-generate!',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: _pickAndImportFile,
            icon: const Icon(Icons.upload_file),
            label: const Text('Pilih File'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndImportFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
      );

      if (result != null && result.files.single.bytes != null) {
        Navigator.pop(context);
        await _importFromBytes(result.files.single.bytes!, result.files.single.name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error memilih file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importFromBytes(Uint8List bytes, String fileName) async {
    List<List<dynamic>>? rows;
    final extension = fileName.split('.').last.toLowerCase();

    try {
      if (extension == 'csv') {
        final csvData = utf8.decode(bytes);
        rows = const CsvToListConverter(
          eol: '\n',
          shouldParseNumbers: false,
        ).convert(csvData);
        
        if (rows!.isNotEmpty) {
          print('CSV Headers: ${rows![0]}');
        }
      } else if (extension == 'xlsx') {
        final excel = excel_lib.Excel.decodeBytes(bytes);
        rows = [];
        
        var firstSheet = excel.tables.keys.first;
        var sheetData = excel.tables[firstSheet];
        
        if (sheetData != null) {
          for (var row in sheetData.rows) {
            List<dynamic> rowData = [];
            for (var cell in row) {
              rowData.add(cell?.value ?? '');
            }
            if (rowData.isNotEmpty) {
              rows!.add(rowData);
            }
          }
        }
      }

      if (rows != null && rows!.isNotEmpty) {
        await _processImportData(rows!);
      } else {
        throw Exception('File kosong atau format tidak valid');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error membaca file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Generate Kode Guru otomatis (GRU001, GRU002, dst)
  String _generateKodeGuru(int index) {
    return 'GRU${(index + 1).toString().padLeft(3, '0')}';
  }

  // Generate Kode Ortu otomatis (ORT001, ORT002, dst)
  String _generateKodeOrtu(int index) {
    return 'ORT${(index + 1).toString().padLeft(3, '0')}';
  }

  // Generate Kode TU otomatis (TU001, TU002, dst)
  String _generateKodeTu(int index) {
    return 'TU${(index + 1).toString().padLeft(3, '0')}';
  }

  Future<void> _processImportData(List<List<dynamic>> rows) async {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File kosong!'), backgroundColor: Colors.red),
      );
      return;
    }

    // Parse header
    final header = rows[0].map((h) => h.toString().trim().toLowerCase()).toList();
    
    final emailIndex = header.indexWhere((h) => h.contains('email'));
    final namaIndex = header.indexWhere((h) => h.contains('nama'));
    final passwordIndex = header.indexWhere((h) => h.contains('password'));
    final roleIndex = header.indexWhere((h) => h.contains('role'));
    final nisnIndex = header.indexWhere((h) => h.contains('nisn'));

    if (emailIndex == -1 || namaIndex == -1 || passwordIndex == -1 || roleIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Format file tidak valid!\nHarus ada kolom: Email, Nama, Password, Role'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    int successCount = 0;
    int failCount = 0;
    final errors = <String>[];
    final generatedCodes = <String>[];

    // Counter untuk generate kode
    int guruCounter = 0;
    int ortuCounter = 0;
    int tuCounter = 0;

    // Get existing codes from database
    try {
      final existingProfiles = await Supabase.instance.client
          .from('profiles')
          .select('kode_guru, kode_ortu, kode_tu');
      
      for (var profile in existingProfiles) {
        if (profile['kode_guru'] != null) {
          final kode = profile['kode_guru'].toString();
          if (kode.startsWith('GRU')) {
            final num = int.tryParse(kode.substring(3)) ?? 0;
            if (num > guruCounter) guruCounter = num;
          }
        }
        if (profile['kode_ortu'] != null) {
          final kode = profile['kode_ortu'].toString();
          if (kode.startsWith('ORT')) {
            final num = int.tryParse(kode.substring(3)) ?? 0;
            if (num > ortuCounter) ortuCounter = num;
          }
        }
        if (profile['kode_tu'] != null) {
          final kode = profile['kode_tu'].toString();
          if (kode.startsWith('TU')) {
            final num = int.tryParse(kode.substring(2)) ?? 0;
            if (num > tuCounter) tuCounter = num;
          }
        }
      }
    } catch (e) {
      print('Error getting existing codes: $e');
    }

    setState(() => _isLoading = true);

    // Show progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Importing...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Processing user ${successCount + failCount + 1} of ${rows.length - 1}'),
          ],
        ),
      ),
    );

    // Process each user with delay
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      
      if (row.every((cell) => cell.toString().trim().isEmpty)) continue;
      
      try {
        final email = row[emailIndex].toString().trim();
        if (email.isEmpty) continue;

        final nama = row.length > namaIndex ? row[namaIndex].toString().trim() : '';
        final password = row.length > passwordIndex ? row[passwordIndex].toString().trim() : 'password123';
        final role = row.length > roleIndex 
            ? row[roleIndex].toString().trim().toLowerCase().replaceAll(RegExp(r'[^\w]'), '')
            : 'guru';
        final nisn = nisnIndex != -1 && row.length > nisnIndex 
            ? row[nisnIndex].toString().trim() 
            : null;

        if (!['guru', 'siswa', 'ortu', 'admin', 'tata_usaha'].contains(role)) {
          errors.add('Baris ${i + 1}: Role "$role" tidak valid');
          failCount++;
          continue;
        }

        print('Creating user: $email ($role)');

        // Delay 2 detik antar user
        if (i > 1) {
          await Future.delayed(const Duration(seconds: 2));
        }

        // Check if user already exists
        final existingUser = await Supabase.instance.client
            .from('profiles')
            .select('id')
            .eq('email', email)
            .maybeSingle();

        if (existingUser != null) {
          print('⚠️ Skip: $email (sudah ada)');
          errors.add('Baris ${i + 1}: User $email sudah ada');
          failCount++;
          continue;
        }

        // Create user
        final response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );

        final userId = response.user?.id;

        if (userId != null) {
          // Generate kode berdasarkan role
          String? kodeGuru, kodeOrtu, kodeTu, nisnValue;
          
          if (role == 'guru') {
            guruCounter++;
            kodeGuru = _generateKodeGuru(guruCounter);
            generatedCodes.add('👨‍🏫 $nama - Kode: $kodeGuru');
          } else if (role == 'siswa') {
            nisnValue = nisn ?? '';
            if (nisnValue.isNotEmpty) {
              generatedCodes.add('📚 $nama - NISN: $nisnValue');
            }
          } else if (role == 'ortu') {
            ortuCounter++;
            kodeOrtu = _generateKodeOrtu(ortuCounter);
            generatedCodes.add('👪 $nama - Kode: $kodeOrtu');
          } else if (role == 'tata_usaha') {
            tuCounter++;
            kodeTu = _generateKodeTu(tuCounter);
            generatedCodes.add('👔 $nama - Kode: $kodeTu');
          }

          // Insert ke profiles
          await Supabase.instance.client.from('profiles').insert({
            'id': userId,
            'email': email,
            'nama': nama,
            'role': role,
            if (nisnValue != null && nisnValue.isNotEmpty) 'nisn': nisnValue,
            if (kodeGuru != null) 'kode_guru': kodeGuru,
            if (kodeOrtu != null) 'kode_ortu': kodeOrtu,
            if (kodeTu != null) 'kode_tu': kodeTu,
          });
          
          successCount++;
          print('✅ Success: $email');
        } else {
          errors.add('Baris ${i + 1}: Gagal membuat user $email');
          failCount++;
        }

        // Update progress
        if (mounted) {
          Navigator.pop(context);
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Importing...'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Processing user ${successCount + failCount + 1} of ${rows.length - 1}\n'
                      '✅ Berhasil: $successCount\n❌ Gagal: $failCount'),
                ],
              ),
            ),
          );
        }
        
      } catch (e) {
        errors.add('Baris ${i + 1}: ${e.toString()}');
        failCount++;
        print('❌ Error row ${i + 1}: $e');
      }
    }

    if (mounted) Navigator.pop(context);
    setState(() => _isLoading = false);

    // Show results
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hasil Import'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ Berhasil: $successCount user', 
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('❌ Gagal: $failCount user',
                style: const TextStyle(color: Colors.red)),
              if (generatedCodes.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('📋 Kode yang di-generate:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: generatedCodes.map((code) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(code, style: const TextStyle(fontSize: 12)),
                      )).toList(),
                    ),
                  ),
                ),
              ],
              if (errors.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Detail Error:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: errors.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(e, style: const TextStyle(fontSize: 12, color: Colors.red)),
                      )).toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _loadUsers();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showAddUserDialog() {
    final _emailController = TextEditingController();
    final _namaController = TextEditingController();
    final _passwordController = TextEditingController();
    String _selectedRole = 'guru';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah User Baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _namaController,
                  decoration: const InputDecoration(labelText: 'Nama Lengkap', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'guru', child: Text('Guru')),
                    DropdownMenuItem(value: 'siswa', child: Text('Siswa')),
                    DropdownMenuItem(value: 'ortu', child: Text('Orang Tua')),
                    DropdownMenuItem(value: 'tata_usaha', child: Text('Tata Usaha')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (value) => setDialogState(() => _selectedRole = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                await _createUser(
                  _emailController.text.trim(),
                  _namaController.text.trim(),
                  _passwordController.text.trim(),
                  _selectedRole,
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createUser(String email, String nama, String password, String role) async {
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      final userId = response.user?.id;

      if (userId != null) {
        await Supabase.instance.client.from('profiles').insert({
          'id': userId,
          'email': email,
          'nama': nama,
          'role': role,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User berhasil ditambahkan!'), backgroundColor: Colors.green),
          );
          _loadUsers();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showEditDialog(Map<String, dynamic> user) {
    final _namaController = TextEditingController(text: user['nama'] ?? '');
    String _selectedRole = user['role'] ?? 'guru';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _namaController,
                decoration: const InputDecoration(labelText: 'Nama Lengkap', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'guru', child: Text('Guru')),
                  DropdownMenuItem(value: 'siswa', child: Text('Siswa')),
                  DropdownMenuItem(value: 'ortu', child: Text('Orang Tua')),
                  DropdownMenuItem(value: 'tata_usaha', child: Text('Tata Usaha')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) => setDialogState(() => _selectedRole = value!),
              ),
              if (user['nisn'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('NISN: ${user['nisn']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              if (user['kode_guru'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('Kode Guru: ${user['kode_guru']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              if (user['kode_tu'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('Kode TU: ${user['kode_tu']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                await Supabase.instance.client
                    .from('profiles')
                    .update({'nama': _namaController.text.trim(), 'role': _selectedRole})
                    .eq('id', user['id']);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User berhasil diupdate!'), backgroundColor: Colors.green),
                  );
                  _loadUsers();
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteUser(String userId, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus User'),
        content: Text('Yakin ingin menghapus user $email?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('profiles').delete().eq('id', userId);
        await Supabase.instance.client.auth.admin.deleteUser(userId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User berhasil dihapus!'), backgroundColor: Colors.green),
          );
          _loadUsers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola User'),
        backgroundColor: const Color(0xFF1e3a8a),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: _showImportDialog,
            tooltip: 'Import dari Excel/CSV',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddUserDialog,
            tooltip: 'Tambah User Manual',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Cari user...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _filterRole,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Semua')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'guru', child: Text('Guru')),
                    DropdownMenuItem(value: 'siswa', child: Text('Siswa')),
                    DropdownMenuItem(value: 'ortu', child: Text('Ortu')),
                    DropdownMenuItem(value: 'tata_usaha', child: Text('Tata Usaha')),
                  ],
                  onChanged: (value) {
                    setState(() => _filterRole = value!);
                    _loadUsers();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? const Center(child: Text('Tidak ada user'))
                    : ListView.builder(
                        itemCount: _filteredUsers.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getRoleColor(user['role']),
                                child: Text(
                                  (user['nama'] ?? '?')[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(user['nama'] ?? 'N/A'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user['email'] ?? ''),
                                  if (user['nisn'] != null) 
                                    Text('NISN: ${user['nisn']}', style: const TextStyle(fontSize: 11, color: Colors.blue)),
                                  if (user['kode_guru'] != null) 
                                    Text('Kode Guru: ${user['kode_guru']}', style: const TextStyle(fontSize: 11, color: Colors.green)),
                                  if (user['kode_tu'] != null) 
                                    Text('Kode TU: ${user['kode_tu']}', style: const TextStyle(fontSize: 11, color: Colors.purple)),
                                  if (user['kode_ortu'] != null) 
                                    Text('Kode Ortu: ${user['kode_ortu']}', style: const TextStyle(fontSize: 11, color: Colors.orange)),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildRoleChip(user['role']),
                                  IconButton(icon: const Icon(Icons.edit), onPressed: () => _showEditDialog(user)),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteUser(user['id'], user['email']),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(String? role) {
    Color color;
    String label;
    
    switch (role) {
      case 'admin': 
        color = Colors.red; 
        label = 'Admin';
        break;
      case 'guru': 
        color = Colors.blue; 
        label = 'Guru';
        break;
      case 'siswa': 
        color = Colors.green; 
        label = 'Siswa';
        break;
      case 'ortu': 
        color = Colors.orange; 
        label = 'Ortu';
        break;
      case 'tata_usaha': 
        color = Colors.purple; 
        label = 'TU';
        break;
      default: 
        color = Colors.grey;
        label = 'N/A';
    }

    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'admin': return Colors.red;
      case 'guru': return Colors.blue;
      case 'siswa': return Colors.green;
      case 'ortu': return Colors.orange;
      case 'tata_usaha': return Colors.purple;
      default: return Colors.grey;
    }
  }
}