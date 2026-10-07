import 'package:flutter/material.dart';
import 'package:exam_03_185/controllers/firebase_service.dart';
import 'package:exam_03_185/models/patient_model.dart';
import 'package:exam_03_185/screens/display_screen.dart';
import 'package:exam_03_185/screens/form_screen.dart';
import 'package:exam_03_185/screens/user_management_screen.dart';

/// TabBar 2 แท็บ (Admin เห็นเพิ่มแท็บ "จัดการผู้ใช้") + ปุ่ม Sign Out บน AppBar
class MainNavigation extends StatelessWidget {
  final AppUser user;
  const MainNavigation({super.key, required this.user});

  // กล่องยืนยันก่อนออกจากระบบ
  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ออกจากระบบ'),
        content: Text('ต้องการออกจากบัญชี ${user.email} ใช่หรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ออกจากระบบ')),
        ],
      ),
    );
    if (ok == true) await FirebaseService().signOut();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      key: ValueKey(user.isAdmin), // สร้างใหม่เมื่อสิทธิ์เปลี่ยน (จำนวนแท็บเปลี่ยน)
      length: user.isAdmin ? 3 : 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TeleTriage (${user.role.toUpperCase()})'),
              Text(user.email, style: const TextStyle(fontSize: 12)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Sign Out',
              icon: const Icon(Icons.logout),
              onPressed: () => _confirmSignOut(context),
            ),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(icon: Icon(Icons.edit_note), text: 'บันทึกอาการ'),
              const Tab(icon: Icon(Icons.list_alt), text: 'บอร์ดผู้ป่วย'),
              if (user.isAdmin)
                const Tab(icon: Icon(Icons.manage_accounts), text: 'จัดการผู้ใช้'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const FormScreen(),
            DisplayScreen(user: user),
            if (user.isAdmin) UserManagementScreen(currentUser: user),
          ],
        ),
      ),
    );
  }
}
