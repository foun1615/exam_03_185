import 'package:flutter/material.dart';
import 'package:exam_03_185/controllers/firebase_service.dart';
import 'package:exam_03_185/models/patient_model.dart';

/// หน้าจัดการผู้ใช้ (เฉพาะ Admin): แสดงอีเมลสมาชิก + ปรับระดับสิทธิ์
class UserManagementScreen extends StatelessWidget {
  final AppUser currentUser; // ผู้ที่ล็อกอินอยู่
  const UserManagementScreen({super.key, required this.currentUser});

  // กล่องยืนยันก่อนลบบัญชี
  Future<void> _confirmDelete(BuildContext context, AppUser u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบบัญชี'),
        content: Text(
            'ต้องการลบบัญชี ${u.email} ออกจากระบบใช่หรือไม่?\nผู้ใช้นี้จะเข้าใช้แอปไม่ได้อีก'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ลบ', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseService().deleteUser(u.uid);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('ลบบัญชี ${u.email} แล้ว')));
  }

  @override
  Widget build(BuildContext context) {
    final service = FirebaseService();
    return StreamBuilder<List<AppUser>>(
      stream: service.usersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snapshot.data!;
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final u = users[index];
            final isMe = u.uid == currentUser.uid;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(u.isAdmin ? Icons.admin_panel_settings : Icons.person),
                ),
                title: Text(u.email),
                subtitle: Text('${isMe ? '${u.name} (คุณ)' : u.name}\nUID: ${u.uid.length > 8 ? u.uid.substring(0, 8) : u.uid}...'),
                isThreeLine: true,
                // เปลี่ยนสิทธิ์ตัวเองไม่ได้ (กันไม่ให้ระบบไม่มี Admin เหลือ)
                trailing: isMe
                    ? Text(u.role.toUpperCase())
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButton<String>(
                            value: u.role == 'admin' ? 'admin' : 'operator',
                            items: const [
                              DropdownMenuItem(
                                  value: 'admin', child: Text('ADMIN')),
                              DropdownMenuItem(
                                  value: 'operator', child: Text('OPERATOR')),
                            ],
                            onChanged: (newRole) async {
                              if (newRole == null || newRole == u.role) return;
                              await service.updateRole(u.uid, newRole);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'เปลี่ยนสิทธิ์ ${u.email} เป็น ${newRole.toUpperCase()} แล้ว')));
                            },
                          ),
                          IconButton(
                            tooltip: 'ลบบัญชี',
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(context, u),
                          ),
                        ],
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
