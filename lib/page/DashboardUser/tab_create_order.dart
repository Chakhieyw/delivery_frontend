import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:delivery_frontend/page/map_picker_page.dart';

class CreateOrderForm extends StatefulWidget {
  final VoidCallback? onOrderCreated;
  const CreateOrderForm({super.key, this.onOrderCreated});

  @override
  State<CreateOrderForm> createState() => _CreateOrderFormState();
}

class _CreateOrderFormState extends State<CreateOrderForm> {
  final _pickupAddressCtl = TextEditingController();
  final _dropAddressCtl = TextEditingController();
  final _detailCtl = TextEditingController();
  final _priceCtl = TextEditingController();
  final _searchPhoneCtl = TextEditingController();

  File? _imageFile;
  LatLng? _pickupLatLng;
  LatLng? _dropLatLng;
  bool _loading = false;

  String? selectedReceiverId;
  String? selectedReceiverName;
  String? selectedReceiverPhone;
  String? selectedReceiverAddress;

  // ✅ ดึง users ทั้งหมด
  Stream<QuerySnapshot> get receiversStream =>
      FirebaseFirestore.instance.collection('users').snapshots();

  // ✅ ดึงข้อมูลของผู้ใช้ปัจจุบัน (ผู้ส่ง)
  Future<Map<String, dynamic>?> _getCurrentUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return doc.data();
  }

  // ✅ แปลงพิกัดเป็นชื่อที่อยู่
  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        return "${p.street ?? ''} ${p.subLocality ?? ''} ${p.locality ?? ''} ${p.administrativeArea ?? ''}"
            .trim();
      }
      return "ไม่พบที่อยู่";
    } catch (e) {
      return "ไม่สามารถระบุที่อยู่ได้";
    }
  }

  // 📍 ใช้พิกัดของผู้ส่งจาก Firestore
  Future<void> _useMyDefaultAddress() async {
    final userData = await _getCurrentUserData();
    if (userData == null) return;

    final addresses =
        List<Map<String, dynamic>>.from(userData['addresses'] ?? []);
    if (addresses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ คุณยังไม่มีที่อยู่ในโปรไฟล์")),
      );
      return;
    }

    final addr = addresses.first; // ใช้ที่อยู่แรก
    setState(() {
      _pickupAddressCtl.text = addr['address'];
      _pickupLatLng = LatLng(addr['lat'], addr['lng']);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("✅ ใช้ที่อยู่เริ่มต้นของคุณเป็นจุดรับสินค้า")),
    );
  }

  // 📍 ใช้ตำแหน่งปัจจุบัน
  Future<void> _getCurrentLocation(bool isPickup) async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ โปรดเปิดสิทธิ์ Location")),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final address = await _getAddressFromLatLng(pos.latitude, pos.longitude);

      setState(() {
        final latLng = LatLng(pos.latitude, pos.longitude);
        if (isPickup) {
          _pickupLatLng = latLng;
          _pickupAddressCtl.text = address;
        } else {
          _dropLatLng = latLng;
          _dropAddressCtl.text = address;
        }
      });
    } catch (e) {
      debugPrint("⚠️ GPS error: $e");
    }
  }

  // 🗺️ เปิดแผนที่เลือกตำแหน่ง
  Future<void> _openMapPicker(bool isPickup) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerPage(
          onPositionSelected: (pos) async {
            final address =
                await _getAddressFromLatLng(pos.latitude, pos.longitude);
            setState(() {
              if (isPickup) {
                _pickupLatLng = pos;
                _pickupAddressCtl.text = address;
              } else {
                _dropLatLng = pos;
                _dropAddressCtl.text = address;
              }
            });
          },
        ),
      ),
    );
  }

  // 📸 ถ่ายรูปพัสดุ
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  // ✅ สร้างออเดอร์
  Future<void> _createOrder() async {
    if (selectedReceiverId == null ||
        _pickupAddressCtl.text.isEmpty ||
        _dropAddressCtl.text.isEmpty ||
        _priceCtl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ กรุณากรอกข้อมูลให้ครบ")),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};

      await FirebaseFirestore.instance.collection("deliveryRecords").add({
        "userId": user.uid,
        "userName": userData['name'] ?? 'ไม่ระบุ',
        "userPhone": userData['phone'] ?? '-',
        "pickupAddress": _pickupAddressCtl.text,
        "pickupLatLng": _pickupLatLng != null
            ? "${_pickupLatLng!.latitude},${_pickupLatLng!.longitude}"
            : "-",
        "receiverId": selectedReceiverId,
        "receiverName": selectedReceiverName,
        "receiverPhone": selectedReceiverPhone,
        "receiverAddress": selectedReceiverAddress ?? '-',
        "dropAddress": _dropAddressCtl.text,
        "dropLatLng": _dropLatLng != null
            ? "${_dropLatLng!.latitude},${_dropLatLng!.longitude}"
            : "-",
        "details": _detailCtl.text,
        "price": double.tryParse(_priceCtl.text) ?? 0.0,
        "status": "รอไรเดอร์รับงาน",
        "createdAt": FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ สร้างออเดอร์สำเร็จ")),
      );

      widget.onOrderCreated?.call();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("เกิดข้อผิดพลาด: $e")));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("สร้างออเดอร์ใหม่"),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitle("เลือกผู้รับสินค้า"),
            StreamBuilder<QuerySnapshot>(
              stream: receiversStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data!.docs;
                final filtered = users.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final phone = data['phone'] ?? '';
                  return phone.contains(_searchPhoneCtl.text.trim());
                }).toList();

                return Column(
                  children: [
                    TextField(
                      controller: _searchPhoneCtl,
                      decoration: const InputDecoration(
                        hintText: "ค้นหาผู้รับโดยเบอร์โทรศัพท์",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "เลือกผู้รับ",
                      ),
                      value: selectedReceiverId,
                      items: filtered.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text("${data['name']} (${data['phone']})"),
                        );
                      }).toList(),
                      onChanged: (val) {
                        final user = users.firstWhere((u) => u.id == val);
                        final data = user.data() as Map<String, dynamic>;
                        final addresses = List<Map<String, dynamic>>.from(
                            data['addresses'] ?? []);
                        final addr =
                            addresses.isNotEmpty ? addresses.first : null;

                        setState(() {
                          selectedReceiverId = val;
                          selectedReceiverName = data['name'];
                          selectedReceiverPhone = data['phone'];
                          selectedReceiverAddress = addr?['address'] ?? '-';
                          if (addr != null) {
                            _dropAddressCtl.text = addr['address'];
                            _dropLatLng = LatLng(addr['lat'], addr['lng']);
                          }
                        });
                      },
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            _buildTitle("จุดรับสินค้า (ผู้ส่ง)"),
            TextField(
              controller: _pickupAddressCtl,
              readOnly: true,
              decoration: InputDecoration(
                hintText: "แตะปุ่มเพื่อเลือกที่อยู่",
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.home, color: Colors.green),
                      tooltip: "ใช้ที่อยู่ของฉัน",
                      onPressed: _useMyDefaultAddress,
                    ),
                    IconButton(
                      icon: const Icon(Icons.my_location, color: Colors.orange),
                      onPressed: () => _getCurrentLocation(true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.map, color: Colors.blue),
                      onPressed: () => _openMapPicker(true),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildAddressSection(
                "จุดส่งสินค้า (ผู้รับ)", _dropAddressCtl, false),
            const SizedBox(height: 20),
            _buildTitle("รายละเอียดเพิ่มเติม"),
            TextField(
              controller: _detailCtl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "รายละเอียดพัสดุหรือคำแนะนำ",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _buildTitle("ค่าใช้จ่าย (บาท)"),
            TextField(
              controller: _priceCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: "เช่น 100",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: _loading ? null : _createOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("สร้างออเดอร์"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  Widget _buildAddressSection(
      String title, TextEditingController ctl, bool isPickup) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(title),
        TextField(
          controller: ctl,
          readOnly: true,
          decoration: InputDecoration(
            hintText: "แตะเพื่อเลือกที่อยู่",
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.my_location, color: Colors.orange),
                  onPressed: () => _getCurrentLocation(isPickup),
                ),
                IconButton(
                  icon: const Icon(Icons.map, color: Colors.blue),
                  onPressed: () => _openMapPicker(isPickup),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
