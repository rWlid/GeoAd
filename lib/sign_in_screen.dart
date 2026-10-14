import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'otp_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _sendCode() {
    final phone = _phone.text.trim();
    // 05 then 8 digits
    if (!RegExp(r'^05\d{8}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ادخل رقم جوال صحيح')));
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => OtpScreen(phone: phone)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 10,
              decoration: const InputDecoration(
                labelText: 'رقم الجوال',
                hintText: '05XXXXXXXX',
                hintTextDirection: TextDirection.ltr,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _sendCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: const Text('دخول'),
            ),
          ],
        ),
      ),
    );
  }
}
