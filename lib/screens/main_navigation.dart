import 'package:flutter/material.dart';
import 'package:exam_03_185/controllers/firebase_service.dart';
import 'package:exam_03_185/models/patient_model.dart';
import 'package:exam_03_185/screens/display_screen.dart';
import 'package:exam_03_185/screens/form_screen.dart';

/// TabBar 2 แท็บ + ปุ่ม Sign Out บน AppBar
class MainNavigation extends StatelessWidget {
  final AppUser user;
  const MainNavigation({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('TeleTriage (${user.role.toUpperCase()})'),
          actions: [
            IconButton(
              tooltip: 'Sign Out',
              icon: const Icon(Icons.logout),
              onPressed: () => FirebaseService().signOut(),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.edit_note), text: 'บันทึกอาการ'),
              Tab(icon: Icon(Icons.list_alt), text: 'บอร์ดผู้ป่วย'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const FormScreen(),
            DisplayScreen(user: user),
          ],
        ),
      ),
    );
  }
}
