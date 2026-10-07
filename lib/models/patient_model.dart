import 'package:cloud_firestore/cloud_firestore.dart';

/// ข้อมูลผู้ป่วยที่ส่งต่อ (collection: patients)
class PatientModel {
  final String? id; // document id
  final String referralId;
  final String patientName; // ชื่อ-นามสกุล หรือ HN
  final String doctorEmail;
  final int triageScore; // 1-5
  final double spo2; // %

  PatientModel({
    this.id,
    required this.referralId,
    required this.patientName,
    required this.doctorEmail,
    required this.triageScore,
    required this.spo2,
  });

  Map<String, dynamic> toMap() => {
        'referralId': referralId,
        'patientName': patientName,
        'doctorEmail': doctorEmail,
        'triageScore': triageScore,
        'spo2': spo2,
      };

  factory PatientModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return PatientModel(
      id: doc.id,
      referralId: d['referralId'] ?? '',
      patientName: d['patientName'] ?? '',
      doctorEmail: d['doctorEmail'] ?? '',
      triageScore: (d['triageScore'] ?? 5).toInt(),
      spo2: (d['spo2'] ?? 0).toDouble(),
    );
  }
}

/// ข้อมูลสมาชิก (collection: users) ใช้ทำ RBAC
class AppUser {
  final String uid;
  final String name;
  final String email;
  final String role; // 'admin' หรือ 'operator'

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
  });

  bool get isAdmin => role == 'admin';

  Map<String, dynamic> toMap() =>
      {'uid': uid, 'name': name, 'email': email, 'role': role};

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        uid: m['uid'] ?? '',
        name: m['name'] ?? '',
        email: m['email'] ?? '',
        // เก็บเป็นตัวพิมพ์เล็กเสมอ (admin / operator)
        role: (m['role'] ?? 'operator').toString().toLowerCase(),
      );
}
