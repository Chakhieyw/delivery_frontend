import 'package:delivery_frontend/page/DashboardRider/rider_history_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:delivery_frontend/page/select_role.dart';
import 'package:delivery_frontend/page/rider_pending_orders.dart';
import 'package:delivery_frontend/page/rider_delivering_page.dart';
import 'package:delivery_frontend/page/profile_rider.dart';

class DashboardRiderPage extends StatefulWidget {
  const DashboardRiderPage({super.key});

  @override
  State<DashboardRiderPage> createState() => _DashboardRiderPageState();
}

class _DashboardRiderPageState extends State<DashboardRiderPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  /// ✅ ฟังก์ชันออกจากระบบ
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

    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SelectRolePage()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ออกจากระบบไม่สำเร็จ: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFF4CAF50),
          title: const Text(
            "Delivery AppT&K",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: "ออกจากระบบ",
              onPressed: _logout,
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "รอรับ"),
              Tab(text: "กำลังส่ง"),
              Tab(text: "ประวัติ"),
              Tab(text: "โปรไฟล์"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            RiderPendingOrdersPage(),
            RiderDeliveringPage(),
            RiderHistoryPage(),
            RiderProfilePage(),
          ],
        ),
      ),
    );
  }
}
