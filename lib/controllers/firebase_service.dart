import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:exam_03_185/models/patient_model.dart';

/// Referral ID ซ้ำกับเคสที่มีอยู่แล้ว
class DuplicateReferralException implements Exception {
  static const message = 'รหัสนี้ถูกใช้แล้ว';
  @override
  String toString() => message;
}

/// รวม Auth + Firestore CRUD
class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _patients =>
      _db.collection('patients');

  // ---------------- Auth ----------------
  Stream<User?> get authChanges => _auth.authStateChanges();

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
  }

  Future<void> signOut() => _auth.signOut();

  /// เป็น true ระหว่างกำลังสมัคร (AuthGate จะรอจนบันทึกข้อมูลผู้ใช้เสร็จ)
  static bool registering = false;

  /// สมัครสมาชิกใหม่ (ผู้สมัครเองได้สิทธิ์ operator)
  /// ผลลัพธ์: มีบัญชีใน Firebase Authentication และมีข้อมูลใน Firestore (users)
  Future<void> signUp(String name, String email, String password) async {
    registering = true;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      final user = AppUser(
          uid: cred.user!.uid,
          name: name.trim(),
          email: email.trim(),
          role: 'operator');
      try {
        await _users.doc(user.uid).set(user.toMap());
      } catch (e) {
        // บันทึก Firestore ไม่สำเร็จ -> ลบบัญชีที่เพิ่งสร้าง จะได้ไม่เหลือบัญชีค้าง
        await cred.user!.delete();
        rethrow;
      }
    } finally {
      registering = false;
    }
  }

  /// ติดตามข้อมูลผู้ใช้คนเดียว (Real-time) ใช้ตรวจสิทธิ์ตอนเข้าแอป
  Stream<AppUser?> appUserStream(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromMap(doc.data()!);
    });
  }

  /// รายชื่อผู้ใช้ทั้งหมด (Real-time) สำหรับหน้าจัดการผู้ใช้ของ Admin
  Stream<List<AppUser>> usersStream() {
    return _users.snapshots().map(
        (snap) => snap.docs.map((d) => AppUser.fromMap(d.data())).toList());
  }

  /// Admin ปรับระดับสิทธิ์ผู้ใช้ ('admin' หรือ 'operator')
  Future<void> updateRole(String uid, String role) async {
    await _users.doc(uid).update({'role': role});
  }

  /// Admin ลบบัญชีผู้ใช้ออกจากระบบ (ลบเอกสารใน collection users)
  /// ผู้ใช้ที่ถูกลบจะเข้าใช้แอปไม่ได้อีก
  Future<void> deleteUser(String uid) async {
    await _users.doc(uid).delete();
  }

  /// แปลงรหัส error ของ Firebase Auth เป็นข้อความภาษาไทย
  String authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'รูปแบบอีเมลไม่ถูกต้อง';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      case 'email-already-in-use':
        return 'อีเมลนี้ถูกใช้สมัครแล้ว';
      case 'weak-password':
        return 'รหัสผ่านสั้นเกินไป (อย่างน้อย 6 ตัวอักษร)';
      case 'network-request-failed':
        return 'เชื่อมต่ออินเทอร์เน็ตไม่ได้';
      default:
        return 'เกิดข้อผิดพลาด: ${e.code}';
    }
  }

  // ---------------- Firestore CRUD ----------------
  /// ตรวจว่า Referral ID ซ้ำหรือไม่ (ข้ามเอกสารของตัวเองตอนแก้ไขด้วย excludeId)
  /// ถ้าซ้ำจะ throw DuplicateReferralException
  Future<void> _ensureReferralUnique(String referralId,
      {String? excludeId}) async {
    final snap = await _patients
        .where('referralId', isEqualTo: referralId.trim())
        .limit(2)
        .get();
    final taken = snap.docs.any((d) => d.id != excludeId);
    if (taken) throw DuplicateReferralException();
  }

  // Create
  Future<void> addPatient(PatientModel p) async {
    await _ensureReferralUnique(p.referralId);
    await _patients.add({
      ...p.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Read (Real-time) เรียงตามความเร่งด่วน: Triage 1 อยู่บนสุด
  // ถ้า Triage เท่ากัน เคสใหม่กว่าอยู่ก่อน
  // (เรียงฝั่งแอป จึงไม่ต้องสร้าง Composite Index ใน Firestore)
  Stream<List<PatientModel>> patientsStream() {
    return _patients.snapshots().map((snap) {
      final list = snap.docs.map(PatientModel.fromDoc).toList();
      final now = DateTime.now(); // เคสที่เพิ่งบันทึก createdAt ยังเป็น null
      list.sort((a, b) {
        final byTriage = a.triageScore.compareTo(b.triageScore);
        if (byTriage != 0) return byTriage;
        return (b.createdAt ?? now).compareTo(a.createdAt ?? now);
      });
      return list;
    });
  }

  // Update
  Future<void> updatePatient(String id, Map<String, dynamic> data) async {
    final ref = data['referralId'];
    if (ref is String) await _ensureReferralUnique(ref, excludeId: id);
    await _patients.doc(id).update(data);
  }

  // Delete
  Future<void> deletePatient(String id) async {
    await _patients.doc(id).delete();
  }
}