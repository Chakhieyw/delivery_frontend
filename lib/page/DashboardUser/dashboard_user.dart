import 'package:delivery_frontend/page/DashboardUser/all_riders_map_page.dart';
import 'package:delivery_frontend/page/DashboardUser/tab_create_order.dart';
import 'package:delivery_frontend/page/DashboardUser/tab_history.dart';
import 'package:delivery_frontend/page/DashboardUser/tab_home.dart';
import 'package:delivery_frontend/page/DashboardUser/tab_profile.dart';
import 'package:delivery_frontend/page/DashboardUser/tab_track.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    // ✅ มี 5 แท็บ (Home, Track, Create, History, Profile)
    _tabController = TabController(length: 5, vsync: this);

    // ✅ รีเซ็ต selectedOrderId เมื่อออกจากแท็บติดตาม
    _tabController.addListener(() {
      if (_tabController.index != 1 && selectedOrderId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              selectedOrderId = null;
            });
          }
        });
      }
    });
  }

  // ✅ ฟังก์ชันเปลี่ยนไปแท็บติดตามพร้อมส่ง orderId
  void goToTrackTab(String orderId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          selectedOrderId = orderId;
          _tabController.animateTo(1); // ไปแท็บ "ติดตาม"
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("กรุณาเข้าสู่ระบบใหม่อีกครั้ง")),
      );
    }

    // ✅ ดึงข้อมูลผู้ใช้จาก Firestore
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
            backgroundColor: Colors.green,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                CircleAvatar(
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
                // 🔹 ปุ่มดูแผนที่รวมไรเดอร์ทั้งหมด
                IconButton(
                  icon: const Icon(Icons.map_outlined, color: Colors.white),
                  tooltip: "ดูไรเดอร์ทั้งหมดบนแผนที่",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AllRidersMapPage()),
                    );
                  },
                ),
                // 🔹 ปุ่มออกจากระบบ
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  tooltip: "ออกจากระบบ",
                  onPressed: () async {
                    await _auth.signOut();
                    if (!context.mounted) return;
                    Navigator.of(context, rootNavigator: true)
                        .pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginUserPage()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.orange,
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.home), text: "หน้าหลัก"),
                Tab(icon: Icon(Icons.location_on), text: "ติดตาม"),
                Tab(icon: Icon(Icons.add_box), text: "สร้าง"),
                Tab(icon: Icon(Icons.history), text: "ประวัติ"),
                Tab(icon: Icon(Icons.person), text: "โปรไฟล์"),
              ],
            ),
          ),

          // 🔹 เนื้อหาทุกแท็บ
          body: TabBarView(
            controller: _tabController,
            children: [
              // ✅ Home — แสดงรายการออเดอร์ล่าสุด
              HomeTab(onTrackPressed: goToTrackTab),

              // ✅ Track — แสดงสถานะของออเดอร์ที่เลือก
              TrackTab(
                selectedOrderId: selectedOrderId,
                orderId: '',
              ),

              // ✅ Create — สร้างออเดอร์ใหม่
              CreateOrderForm(
                onOrderCreated: () {
                  setState(() {
                    _tabController.animateTo(0); // กลับไปหน้า Home
                  });
                },
              ),

              // ✅ History — ประวัติออเดอร์ทั้งหมด
              const HistoryTab(),

              // ✅ Profile — ข้อมูลโปรไฟล์ผู้ใช้
              const ProfileTab(),
            ],
          ),
        );
      },
    );
  }
}
