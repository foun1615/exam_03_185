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

  /// ดึงข้อมูล role ของผู้ใช้จาก collection users
  Future<AppUser?> getAppUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.data()!);
  }

  /// สร้างบัญชีทดสอบ 2 บัญชี (รหัสผ่าน 123456) พร้อมบันทึก role
  Future<void> seedTestUsers() async {
    await _seed('admin@test.com', 'Admin Test', 'admin');
    await _seed('operator@test.com', 'Operator Test', 'operator');
    await _auth.signOut();
  }

  Future<void> _seed(String email, String name, String role) async {
    const pw = '123456';
    UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: pw);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        cred = await _auth.signInWithEmailAndPassword(
            email: email, password: pw);
      } else {
        rethrow;
      }
    }
    final user = AppUser(
        uid: cred.user!.uid, name: name, email: email, role: role);
    await _users.doc(user.uid).set(user.toMap());
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
