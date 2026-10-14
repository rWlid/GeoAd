import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Fake OTP
const fakeCode = '1234';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.phone});

  final String phone;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.trim() != fakeCode) {
      _showError('الرمز غير صحيح. استخدم $fakeCode');
      return;
    }

    final email = '${widget.phone}@phone.geoad.app';
    final password = 'geoad-mock-${widget.phone}';
    final db = Supabase.instance.client;

    setState(() => _loading = true);
    try {
      // Only accounts that already exist with a profile get in.
      // Anyone else is simply not let in, with no message.
      try {
        await db.auth.signInWithPassword(email: email, password: password);
      } on AuthException catch (e) {
        if (e.code == 'invalid_credentials') return;
        rethrow;
      }
      final profile = await db
          .from('profiles')
          .select('id')
          .eq('id', db.auth.currentUser!.id)
          .maybeSingle();
      if (profile == null) {
        await db.auth.signOut();
        return;
      }
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('رمز التحقق'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text('أرسلنا رمز إلى ${widget.phone}'),
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(labelText: 'الرمز'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _verify,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('تحقق'),
            ),
          ],
        ),
      ),
    );
  }
}
