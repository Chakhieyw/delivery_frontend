import 'package:delivery_frontend/page/login_user.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';


class DashboardUserPage extends StatelessWidget {
  const DashboardUserPage({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginUserPage()),
      (route) => false, // ลบทุกหน้าออกจาก stack
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.green,
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Colors.green, size: 30),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "นาย ค โต้",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                 
                  IconButton(
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout, color: Colors.white),
                    tooltip: "ออกจากระบบ",
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      // Body
      body: Column(
        children: [
          // 🔹 Navigation Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home, "หน้าหลัก", true),
                _buildNavItem(Icons.location_on, "ติดตาม", false),
                _buildNavItem(Icons.add_box, "สร้างออเดอร์", false),
                _buildNavItem(Icons.history, "ประวัติ", false),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.grey),

          // 🔹 Orders List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _buildOrderCard("#D-1", "จุดรับสินค้า", "123 ถนนสุขาภิบาล, กรุงเทพ",
                    "จุดส่งสินค้า", "456 ถนนสาทร, กรุงเทพ", "กำลังจัดส่ง", 150, true),
                _buildOrderCard("#D-2", "จุดรับสินค้า", "123 ถนนสุขาภิบาล, กรุงเทพ",
                    "จุดส่งสินค้า", "456 ถนนสาทร, กรุงเทพ", "ส่งสำเร็จ", 150, false),
                _buildOrderCard("#D-3", "จุดรับสินค้า", "123 ถนนสุขาภิบาล, กรุงเทพ",
                    "จุดส่งสินค้า", "456 ถนนสาทร, กรุงเทพ", "ส่งสำเร็จ", 150, false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 Nav Item Widget
  Widget _buildNavItem(IconData icon, String label, bool active) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: active ? Colors.green : Colors.grey),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: active ? Colors.green : Colors.grey,
          ),
        ),
      ],
    );
  }

  // 🔹 Order Card Widget
  Widget _buildOrderCard(
    String orderId,
    String pickupLabel,
    String pickupAddress,
    String dropLabel,
    String dropAddress,
    String status,
    int price,
    bool canTrack,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order ID + Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "ออเดอร์ $orderId",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.green,
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: status == "กำลังจัดส่ง" ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Pickup
            Row(
              children: [
                const Icon(Icons.store, color: Colors.green, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "$pickupLabel\n$pickupAddress",
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Drop
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.green, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "$dropLabel\n$dropAddress",
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Price + Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "฿$price.00",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green,
                  ),
                ),
                ElevatedButton(
                  onPressed: canTrack ? () {} : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        canTrack ? Colors.orange : Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    canTrack ? "ติดตาม" : "ส่งสำเร็จ",
                    style: TextStyle(
                      color: canTrack ? Colors.white : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
