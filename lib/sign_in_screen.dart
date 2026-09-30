import 'package:flutter/material.dart';

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
    if (phone.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid phone number')),
      );
      return;
    }
    // No SMS is sent. We just move on to the code screen.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OtpScreen(phone: phone)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: '05XXXXXXXX',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _sendCode,
              child: const Text('Send code'),
            ),
          ],
        ),
      ),
    );
  }
}
