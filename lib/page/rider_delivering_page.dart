import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class RiderDeliveringPage extends StatefulWidget {
  const RiderDeliveringPage({super.key});

  @override
  State<RiderDeliveringPage> createState() => _RiderDeliveringPageState();
}

class _RiderDeliveringPageState extends State<RiderDeliveringPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _picker = ImagePicker();
  final MapController _mapController = MapController();

  File? _imageFile;
  bool _isUploading = false;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndStartTracking();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  // ✅ ขอ permission ก่อนเริ่มติดตาม
  Future<void> _checkPermissionAndStartTracking() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint("❌ Location permission denied");
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      debugPrint("❌ Location permission permanently denied");
      return;
    }
    _startUpdatingLocation();
  }

  // ✅ อัปเดตพิกัดไรเดอร์เรียลไทม์ทุก 5 วิ
  void _startUpdatingLocation() {
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final rider = _auth.currentUser;
      if (rider == null) return;

      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 10),
        );

        // อัปเดตตำแหน่งใน Firestore
        await _firestore.collection('riders').doc(rider.uid).update({
          'lat': pos.latitude,
          'lng': pos.longitude,
        });

        // อัปเดตทุกออเดอร์ที่ไรเดอร์ทำอยู่
        final activeOrders = await _firestore
            .collection('deliveryRecords')
            .where('riderId', isEqualTo: rider.uid)
            .where('status', whereIn: [
          'ไรเดอร์รับสินค้าแล้ว',
          'ไรเดอร์นำส่งสินค้าแล้ว',
          'ไรเดอร์รับงาน'
        ]).get();

        for (final doc in activeOrders.docs) {
          await doc.reference.update({
            'riderLat': pos.latitude,
            'riderLng': pos.longitude,
          });
        }

        // ✅ ให้กล้องขยับตามตำแหน่งไรเดอร์
        if (mounted) {
          _mapController.move(
              LatLng(pos.latitude, pos.longitude), _mapController.camera.zoom);
        }
      } catch (e) {
        debugPrint("⚠️ Location update failed: $e");
      }
    });
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

  Future<void> _pickImage({required bool fromCamera}) async {
    final picked = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('ถ่ายภาพด้วยกล้อง'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(fromCamera: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('เลือกรูปจากเครื่อง'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(fromCamera: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _uploadProof(String orderId) async {
    if (_imageFile == null) return null;
    setState(() => _isUploading = true);
    try {
      final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
      final ref = FirebaseStorage.instance
          .ref()
          .child('deliveryProofs')
          .child(orderId)
          .child(fileName);
      await ref.putFile(_imageFile!);
      return await ref.getDownloadURL();
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _confirmStep(String orderId, String currentStatus) async {
    String nextStatus = "";
    String imageField = "";

    if (currentStatus == "ไรเดอร์รับงาน") {
      nextStatus = "ไรเดอร์รับสินค้าแล้ว";
      imageField = "pickupProofUrl";
    } else if (currentStatus == "ไรเดอร์รับสินค้าแล้ว") {
      nextStatus = "ไรเดอร์นำส่งสินค้าแล้ว";
      imageField = "deliveryProofUrl";
    }

    String? proofUrl;
    if (_imageFile != null) proofUrl = await _uploadProof(orderId);

    try {
      final updateData = {
        'status': nextStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (proofUrl != null) updateData[imageField] = proofUrl;

      await _firestore
          .collection('deliveryRecords')
          .doc(orderId)
          .update(updateData);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ อัปเดตสถานะเป็น $nextStatus สำเร็จ")));
      setState(() => _imageFile = null);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("เกิดข้อผิดพลาด: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rider = _auth.currentUser;
    if (rider == null) {
      return const Center(child: Text("กรุณาเข้าสู่ระบบอีกครั้ง"));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('deliveryRecords')
          .where('riderId', isEqualTo: rider.uid)
          .where('status',
              whereIn: ['ไรเดอร์รับงาน', 'ไรเดอร์รับสินค้าแล้ว']).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text("ยังไม่มีงานที่กำลังส่ง",
                style: TextStyle(color: Colors.grey)),
          );
        }

        final deliveries = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: deliveries.length,
          itemBuilder: (context, index) {
            final delivery = deliveries[index].data() as Map<String, dynamic>;
            final orderId = deliveries[index].id;

            final pickupAddress = delivery['pickupAddress'] ?? '-';
            final dropAddress = delivery['dropAddress'] ?? '-';
            final price = delivery['price'] ?? 0;
            final status = delivery['status'] ?? '-';
            final pickupLatLng = _parseLatLng(delivery['pickupLatLng']);
            final dropLatLng = _parseLatLng(delivery['dropLatLng']);

            final isStep1 = status == "ไรเดอร์รับงาน";
            final buttonText = isStep1 ? "ยืนยันรับสินค้า" : "ยืนยันส่งสำเร็จ";
            final buttonColor = isStep1 ? Colors.green : Colors.orange;

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("ออเดอร์ #$orderId",
                      style: const TextStyle(
                          color: Colors.green,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.store, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text("จุดรับสินค้า\n$pickupAddress")),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text("จุดส่งสินค้า\n$dropAddress")),
                    ],
                  ),
                  const Divider(height: 24),
                  if (pickupLatLng != null && dropLatLng != null)
                    SizedBox(
                      height: 220,
                      child: FlutterMap(
                        mapController: _mapController,
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
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _isUploading ? null : _showImageSourceDialog,
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _imageFile == null
                          ? const Center(
                              child: Text("เพิ่มรูปภาพ (ไม่บังคับ)",
                                  style: TextStyle(color: Colors.green)))
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(_imageFile!, fit: BoxFit.cover),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _isUploading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: () => _confirmStep(orderId, status),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buttonColor,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(buttonText,
                              style: const TextStyle(color: Colors.white)),
                        ),
                  const SizedBox(height: 10),
                  Text("฿$price บาท",
                      style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
