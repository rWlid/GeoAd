import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'my_products_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _db = Supabase.instance.client;
  // قراءة بيانات الحساب: لعرض حقل إضافي أضف اسمه داخل select
  late final Future<Map<String, dynamic>> _profile = _db
      .from('profiles')
      .select('name, phone, email')
      .eq('id', _db.auth.currentUser!.id)
      .single();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي'), centerTitle: true),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final name = snapshot.data!['name'] as String;
          final phone = snapshot.data!['phone'] as String;
          final email = snapshot.data!['email'] as String?;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(32),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 36,
                        child: Icon(Icons.person, size: 36),
                      ),
                      const SizedBox(height: 12),
                      Text(name, style: Theme.of(context).textTheme.titleLarge),
                      Text(phone),
                      // البريد الإلكتروني تحت الجوال: يظهر فقط إذا كان موجوداً
                      if (email != null) Text(email),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: const Text('منتجاتي'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyProductsScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('تسجيل الخروج'),
                // main.dart hears the sign out and shows the sign in screen.
                onPressed: () => _db.auth.signOut(),
              ),
            ],
          );
        },
      ),
    );
  }
}
