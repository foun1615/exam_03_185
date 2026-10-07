import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:form_field_validator/form_field_validator.dart';
import 'package:exam_03_185/controllers/firebase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _service = FirebaseService();
  bool _loading = false;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _service.signIn(_email.text, _password.text);
      // AuthGate จะพาไปหน้าหลักเอง
    } on FirebaseAuthException catch (e) {
      _snack('เข้าสู่ระบบไม่สำเร็จ: ${e.code}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _seed() async {
    setState(() => _loading = true);
    try {
      await _service.seedTestUsers();
      _snack('สร้างบัญชีทดสอบแล้ว (รหัสผ่าน 123456)');
    } catch (e) {
      _snack('สร้างบัญชีไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Icon(Icons.monitor_heart, size: 80, color: Colors.red),
                  const SizedBox(height: 8),
                  const Text('TeleTriage',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'อีเมล', border: OutlineInputBorder()),
                    validator: MultiValidator([
                      RequiredValidator(errorText: 'กรุณากรอกอีเมล'),
                      EmailValidator(errorText: 'รูปแบบอีเมลไม่ถูกต้อง'),
                    ]).call,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'รหัสผ่าน', border: OutlineInputBorder()),
                    validator:
                        RequiredValidator(errorText: 'กรุณากรอกรหัสผ่าน').call,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('เข้าสู่ระบบ'),
                    ),
                  ),
                  const Divider(height: 32),
                  TextButton(
                    onPressed: _loading ? null : _seed,
                    child: const Text('สร้างบัญชีทดสอบ (ครั้งแรกครั้งเดียว)'),
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
