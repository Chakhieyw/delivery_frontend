import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class TrackTab extends StatefulWidget {
  final String? selectedOrderId;
  const TrackTab(
      {super.key, required this.selectedOrderId, required String orderId});

  @override
  State<TrackTab> createState() => _TrackTabState();
}

class _TrackTabState extends State<TrackTab> {
  LatLng? _previousRiderPosition;

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

    if (widget.selectedOrderId == null) {
      return const Center(
        child: Text(
          "ยังไม่ได้เลือกออเดอร์ที่ต้องติดตาม",
          style: TextStyle(color: Colors.black54, fontSize: 16),
        ),
      );
    }

    final orderStream = FirebaseFirestore.instance
        .collection('deliveryRecords')
        .doc(widget.selectedOrderId)
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: StreamBuilder<DocumentSnapshot>(
        stream: orderStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("ไม่พบข้อมูลออเดอร์นี้"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status'] ?? 'รอไรเดอร์มารับสินค้า';
          final step = _getStatusStep(status);
          final riderName = data['riderName'] ?? 'ยังไม่มีไรเดอร์รับงาน';
          final riderPhone = data['riderPhone'] ?? '-';
          final riderBike = data['riderBike'] ?? '-';
          final pickupLatLng = _parseLatLng(data['pickupLatLng']);
          final dropLatLng = _parseLatLng(data['dropLatLng']);
          final riderLat =
              double.tryParse(data['riderLat']?.toString() ?? '') ?? 0;
          final riderLng =
              double.tryParse(data['riderLng']?.toString() ?? '') ?? 0;
          final currentRiderPos = LatLng(riderLat, riderLng);

          // เก็บตำแหน่งก่อนหน้าเพื่อทำ animation
          _previousRiderPosition ??= currentRiderPos;

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
                Container(
                  height: 250,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: pickupLatLng == null || dropLatLng == null
                      ? const Center(
                          child: Text("ไม่มีข้อมูลแผนที่"),
                        )
                      : FlutterMap(
                          options: MapOptions(
                            initialCenter: pickupLatLng,
                            initialZoom: 13,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.kongphob.deliveryapp',
                            ),
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: [pickupLatLng, dropLatLng],
                                  strokeWidth: 4,
                                  color: Colors.green,
                                ),
                              ],
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: pickupLatLng,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(Icons.store,
                                      color: Colors.green, size: 30),
                                ),
                                Marker(
                                  point: dropLatLng,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(Icons.location_on,
                                      color: Colors.red, size: 30),
                                ),
                              ],
                            ),
                            // 🔹 Marker ไรเดอร์พร้อม Animation
                            if (riderLat != 0 && riderLng != 0)
                              TweenAnimationBuilder<LatLng>(
                                tween: Tween<LatLng>(
                                  begin: _previousRiderPosition!,
                                  end: currentRiderPos,
                                ),
                                duration: const Duration(seconds: 2),
                                builder: (context, value, _) {
                                  _previousRiderPosition = value;
                                  return MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: value,
                                        width: 60,
                                        height: 60,
                                        child: const Icon(
                                          Icons.delivery_dining,
                                          color: Colors.orange,
                                          size: 40,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 20),
                Container(
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

  LatLng? _parseLatLng(String? raw) {
    if (raw == null || !raw.contains(",")) return null;
    try {
      final parts = raw.split(",");
      return LatLng(double.parse(parts[0]), double.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

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
            Text(
              steps[index],
              style: TextStyle(
                color: isActive ? Colors.green : Colors.grey,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }
}
