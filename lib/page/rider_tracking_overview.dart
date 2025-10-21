import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RiderTrackingOverview extends StatelessWidget {
  const RiderTrackingOverview({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("ดูตำแหน่งไรเดอร์ทั้งหมด"),
          backgroundColor: Colors.green),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('deliveryRecords').where(
            'status',
            whereIn: ['ไรเดอร์รับงาน', 'ไรเดอร์รับสินค้าแล้ว']).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text("ไม่มีไรเดอร์ที่กำลังจัดส่งในขณะนี้"));
          }

          final docs = snapshot.data!.docs;
          final markers = docs
              .map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final lat = (d['riderLat'] ?? 0).toDouble();
                final lng = (d['riderLng'] ?? 0).toDouble();
                final name = d['riderName'] ?? 'ไรเดอร์ไม่ทราบชื่อ';
                if (lat == 0 || lng == 0) return null;
                return Marker(
                  point: LatLng(lat, lng),
                  width: 70,
                  height: 70,
                  child: Column(
                    children: [
                      const Icon(Icons.delivery_dining,
                          color: Colors.green, size: 40),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(name, style: const TextStyle(fontSize: 10)),
                      ),
                    ],
                  ),
                );
              })
              .whereType<Marker>()
              .toList();

          return FlutterMap(
            options: MapOptions(
              initialCenter: markers.isNotEmpty
                  ? markers.first.point
                  : const LatLng(13.7563, 100.5018),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.kongphob.deliveryapp',
              ),
              MarkerLayer(markers: markers),
            ],
          );
        },
      ),
    );
  }
}
