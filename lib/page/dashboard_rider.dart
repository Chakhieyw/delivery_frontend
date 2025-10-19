import 'package:flutter/material.dart';
import 'package:delivery_frontend/page/profile_rider.dart';
import 'package:delivery_frontend/page/rider_pending_orders.dart';
import 'package:delivery_frontend/page/rider_delivering_page.dart';
import 'package:delivery_frontend/page/rider_history_page.dart';

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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text(
          "Delivery AppT&K",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "รอรับ"),
            Tab(text: "กำลังส่ง"),
            Tab(text: "ประวัติ"),
            Tab(text: "โปรไฟล์"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          RiderPendingOrdersPage(), // ✅ รอรับ
          RiderDeliveringPage(),
          RiderHistoryPage(),
          RiderProfilePage(),
        ],
      ),
    );
  }
}
