import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
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

  File? _imageFile;
  LatLng? _pickupLatLng;
  LatLng? _dropLatLng;
  bool _loading = false;

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
      debugPrint("❌ Reverse geocode error: $e");
      return "ไม่สามารถระบุที่อยู่ได้";
    }
  }

  // 📍 ใช้ตำแหน่งปัจจุบัน
  Future<void> _getCurrentLocation(bool isPickup) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("⚠️ โปรดเปิดสิทธิ์ Location ในการตั้งค่าแอป")),
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

  // 🗺️ เปิดแผนที่ให้เลือกตำแหน่ง
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

  // ✅ ดึงรายชื่อผู้รับจาก Firestore
  Future<void> _selectReceiverFromList() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('receivers').get();

    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        children: snapshot.docs.map((doc) {
          final data = doc.data();
          return ListTile(
            title: Text(data['name'] ?? ''),
            subtitle: Text("${data['phone'] ?? ''} • ${data['address'] ?? ''}"),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _dropAddressCtl.text = data['address'] ?? '';
                if (data['lat'] != null && data['lng'] != null) {
                  _dropLatLng = LatLng(data['lat'], data['lng']);
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }

  // ✅ ค้นหาผู้รับด้วยเบอร์โทรศัพท์
  Future<void> _searchReceiverByPhone() async {
    String? inputPhone = await showDialog<String>(
      context: context,
      builder: (context) {
        String phone = '';
        return AlertDialog(
          title: const Text("ค้นหาผู้รับด้วยเบอร์โทรศัพท์"),
          content: TextField(
            keyboardType: TextInputType.phone,
            onChanged: (val) => phone = val,
            decoration: const InputDecoration(hintText: "กรอกเบอร์โทรศัพท์"),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("ยกเลิก")),
            TextButton(
                onPressed: () => Navigator.pop(context, phone),
                child: const Text("ค้นหา")),
          ],
        );
      },
    );

    if (inputPhone == null || inputPhone.isEmpty) return;

    final query = await FirebaseFirestore.instance
        .collection('receivers')
        .where('phone', isEqualTo: inputPhone)
        .get();

    if (query.docs.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("ไม่พบผู้รับนี้")));
      return;
    }

    final data = query.docs.first.data();
    setState(() {
      _dropAddressCtl.text = data['address'] ?? '';
      if (data['lat'] != null && data['lng'] != null) {
        _dropLatLng = LatLng(data['lat'], data['lng']);
      }
    });
  }

  // ✅ บันทึกลง Firestore
  Future<void> saveDeliveryRecord({
    required String userId,
    required String pickupAddress,
    required String dropAddress,
    required double price,
    String? details,
    LatLng? pickupLatLng,
    LatLng? dropLatLng,
  }) async {
    await FirebaseFirestore.instance.collection("deliveryRecords").add({
      "userId": userId,
      "pickupAddress": pickupAddress,
      "pickupLatLng": pickupLatLng != null
          ? "${pickupLatLng.latitude},${pickupLatLng.longitude}"
          : "-",
      "dropAddress": dropAddress,
      "dropLatLng": dropLatLng != null
          ? "${dropLatLng.latitude},${dropLatLng.longitude}"
          : "-",
      "details": details ?? "",
      "price": price,
      "status": "รอไรเดอร์รับงาน",
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> _createOrder() async {
    if (_pickupAddressCtl.text.isEmpty ||
        _dropAddressCtl.text.isEmpty ||
        _priceCtl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ กรุณากรอกข้อมูลให้ครบ")));
      return;
    }

    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("ยังไม่ได้เข้าสู่ระบบ");

      await saveDeliveryRecord(
        userId: user.uid,
        pickupAddress: _pickupAddressCtl.text,
        dropAddress: _dropAddressCtl.text,
        details: _detailCtl.text,
        price: double.tryParse(_priceCtl.text) ?? 0.0,
        pickupLatLng: _pickupLatLng,
        dropLatLng: _dropLatLng,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ สร้างออเดอร์สำเร็จ")),
      );
      widget.onOrderCreated?.call();
    } catch (e) {
      debugPrint("❌ Error: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("เกิดข้อผิดพลาด: $e")));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("สร้างออเดอร์ใหม่"), backgroundColor: Colors.green),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildAddressSection("จุดรับสินค้า", _pickupAddressCtl, true),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _selectReceiverFromList,
                icon: const Icon(Icons.person_search),
                label: const Text("เลือกรายชื่อผู้รับ"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: _searchReceiverByPhone,
                icon: const Icon(Icons.search, color: Colors.green),
                label: const Text("ค้นหาด้วยเบอร์โทร",
                    style: TextStyle(color: Colors.green)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildAddressSection("จุดส่งสินค้า (ผู้รับ)", _dropAddressCtl, false),

          // ✅ แสดงแผนที่ตำแหน่งผู้รับ (ข้อ 2.1.4)
          if (_dropLatLng != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              height: 180,
              decoration:
                  BoxDecoration(border: Border.all(color: Colors.green)),
              child: FlutterMap(
                options:
                    MapOptions(initialCenter: _dropLatLng!, initialZoom: 15),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.delivery_frontend',
                  ),
                  MarkerLayer(markers: [
                    Marker(
                      point: _dropLatLng!,
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.location_pin,
                          color: Colors.red, size: 40),
                    ),
                  ]),
                ],
              ),
            ),

          const SizedBox(height: 20),
          _buildTitle("รายละเอียดเพิ่มเติม"),
          TextField(
            controller: _detailCtl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: "รายละเอียดพัสดุ, คำแนะนำ",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          _buildTitle("รูปถ่ายพัสดุ"),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _imageFile != null
                  ? Image.file(_imageFile!, fit: BoxFit.cover)
                  : const Center(child: Text("แตะเพื่อถ่ายรูปพัสดุ")),
            ),
          ),
          const SizedBox(height: 20),
          _buildTitle("ค่าใช้จ่าย"),
          TextField(
            controller: _priceCtl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: "ระบุราคา (บาท)",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 30),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            ElevatedButton(
              onPressed: _loading ? null : () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  minimumSize: const Size(130, 45)),
              child: const Text("ยกเลิก"),
            ),
            ElevatedButton(
              onPressed: _loading ? null : _createOrder,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(130, 45)),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("สร้างออเดอร์"),
            ),
          ]),
        ]),
      ),
    );
  }

  // 🎯 ส่วน UI ย่อย
  Widget _buildTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  Widget _buildAddressSection(
      String title, TextEditingController ctl, bool isPickup) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildTitle(title),
      TextField(
        controller: ctl,
        readOnly: true,
        decoration: InputDecoration(
          hintText: "แตะปุ่มด้านขวาเพื่อเลือกที่อยู่",
          border: const OutlineInputBorder(),
          suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              icon: const Icon(Icons.my_location, color: Colors.green),
              onPressed: () => _getCurrentLocation(isPickup),
            ),
            IconButton(
              icon: const Icon(Icons.map, color: Colors.orange),
              onPressed: () => _openMapPicker(isPickup),
            ),
          ]),
        ),
      ),
    ]);
  }
}
