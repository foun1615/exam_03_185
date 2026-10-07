import 'package:flutter/material.dart';
import 'package:form_field_validator/form_field_validator.dart';
import 'package:exam_03_185/controllers/firebase_service.dart';
import 'package:exam_03_185/models/patient_model.dart';

/// ตัวตรวจสอบข้อมูล (ใช้ร่วมกับหน้า Edit)
class PatientValidators {
  static final required = RequiredValidator(errorText: 'ห้ามเว้นว่าง');

  // อีเมล: ตัดช่องว่างหน้า-หลังก่อนตรวจ (คีย์บอร์ดมือถือมักเติมช่องว่างต่อท้าย)
  static String? email(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'กรุณากรอกอีเมล';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      return 'รูปแบบอีเมลไม่ถูกต้อง';
    }
    return null;
  }

  static String? triage(String? v) {
    if (v == null || v.trim().isEmpty) return 'ห้ามเว้นว่าง';
    final n = int.tryParse(v.trim());
    if (n == null || n < 1 || n > 5) return 'ต้องเป็นเลขจำนวนเต็ม 1-5';
    return null;
  }

  static String? spo2(String? v) {
    if (v == null || v.trim().isEmpty) return 'ห้ามเว้นว่าง';
    final n = double.tryParse(v.trim());
    if (n == null || n < 0 || n > 100) return 'ต้องเป็นตัวเลข 0-100';
    return null;
  }
}

class FormScreen extends StatefulWidget {
  const FormScreen({super.key});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _referralId = TextEditingController();
  final _name = TextEditingController();
  final _doctorEmail = TextEditingController();
  final _triage = TextEditingController();
  final _spo2 = TextEditingController();
  final _service = FirebaseService();
  bool _saving = false;
  String? _referralError; // ข้อความ error จากเซิร์ฟเวอร์ (เช่น รหัสซ้ำ)

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _service.addPatient(PatientModel(
        referralId: _referralId.text.trim().toUpperCase(),
        patientName: _name.text.trim(),
        doctorEmail: _doctorEmail.text.trim(),
        triageScore: int.parse(_triage.text.trim()),
        spo2: double.parse(_spo2.text.trim()),
      ));
      _formKey.currentState!.reset();
      for (final c in [_referralId, _name, _doctorEmail, _triage, _spo2]) {
        c.clear();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกข้อมูลสำเร็จ')));
    } on DuplicateReferralException {
      if (!mounted) return;
      // แสดง error ใต้ช่อง Referral ID
      _referralError = DuplicateReferralException.message;
      _formKey.currentState!.validate();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_referralId, _name, _doctorEmail, _triage, _spo2]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _referralId,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  labelText: 'รหัสส่งต่อผู้ป่วย (Referral ID)',
                  hintText: 'เช่น REF-EMR-2026',
                  border: OutlineInputBorder()),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              onChanged: (_) => _referralError = null, // พิมพ์แก้แล้วล้าง error
              validator: (v) =>
                  _referralError ?? PatientValidators.required.call(v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'ชื่อ-นามสกุล ผู้ป่วย หรือ HN',
                  border: OutlineInputBorder()),
              validator: PatientValidators.required.call,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _doctorEmail,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'อีเมลแพทย์ผู้ส่งตัว',
                  border: OutlineInputBorder()),
              validator: PatientValidators.email,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _triage,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Triage Score (1: Resuscitation - 5: Non-urgent)',
                  border: OutlineInputBorder()),
              validator: PatientValidators.triage,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _spo2,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'SpO2 (%)', border: OutlineInputBorder()),
              validator: PatientValidators.spo2,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save),
                label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึก'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}