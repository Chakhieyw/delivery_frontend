import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SenderAllShipmentsMapPage extends StatefulWidget {
  const SenderAllShipmentsMapPage({super.key});

  @override
  State<SenderAllShipmentsMapPage> createState() =>
      _SenderAllShipmentsMapPageState();
}

class _SenderAllShipmentsMapPageState extends State<SenderAllShipmentsMapPage> {
  final _auth = FirebaseAuth.instance;
  final MapController _mapController = MapController();

  LatLng? _focusedRiderPos;
  String? _focusedRiderId;
  bool _autoZoomDone = false;

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("กรุณาเข้าสู่ระบบใหม่อีกครั้ง")),
      );
    }

    final shipmentsStream = FirebaseFirestore.instance
        .collection('deliveryRecords')
        .where('userId', isEqualTo: user.uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text("🌍 แผนที่รวมทุก Shipment ของฉัน",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: shipmentsStream,
        builder: (context, shipmentSnap) {
          if (shipmentSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!shipmentSnap.hasData || shipmentSnap.data!.docs.isEmpty) {
            return const Center(child: Text("ยังไม่มีรายการจัดส่งในระบบ"));
          }

          final shipments = shipmentSnap.data!.docs;
          final riderIds = shipments
              .map((d) => (d.data() as Map<String, dynamic>)['riderId'])
              .where((id) => id != null && id.toString().isNotEmpty)
              .cast<String>()
              .toList();

          final ridersStream = FirebaseFirestore.instance
              .collection('riders')
              .where(FieldPath.documentId,
                  whereIn: riderIds.isEmpty ? ['dummy'] : riderIds)
              .snapshots();

          return StreamBuilder<QuerySnapshot>(
            stream: ridersStream,
            builder: (context, riderSnap) {
              final markers = <Marker>[];
              final polylines = <Polyline>[];
              final allPoints = <LatLng>[];
              final riderList = <Map<String, dynamic>>[];

              // ✅ pickup/drop markers
              for (var doc in shipments) {
                final data = doc.data() as Map<String, dynamic>;
                final pickup = _parseLatLng(data['pickupLatLng']);
                final drop = _parseLatLng(data['dropLatLng']);
                if (pickup != null) {
                  markers.add(Marker(
                    point: pickup,
                    width: 36,
                    height: 36,
                    child:
                        const Icon(Icons.store, color: Colors.green, size: 32),
                  ));
                  allPoints.add(pickup);
                }
                if (drop != null) {
                  markers.add(Marker(
                    point: drop,
                    width: 36,
                    height: 36,
                    child: const Icon(Icons.location_on,
                        color: Colors.red, size: 34),
                  ));
                  allPoints.add(drop);
                }
                if (pickup != null && drop != null) {
                  polylines.add(Polyline(
                    points: [pickup, drop],
                    strokeWidth: 3,
                    color: Colors.green.withOpacity(0.4),
                  ));
                }
              }

              // ✅ riders markers
              if (riderSnap.hasData) {
                for (var r in riderSnap.data!.docs) {
                  final rd = r.data() as Map<String, dynamic>;
                  final lat = (rd['lat'] ?? 0.0).toDouble();
                  final lng = (rd['lng'] ?? 0.0).toDouble();
                  final name = rd['name'] ?? 'Rider';
                  final id = r.id;

                  if (lat != 0.0 && lng != 0.0) {
                    final pos = LatLng(lat, lng);
                    riderList.add({'id': id, 'name': name, 'pos': pos});
                    allPoints.add(pos);

                    markers.add(Marker(
                      point: pos,
                      width: 44,
                      height: 44,
                      child: Tooltip(
                        message: "ไรเดอร์: $name",
                        child: Icon(
                          Icons.delivery_dining,
                          color: id == _focusedRiderId
                              ? Colors.orange
                              : Colors.blue,
                          size: 38,
                        ),
                      ),
                    ));

                    // 🎯 Auto follow if this is the focused rider
                    if (_focusedRiderId == id) {
                      _focusCameraOnRider(pos);
                    }
                  }
                }
              }

              if (allPoints.isEmpty) {
                return const Center(
                    child: Text("ไม่พบตำแหน่งจัดส่งสินค้าในระบบ"));
              }

              final avgLat =
                  allPoints.map((p) => p.latitude).reduce((a, b) => a + b) /
                      allPoints.length;
              final avgLng =
                  allPoints.map((p) => p.longitude).reduce((a, b) => a + b) /
                      allPoints.length;
              final center = LatLng(avgLat, avgLng);

              return Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 12,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.delivery.app',
                      ),
                      PolylineLayer(polylines: polylines),
                      MarkerLayer(markers: markers),
                    ],
                  ),

                  // 🔹 Legend
                  Positioned(
                    bottom: 20,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.store, color: Colors.green, size: 20),
                          SizedBox(width: 4),
                          Text("จุดรับ", style: TextStyle(fontSize: 12)),
                          SizedBox(width: 12),
                          Icon(Icons.location_on, color: Colors.red, size: 20),
                          SizedBox(width: 4),
                          Text("จุดส่ง", style: TextStyle(fontSize: 12)),
                          SizedBox(width: 12),
                          Icon(Icons.delivery_dining,
                              color: Colors.blue, size: 20),
                          SizedBox(width: 4),
                          Text("ไรเดอร์", style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),

                  // 🔹 ปุ่มเลือกไรเดอร์
                  Positioned(
                    bottom: 20,
                    right: 16,
                    child: FloatingActionButton(
                      backgroundColor: Colors.green,
                      child: const Icon(Icons.search, color: Colors.white),
                      onPressed: () => _showRiderSelector(context, riderList),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // 🎯 แสดง Bottom Sheet เลือกไรเดอร์
  void _showRiderSelector(
      BuildContext context, List<Map<String, dynamic>> riders) {
    if (riders.isEmpty) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              "เลือกไรเดอร์ที่ต้องการติดตาม",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...riders.map((r) {
              return ListTile(
                leading: const Icon(Icons.delivery_dining, color: Colors.blue),
                title: Text(r['name']),
                trailing: _focusedRiderId == r['id']
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: () {
                  setState(() {
                    _focusedRiderId = r['id'];
                    _focusedRiderPos = r['pos'];
                    _autoZoomDone = false;
                  });
                  Navigator.pop(context);
                },
              );
            }),
            if (_focusedRiderId != null)
              ListTile(
                leading: const Icon(Icons.close, color: Colors.red),
                title: const Text("ยกเลิกการติดตาม"),
                onTap: () {
                  setState(() {
                    _focusedRiderId = null;
                    _focusedRiderPos = null;
                  });
                  Navigator.pop(context);
                },
              ),
          ],
        );
      },
    );
  }

  void _focusCameraOnRider(LatLng pos) {
    if (_focusedRiderPos == null ||
        pos.latitude != _focusedRiderPos!.latitude ||
        pos.longitude != _focusedRiderPos!.longitude) {
      _focusedRiderPos = pos;
      if (!_autoZoomDone) {
        _mapController.move(pos, 15.5);
        _autoZoomDone = true;
      } else {
        _mapController.move(pos, _mapController.camera.zoom);
      }
    }
  }

  static LatLng? _parseLatLng(String? raw) {
    if (raw == null || !raw.contains(",")) return null;
    try {
      final parts = raw.split(",");
      return LatLng(double.parse(parts[0]), double.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }
}
