import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_frontend/page/DashboardUser/tab_track.dart';

class HomeTab extends StatelessWidget {
  final Function(String orderId)? onTrackPressed;
  const HomeTab({super.key, this.onTrackPressed});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text("กรุณาเข้าสู่ระบบใหม่อีกครั้ง"));
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
              child: Text("ยังไม่มีออเดอร์ในระบบ",
                  style: TextStyle(color: Colors.black54, fontSize: 16)),
            );
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final doc = orders[index];
              final pickup = doc['pickupAddress'] ?? '-';
              final drop = doc['dropAddress'] ?? '-';
              final price = doc['price']?.toString() ?? '0';
              final status = doc['status'] ?? 'รอไรเดอร์รับงาน';
              final createdAt = (doc['createdAt'] as Timestamp?)?.toDate();
              final orderId = doc.id;

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
                          "ออเดอร์ #${index + 1}",
                          style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                                color: Colors.green, fontSize: 12),
                          ),
                        ),
                      ],
                    ),

                    if (createdAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "📅 ${createdAt.day}/${createdAt.month}/${createdAt.year} • ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}",
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
                      ),

                    const SizedBox(height: 10),

                    // 🔸 จุดรับ / ส่ง
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

                    // 🔹 ราคา + ปุ่มติดตาม
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "฿$price",
                          style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            // ✅ แทนที่จะเปิดหน้าใหม่ เราจะส่ง orderId กลับไปยัง Dashboard
                            if (orderId.isNotEmpty) {
                              // เรียก callback ที่ได้จาก DashboardUserPage
                              onTrackPressed?.call(orderId);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text("ติดตาม",
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
