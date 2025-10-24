import 'package:delivery_frontend/page/DashboardUser/receiver_shipments_list_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 🔹 Tabs (Sender + Receiver)
import 'package:delivery_frontend/page/DashboardUser/tab_home.dart';
import 'package:delivery_frontend/page/DashboardUser/tab_track.dart';
import 'package:delivery_frontend/page/DashboardUser/tab_create_order.dart';
import 'package:delivery_frontend/page/DashboardUser/tab_history.dart';
import 'package:delivery_frontend/page/DashboardUser/tab_profile.dart';

import 'package:delivery_frontend/page/login_user.dart';

class DashboardUserPage extends StatefulWidget {
  const DashboardUserPage({super.key});

  @override
  State<DashboardUserPage> createState() => _DashboardUserPageState();
}

class _DashboardUserPageState extends State<DashboardUserPage>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  late TabController _tabController;
  String? selectedOrderId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this); // ✅ มี 6 แท็บ

    // ✅ ถ้าเปลี่ยนแท็บอื่นให้รีเซ็ตการติดตาม
    _tabController.addListener(() {
      if (_tabController.index != 2 && selectedOrderId != null) {
        setState(() => selectedOrderId = null);
      }
    });
  }

  void goToTrackTab(String orderId) {
    setState(() {
      selectedOrderId = orderId;
      _tabController.animateTo(2); // ✅ index 2 = ติดตาม
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ออกจากระบบ"),
        content: const Text("คุณต้องการออกจากระบบใช่หรือไม่?"),
        actions: [
          TextButton(
            child: const Text("ยกเลิก", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child:
                const Text("ออกจากระบบ", style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginUserPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("กรุณาเข้าสู่ระบบใหม่อีกครั้ง")),
      );
    }

    final userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots();

    return StreamBuilder<DocumentSnapshot>(
      stream: userStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final userName = data['name'] ?? 'ผู้ใช้';
        final userImage = data['imageUrl'] ?? '';

        return Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: AppBar(
            backgroundColor: Colors.green.shade700,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  backgroundImage:
                      (userImage.isNotEmpty) ? NetworkImage(userImage) : null,
                  child: userImage.isEmpty
                      ? const Icon(Icons.person, color: Colors.green)
                      : null,
                ),
                const SizedBox(width: 10),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  tooltip: "ออกจากระบบ",
                  onPressed: _logout,
                ),
              ],
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.orangeAccent,
              indicatorWeight: 3,
              isScrollable: false,
              tabs: const [
                Tab(icon: Icon(Icons.send), text: "สินค้าที่ส่งออก"),
                Tab(icon: Icon(Icons.inventory_2), text: "สินค้าที่จะได้รับ"),
                Tab(icon: Icon(Icons.location_on), text: "ติดตาม"),
                Tab(icon: Icon(Icons.add_box), text: "สร้าง"),
                Tab(icon: Icon(Icons.history), text: "ประวัติ"),
                Tab(icon: Icon(Icons.person), text: "โปรไฟล์"),
              ],
            ),
          ),

          // 🔹 ส่วนแสดงเนื้อหาแต่ละแท็บ
          body: TabBarView(
            controller: _tabController,
            children: [
              // 🟢 สินค้าที่ส่งออก (Sender)
              HomeTab(onTrackPressed: goToTrackTab),

              // 🟣 สินค้าที่จะได้รับ (Receiver)
              ReceiverShipmentsListPage(onTrackPressed: goToTrackTab),

              // 🔵 ติดตาม (Track)
              TrackTab(selectedOrderId: selectedOrderId ?? ''),

              // 🟠 สร้างออเดอร์ใหม่
              CreateOrderForm(onOrderCreated: () {
                setState(() => _tabController.animateTo(0));
              }),

              // ⚫ ประวัติ
              const HistoryTab(),

              // ⚪ โปรไฟล์
              const ProfileTab(),
            ],
          ),
        );
      },
    );
  }
}
