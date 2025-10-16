import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AllRidersMapPage extends StatelessWidget {
  const AllRidersMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Stream<QuerySnapshot> ridersStream = FirebaseFirestore.instance
        .collection('deliveryRecords')
        .where('status', whereIn: ['ไรเดอร์รับงาน', 'ไรเดอร์รับสินค้าแล้ว'])
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text('📍 ตำแหน่งไรเดอร์ทั้งหมด'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: ridersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "ไม่มีไรเดอร์ที่กำลังจัดส่งสินค้าในขณะนี้",
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          final markers = <Marker>[];
          final List<LatLng> points = [];

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final lat = double.tryParse(data['riderLat']?.toString() ?? '') ?? 0;
            final lng = double.tryParse(data['riderLng']?.toString() ?? '') ?? 0;
            if (lat == 0 || lng == 0) continue;

            points.add(LatLng(lat, lng));

            markers.add(
              Marker(
                width: 60,
                height: 60,
                point: LatLng(lat, lng),
                child: GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        title: const Text("🚴 ข้อมูลไรเดอร์"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("ชื่อ: ${data['riderName'] ?? 'ไม่ระบุ'}"),
                            Text("เบอร์โทร: ${data['riderPhone'] ?? '-'}"),
                            Text("สถานะ: ${data['status'] ?? '-'}"),
                            const SizedBox(height: 10),
                            Text(
                              data['status'] == 'ไรเดอร์รับงาน'
                                  ? "🟡 กำลังมารับของ"
                                  : "🟢 กำลังจัดส่งสินค้า",
                              style: TextStyle(
                                color: data['status'] == 'ไรเดอร์รับงาน'
                                    ? Colors.orange
                                    : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("ปิด"),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Icon(Icons.delivery_dining,
                      color: Colors.green, size: 40),
                ),
              ),
            );
          }

          // 🔹 ถ้าไม่มีพิกัดเลย
          if (points.isEmpty) {
            return const Center(
              child: Text(
                "ยังไม่มีไรเดอร์ที่แชร์ตำแหน่ง",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          // 🔹 คำนวณตำแหน่งเฉลี่ยของไรเดอร์ทั้งหมด
          final avgLat = points.map((p) => p.latitude).reduce((a, b) => a + b) /
              points.length;
          final avgLng = points.map((p) => p.longitude).reduce((a, b) => a + b) /
              points.length;

          return FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(avgLat, avgLng),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.delivery.app',
              ),
              MarkerLayer(markers: markers),
            ],
          );
        },
      ),
    );
  }
}
