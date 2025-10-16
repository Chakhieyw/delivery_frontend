import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class TrackTab extends StatelessWidget {
  final String? selectedOrderId; // ✅ รับ orderId ที่เลือกจากหน้า Home
  const TrackTab({super.key, required this.selectedOrderId, required String orderId});

  int _getStatusStep(String status) {
    switch (status) {
      case 'รอไรเดอร์มารับสินค้า':
        return 0;
      case 'ไรเดอร์รับงาน':
        return 1;
      case 'ไรเดอร์รับสินค้าแล้ว':
        return 2;
      case 'ไรเดอร์นำส่งสินค้าแล้ว':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("กรุณาเข้าสู่ระบบใหม่อีกครั้ง"));
    }

    // ✅ ถ้าไม่มี order ที่เลือก (เช่น ยังไม่ได้กดติดตาม)
    if (selectedOrderId == null) {
      return const Center(
        child: Text(
          "ยังไม่ได้เลือกออเดอร์ที่ต้องติดตาม",
          style: TextStyle(color: Colors.black54, fontSize: 16),
        ),
      );
    }

    // ✅ ดึงข้อมูลเฉพาะออเดอร์ที่เลือกแบบเรียลไทม์
    final orderStream = FirebaseFirestore.instance
        .collection('deliveryRecords')
        .doc(selectedOrderId)
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: StreamBuilder<DocumentSnapshot>(
        stream: orderStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("ไม่พบข้อมูลออเดอร์นี้"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status'] ?? 'รอไรเดอร์มารับสินค้า';
          final step = _getStatusStep(status);
          final riderName = data['riderName'] ?? 'ยังไม่มีไรเดอร์รับงาน';
          final riderPhone = data['riderPhone'] ?? '-';
          final riderBike = data['riderBike'] ?? '-';
          final riderLat =
              double.tryParse(data['riderLat']?.toString() ?? '') ?? 0;
          final riderLng =
              double.tryParse(data['riderLng']?.toString() ?? '') ?? 0;

          final hasMap = step == 1 || step == 2;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("สถานะการจัดส่ง",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                _buildTimeline(step),
                const SizedBox(height: 25),

                // 🔹 แผนที่ติดตามไรเดอร์ (เฉพาะสถานะ 2,3)
                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: hasMap && riderLat != 0 && riderLng != 0
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: LatLng(riderLat, riderLng),
                              initialZoom: 14,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.delivery.app',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(riderLat, riderLng),
                                    width: 60,
                                    height: 60,
                                    child: const Icon(Icons.delivery_dining,
                                        color: Colors.green, size: 40),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.map, color: Colors.grey, size: 40),
                              SizedBox(height: 6),
                              Text("แผนที่ติดตามตำแหน่งไรเดอร์",
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 20),

                // 🔹 กล่องข้อมูลไรเดอร์
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.person, color: Colors.green),
                          SizedBox(width: 8),
                          Text("นักไรเดอร์",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("ชื่อ: $riderName",
                          style: const TextStyle(fontSize: 14)),
                      Text("เบอร์โทร: $riderPhone",
                          style: const TextStyle(fontSize: 14)),
                      Text("รถจักรยานยนต์: $riderBike",
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 10),
                      Text(
                        step == 0
                            ? "🕓 รอไรเดอร์มารับสินค้า"
                            : step == 1
                                ? "🏍️ ไรเดอร์กำลังเดินทางมารับของ"
                                : step == 2
                                    ? "📦 ไรเดอร์กำลังนำส่งสินค้า"
                                    : "✅ ส่งสินค้าเรียบร้อยแล้ว",
                        style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 🔸 ฟังก์ชันสร้าง Timeline 4 ขั้น
  Widget _buildTimeline(int step) {
    final steps = [
      "สร้างออเดอร์สำเร็จ",
      "ไรเดอร์รับงานแล้ว",
      "กำลังจัดส่งสินค้า",
      "ส่งสำเร็จ",
    ];

    return Column(
      children: List.generate(steps.length, (index) {
        final isActive = index <= step;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor:
                      isActive ? Colors.green : Colors.grey.shade300,
                  child: Icon(Icons.check,
                      size: 14,
                      color: isActive ? Colors.white : Colors.transparent),
                ),
                if (index < steps.length - 1)
                  Container(
                    width: 2,
                    height: 35,
                    color: isActive ? Colors.green : Colors.grey.shade300,
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                steps[index],
                style: TextStyle(
                  color: isActive ? Colors.green : Colors.grey,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
