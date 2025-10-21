import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RiderHistoryDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final String orderId;

  const RiderHistoryDetailPage({
    super.key,
    required this.data,
    required this.orderId,
  });

  LatLng? _parseLatLng(String? raw) {
    if (raw == null || !raw.contains(',')) return null;
    try {
      final parts = raw.split(',');
      return LatLng(double.parse(parts[0]), double.parse(parts[1]));
    } catch (e) {
      return null;
    }
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '-';
    try {
      final date = ts.toDate();
      return "${date.day}/${date.month}/${date.year} "
          "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickupAddress = data['pickupAddress'] ?? '-';
    final dropAddress = data['dropAddress'] ?? '-';
    final details = data['details'] ?? '-';
    final price = data['price'] ?? 0;
    final status = data['status'] ?? '-';
    final pickupProof = data['pickupProofUrl'] ?? '';
    final deliveryProof = data['deliveryProofUrl'] ?? '';
    final pickupLatLng = _parseLatLng(data['pickupLatLng']);
    final dropLatLng = _parseLatLng(data['dropLatLng']);
    final acceptedAt = data['acceptedAt'];
    final updatedAt = data['updatedAt'];

    Duration? deliveryDuration;
    if (acceptedAt != null && updatedAt != null) {
      try {
        final start = acceptedAt.toDate();
        final end = updatedAt.toDate();
        deliveryDuration = end.difference(start);
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        title: Text(
          "รายละเอียดออเดอร์ #$orderId",
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 ข้อมูลออเดอร์หลัก
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("สถานะ: $status",
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green)),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.store, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text("จุดรับสินค้า\n$pickupAddress",
                            style: const TextStyle(fontSize: 14)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text("จุดส่งสินค้า\n$dropAddress",
                            style: const TextStyle(fontSize: 14)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text("รายละเอียดเพิ่มเติม: $details",
                      style: const TextStyle(fontSize: 14)),
                  const Divider(height: 20),
                  Text("ราคา: ฿$price บาท",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green)),
                  const SizedBox(height: 8),
                  Text("เริ่มงานเมื่อ: ${_formatDate(acceptedAt)}",
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  Text("ส่งสำเร็จเมื่อ: ${_formatDate(updatedAt)}",
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  if (deliveryDuration != null)
                    Text(
                      "ใช้เวลาส่งทั้งหมด: "
                      "${deliveryDuration.inMinutes} นาที",
                      style:
                          const TextStyle(color: Colors.blueGrey, fontSize: 13),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 🗺️ แผนที่เส้นทาง
            if (pickupLatLng != null && dropLatLng != null)
              Container(
                height: 240,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: pickupLatLng,
                      initialZoom: 13,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [pickupLatLng, dropLatLng],
                            color: Colors.green,
                            strokeWidth: 4,
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
                                color: Colors.green, size: 35),
                          ),
                          Marker(
                            point: dropLatLng,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.location_on,
                                color: Colors.red, size: 35),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // 🖼️ รูปหลักฐาน
            if (pickupProof.isNotEmpty || deliveryProof.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("หลักฐานการจัดส่ง:",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (pickupProof.isNotEmpty)
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                pickupProof,
                                height: 140,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                        if (deliveryProof.isNotEmpty)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  deliveryProof,
                                  height: 140,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.broken_image),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
