import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:exam_03_185/controllers/firebase_service.dart';
import 'package:exam_03_185/models/patient_model.dart';
import 'package:exam_03_185/screens/form_screen.dart';

class DisplayScreen extends StatelessWidget {
  final AppUser user;
  const DisplayScreen({super.key, required this.user});

  Color _triageColor(int s) {
    switch (s) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow;
      case 4:
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  Future<void> _confirmDelete(BuildContext context, PatientModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการปิดเคสส่งต่อ'),
        content: Text('ต้องการย้ายผู้ป่วยเข้าห้องผ่าตัด / ปิดเคสส่งต่อของ "${p.patientName}" ใช่หรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ยืนยัน', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      String msg = 'ปิดเคสส่งต่อแล้ว';
      try {
        await FirebaseService().deletePatient(p.id!);
      } catch (e) {
        msg = e.toString().replaceFirst('Exception: ', '');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _edit(BuildContext context, PatientModel p) async {
    await showDialog(
      context: context,
      builder: (ctx) => _EditDialog(patient: p),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = FirebaseService();
    return StreamBuilder<List<PatientModel>>(
      stream: service.patientsStream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('เกิดข้อผิดพลาด: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return const Center(child: Text('ยังไม่มีข้อมูลผู้ป่วย'));
        }
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final p = list[i];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _triageColor(p.triageScore),
                  foregroundColor: Colors.white,
                  child: Text('${p.triageScore}'),
                ),
                title: Text(
                  p.patientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SpO2: ${p.spo2}%  |  แพทย์เจ้าของไข้: ${p.doctorEmail}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Ref: ${p.referralId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // createdAt เป็น null ชั่วคราวตอนเพิ่งบันทึก (รอเซิร์ฟเวอร์ตอบกลับ)
                    Text(
                      'วันที่บันทึก: ${p.createdAt == null ? '-' : DateFormat('dd/MM/yyyy').format(p.createdAt!)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                isThreeLine: true,
                // Operator: ซ่อนปุ่ม Edit/Delete
                trailing: user.isAdmin
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _edit(context, p),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(context, p),
                          ),
                        ],
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}

/// กล่องแก้ไข: อัปเดตสัญญาณชีพ / ระดับความเร่งด่วน
class _EditDialog extends StatefulWidget {
  final PatientModel patient;
  const _EditDialog({required this.patient});

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _referralError; // ข้อความ error จากเซิร์ฟเวอร์ (เช่น รหัสซ้ำ)
  late final TextEditingController _referralId =
      TextEditingController(text: widget.patient.referralId);
  late final TextEditingController _name =
      TextEditingController(text: widget.patient.patientName);
  late final TextEditingController _doctorEmail =
      TextEditingController(text: widget.patient.doctorEmail);
  late final TextEditingController _triage =
      TextEditingController(text: widget.patient.triageScore.toString());
  late final TextEditingController _spo2 =
      TextEditingController(text: widget.patient.spo2.toString());

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final newRef = _referralId.text.trim();
      await FirebaseService().updatePatient(widget.patient.id!, {
        // ส่งเฉพาะเมื่อมีการเปลี่ยนรหัส จะได้ไม่ถูกบล็อกเพราะข้อมูลเก่าที่ซ้ำอยู่แล้ว
        if (newRef != widget.patient.referralId) 'referralId': newRef,
        'patientName': _name.text.trim(),
        'doctorEmail': _doctorEmail.text.trim(),
        'triageScore': int.parse(_triage.text.trim()),
        'spo2': double.parse(_spo2.text.trim()),
      });
      if (mounted) Navigator.pop(context);
    } on DuplicateReferralException {
      if (!mounted) return;
      _referralError = DuplicateReferralException.message;
      _formKey.currentState!.validate();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  void dispose() {
    _referralId.dispose();
    _name.dispose();
    _doctorEmail.dispose();
    _triage.dispose();
    _spo2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('แก้ไขข้อมูลผู้ป่วย'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _referralId,
                decoration: const InputDecoration(
                    labelText: 'รหัสส่งต่อผู้ป่วย (Referral ID)'),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                onChanged: (_) => _referralError = null, // พิมพ์แก้แล้วล้าง error
                validator: (v) =>
                    _referralError ?? PatientValidators.required.call(v),
              ),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'ชื่อ / HN'),
                validator: PatientValidators.required.call,
              ),
              TextFormField(
                controller: _doctorEmail,
                keyboardType: TextInputType.emailAddress,
                decoration:
                    const InputDecoration(labelText: 'อีเมลแพทย์ผู้ส่งตัว'),
                validator: PatientValidators.email,
              ),
              TextFormField(
                controller: _triage,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Triage Score (1-5)'),
                validator: PatientValidators.triage,
              ),
              TextFormField(
                controller: _spo2,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'SpO2 (%)'),
                validator: PatientValidators.spo2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก')),
        ElevatedButton(onPressed: _save, child: const Text('บันทึก')),
      ],
    );
  }
}