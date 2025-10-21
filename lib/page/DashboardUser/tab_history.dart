import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return DateFormat('dd MMM yyyy, HH:mm น.', 'th').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text("กรุณาเข้าสู่ระบบอีกครั้ง"));
    }

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
              child: Text("ยังไม่มีประวัติการสั่งซื้อ"),
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
              final status = order['status'] ?? 'ไม่ทราบสถานะ';
              final createdAt = _formatDate(order['createdAt']);
              final orderNumber = '#Orders-${index + 1}';

              Color statusColor;
              switch (status) {
                case 'ส่งสำเร็จ':
                  statusColor = Colors.grey;
                  break;
                case 'กำลังจัดส่ง':
                  statusColor = Colors.orange;
                  break;
                default:
                  statusColor = Colors.green;
              }

              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔹 หัวข้อ
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "ออเดอร์ $orderNumber",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("วันที่สร้าง: $createdAt",
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade700)),

                      const Divider(height: 20),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Icon(Icons.store,
                                  color: Colors.green.shade700, size: 22),
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
                                        fontSize: 14,
                                        color: Colors.grey.shade700)),
                                const SizedBox(height: 8),
                                Text("จุดส่งสินค้า",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800)),
                                Text(drop,
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700)),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          "฿$price",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
