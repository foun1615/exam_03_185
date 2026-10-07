import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:exam_03_185/models/patient_model.dart';

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
  // Create
  Future<void> addPatient(PatientModel p) async {
    await _patients.add({
      ...p.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Read (Real-time)
  Stream<List<PatientModel>> patientsStream() {
    return _patients
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(PatientModel.fromDoc).toList());
  }

  // Update
  Future<void> updatePatient(String id, Map<String, dynamic> data) async {
    await _patients.doc(id).update(data);
  }

  // Delete
  Future<void> deletePatient(String id) async {
    await _patients.doc(id).delete();
  }
}
