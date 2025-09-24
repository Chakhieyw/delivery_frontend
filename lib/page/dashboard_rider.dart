import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Delivery AppT&K",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color.fromARGB(255, 255, 255, 255),
          unselectedLabelColor: const Color.fromARGB(255, 255, 255, 255),
          indicatorColor: Colors.green,
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
        children: [
          _buildWaitingOrders(),
          const Center(child: Text("🚚 อยู่ระหว่างจัดส่ง")),
          const Center(child: Text("📜 ประวัติการจัดส่ง")),
          const Center(child: Text("👤 โปรไฟล์ผู้ใช้")),
        ],
      ),
    );
  }

  Widget _buildWaitingOrders() {
    final orders = [
      {
        "id": "D-1",
        "pickup": "123 ถนนสุขสบาย, กรุงเทพ",
        "dropoff": "456 ถนนเจริญกรุง, กรุงเทพ",
        "price": 150
      },
      {
        "id": "D-2",
        "pickup": "999 ถนนลาดพร้าว, กรุงเทพ",
        "dropoff": "888 ถนนสุขุมวิท, กรุงเทพ",
        "price": 200
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.symmetric(vertical: 8),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("ออเดอร์ #${order['id']}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.green)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.store, color: Colors.green),
                    const SizedBox(width: 6),
                    Expanded(child: Text("จุดรับสินค้า\n${order['pickup']}")),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.green),
                    const SizedBox(width: 6),
                    Expanded(child: Text("จุดส่งสินค้า\n${order['dropoff']}")),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("฿${order['price']} บาท",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.green)),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text("📌 รับงาน #${order['id']} แล้ว")));
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                      child: const Text("รับงาน"),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
