import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Fake OTP: this is the only code that works.
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
      _showError('الرمز غير صحيح، استخدم $fakeCode');
      return;
    }

    // The trick: Supabase has no free phone OTP, so each phone number
    // becomes a hidden email + password that only this app knows.
    final email = '${widget.phone}@phone.geoad.app';
    final password = 'geoad-mock-${widget.phone}';
    final auth = Supabase.instance.client.auth;

    setState(() => _loading = true);
    try {
      try {
        await auth.signInWithPassword(email: email, password: password);
      } on AuthException {
        // First time with this phone: create the account instead.
        // Needs "Confirm email" turned off in Supabase Auth settings.
        await auth.signUp(email: email, password: password);
      }
      if (!mounted) return;
      // Signed in: drop this screen so the map (shown by main.dart) is visible.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أدخل الرمز')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text('"أرسلنا" رمزًا إلى ${widget.phone}. تلميح: $fakeCode'),
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
