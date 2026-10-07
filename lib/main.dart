import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:flutter/material.dart';
import 'package:exam_03_185/controllers/firebase_service.dart';
import 'package:exam_03_185/models/patient_model.dart';
import 'package:exam_03_185/screens/login_screen.dart';
import 'package:exam_03_185/screens/main_navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // อ่านค่าจาก google-services.json
  runApp(const TeleTriageApp());
}

class TeleTriageApp extends StatelessWidget {
  const TeleTriageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TeleTriage',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// เช็กสถานะ login: ยังไม่ login -> LoginScreen, login แล้ว -> โหลด role -> MainNavigation
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirebaseService();
    return StreamBuilder<User?>(
      stream: service.authChanges,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) return const LoginScreen();

        // ติดตามข้อมูล role แบบ Real-time
        // (ตอนสมัครใหม่ ข้อมูลจะถูกบันทึกลง Firestore ตามมา จึงรอโหลดสักครู่)
        return StreamBuilder<AppUser?>(
          stream: service.appUserStream(user.uid),
          builder: (context, roleSnap) {
            // ยังโหลดไม่เสร็จ หรือกำลังสมัคร (รอบันทึกข้อมูลลง Firestore)
            if (roleSnap.connectionState == ConnectionState.waiting ||
                (roleSnap.data == null && FirebaseService.registering)) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            final appUser = roleSnap.data;
            // ไม่มีข้อมูลผู้ใช้ใน Firestore = ถูก Admin ลบออกจากระบบแล้ว
            if (appUser == null) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.block, size: 64, color: Colors.red),
                        const SizedBox(height: 12),
                        const Text(
                          'บัญชีนี้ถูกลบออกจากระบบแล้ว\nกรุณาติดต่อผู้ดูแลระบบ',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                            onPressed: service.signOut,
                            child: const Text('Sign Out')),
                      ],
                    ),
                  ),
                ),
              );
            }
            return MainNavigation(user: appUser);
          },
        );
      },
    );
  }
}
