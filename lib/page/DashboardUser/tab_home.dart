import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text("กรุณาเข้าสู่ระบบใหม่อีกครั้ง"));
    }

    // ✅ ดึงข้อมูลจาก collection 'deliveryRecords'
    final orderStream = FirebaseFirestore.instance
        .collection('deliveryRecords')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: StreamBuilder<QuerySnapshot>(
        stream: orderStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "ยังไม่มีออเดอร์ในระบบ",
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
            );
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index].data() as Map<String, dynamic>;
              final pickup = order['pickupAddress'] ?? '-';
              final drop = order['dropAddress'] ?? '-';
              final price = order['price']?.toString() ?? '0';
              final status = order['status'] ?? 'รอไรเดอร์รับงาน';
              final createdAt = (order['createdAt'] as Timestamp?)?.toDate();
              final orderNumber = '#Orders-${index + 1}';

              return _buildOrderCard(
                context: context,
                orderNumber: orderNumber,
                pickup: pickup,
                drop: drop,
                price: price,
                status: status,
                createdAt: createdAt,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard({
    required BuildContext context,
    required String orderNumber,
    required String pickup,
    required String drop,
    required String price,
    required String status,
    DateTime? createdAt,
  }) {
    Color statusColor;
    Color buttonColor;
    String buttonText;

    switch (status) {
      case "กำลังจัดส่ง":
        statusColor = Colors.orange;
        buttonColor = Colors.orange;
        buttonText = "ติดตาม";
        break;
      case "ส่งสำเร็จ":
        statusColor = Colors.grey;
        buttonColor = Colors.grey.shade400;
        buttonText = "ส่งสำเร็จ";
        break;
      default:
        statusColor = Colors.green;
        buttonColor = Colors.green;
        buttonText = "ติดตาม";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 หัวการ์ด
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "ออเดอร์ $orderNumber",
                style: const TextStyle(
                    color: Colors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(status,
                    style: TextStyle(color: statusColor, fontSize: 12)),
              ),
            ],
          ),

          if (createdAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "📅 ${createdAt.day}/${createdAt.month}/${createdAt.year} • ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}",
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),

          const SizedBox(height: 10),

          // 🔸 จุดรับ / ส่ง
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(Icons.store, color: Colors.green.shade700, size: 22),
                  Container(
                    width: 2,
                    height: 25,
                    color: Colors.green.shade400,
                  ),
                  Icon(Icons.location_on,
                      color: Colors.green.shade700, size: 22),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("จุดรับสินค้า",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800)),
                    Text(pickup,
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Text("จุดส่งสินค้า",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800)),
                    Text(drop,
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 🔹 ราคา + ปุ่ม
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("฿$price",
                  style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              ElevatedButton(
                onPressed: status == "ส่งสำเร็จ"
                    ? null
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("ระบบติดตามจะมีในเวอร์ชันถัดไป 😄"),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(100, 38),
                ),
                child: Text(buttonText,
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
