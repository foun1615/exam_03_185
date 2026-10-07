import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:form_field_validator/form_field_validator.dart';
import 'package:exam_03_185/controllers/firebase_service.dart';

/// หน้าเข้าสู่ระบบ + สมัครสมาชิก (สลับโหมดด้วยปุ่มด้านล่าง)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _service = FirebaseService();
  bool _isRegister = false; // false = เข้าสู่ระบบ, true = สมัครสมาชิก
  bool _loading = false;

  // ตรวจอีเมล: ตัดช่องว่างหน้า-หลังก่อน (คีย์บอร์ดมือถือมักเติมช่องว่างต่อท้ายให้)
  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'กรุณากรอกอีเมล';
    final pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!pattern.hasMatch(email)) return 'รูปแบบอีเมลไม่ถูกต้อง';
    return null;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_isRegister) {
        await _service.signUp(_name.text, _email.text, _password.text);
      } else {
        await _service.signIn(_email.text, _password.text);
      }
      // สำเร็จแล้ว AuthGate จะพาไปหน้าหลักเอง
    } on FirebaseAuthException catch (e) {
      _snack(_service.authMessage(e));
    } catch (e) {
      _snack('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
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
                  const SizedBox(height: 4),
                  Text(_isRegister ? 'สมัครสมาชิกใหม่' : 'เข้าสู่ระบบ'),
                  const SizedBox(height: 24),

                  // ช่องชื่อ แสดงเฉพาะตอนสมัครสมาชิก
                  if (_isRegister) ...[
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                          labelText: 'ชื่อ-นามสกุล',
                          border: OutlineInputBorder()),
                      validator:
                          RequiredValidator(errorText: 'กรุณากรอกชื่อ').call,
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'อีเมล', border: OutlineInputBorder()),
                    autocorrect: false,
                    enableSuggestions: false,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'รหัสผ่าน', border: OutlineInputBorder()),
                    validator: MultiValidator([
                      RequiredValidator(errorText: 'กรุณากรอกรหัสผ่าน'),
                      MinLengthValidator(6,
                          errorText: 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร'),
                    ]).call,
                  ),

                  // ช่องยืนยันรหัสผ่าน แสดงเฉพาะตอนสมัครสมาชิก
                  if (_isRegister) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirm,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: 'ยืนยันรหัสผ่าน',
                          border: OutlineInputBorder()),
                      validator: (value) => value != _password.text
                          ? 'รหัสผ่านไม่ตรงกัน'
                          : null,
                    ),
                  ],

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_isRegister ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ'),
                    ),
                  ),
                  const Divider(height: 32),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() => _isRegister = !_isRegister),
                    child: Text(_isRegister
                        ? 'มีบัญชีอยู่แล้ว? เข้าสู่ระบบ'
                        : 'ยังไม่มีบัญชี? สมัครสมาชิก'),
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
