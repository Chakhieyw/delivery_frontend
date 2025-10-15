import 'package:delivery_frontend/page/DashboardUser/tab_home.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:delivery_frontend/page/login_user.dart';
// import แท็บต่าง ๆ
import 'tab_create_order.dart';
import 'tab_history.dart';
import 'tab_profile.dart';
import 'tab_track.dart';

class DashboardUserPage extends StatefulWidget {
  const DashboardUserPage({super.key});

  @override
  State<DashboardUserPage> createState() => _DashboardUserPageState();
}

class _DashboardUserPageState extends State<DashboardUserPage>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
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
          body: TabBarView(
            controller: _tabController,
            children: [
              HomeTab(),
              TrackTab(),
              CreateOrderForm(
                onOrderCreated: () {
                  setState(() {
                    _tabController.animateTo(0);
                  });
                },
              ),
              HistoryTab(),
              ProfileTab(),
            ],
          ),
        );
      },
    );
  }
}
