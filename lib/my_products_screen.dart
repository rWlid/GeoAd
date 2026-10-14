import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyProductsScreen extends StatelessWidget {
  const MyProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Supabase.instance.client;

    return Scaffold(
      appBar: AppBar(title: const Text('منتجاتي'), centerTitle: true),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: db
            .from('products')
            .select('name, price')
            .eq('owner', db.auth.currentUser!.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final products = snapshot.data!;
          if (products.isEmpty) {
            return const Center(child: Text('لا توجد منتجات'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final p in products)
                Card(
                  child: ListTile(
                    title: Text(p['name'] as String),
                    trailing: Text('${p['price']} ر.س'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
