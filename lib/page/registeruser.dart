import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:delivery_frontend/page/login_user.dart';
import 'package:delivery_frontend/page/MapPickerPage.dart';
import 'package:delivery_frontend/services/cloudinary_service.dart';

class RegisterUserPage extends StatefulWidget {
  const RegisterUserPage({super.key});

  @override
  State<RegisterUserPage> createState() => _RegisterUserPageState();
}

class _RegisterUserPageState extends State<RegisterUserPage> {
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _confirmCtl = TextEditingController();

  File? _imageFile;
  bool _loading = false;
  LatLng? _selectedPosition;

  List<Map<String, dynamic>> _addresses = []; // ✅ ที่อยู่หลายที่
  final String _apiKey = "YOUR_THUNDERFOREST_API_KEY";

  /// ✅ เลือกรูป
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  /// ✅ ดึงที่อยู่จากพิกัด
  Future<String> _getAddressFromLatLng(LatLng? position) async {
    if (position == null) return "ไม่พบตำแหน่ง";
    try {
      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        return "${p.street ?? ''} ${p.subLocality ?? ''} ${p.locality ?? ''} ${p.administrativeArea ?? ''}";
      }
      return "ไม่พบที่อยู่";
    } catch (e) {
      return "ไม่สามารถระบุที่อยู่ได้";
    }
  }

  /// ✅ เปิด MapPicker
  Future<void> _openMapPicker() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerPage(
          apiKey: _apiKey,
          onPositionSelected: (pos) async {
            setState(() => _selectedPosition = pos);
          },
        ),
      ),
    );
  }

  /// ✅ ใช้ตำแหน่งปัจจุบัน
  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ โปรดอนุญาตการเข้าถึงตำแหน่ง")),
        );
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() => _selectedPosition = LatLng(pos.latitude, pos.longitude));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("📍 พิกัด: ${pos.latitude}, ${pos.longitude}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ ไม่สามารถดึงตำแหน่งได้: $e")),
      );
    }
  }

  /// ✅ เพิ่มที่อยู่ในรายการ
  Future<void> _addAddress() async {
    if (_selectedPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณาเลือกตำแหน่งก่อนเพิ่มที่อยู่")),
      );
      return;
    }

    final address = await _getAddressFromLatLng(_selectedPosition);
    setState(() {
      _addresses.add({
        'address': address,
        'lat': _selectedPosition!.latitude,
        'lng': _selectedPosition!.longitude,
      });
      _selectedPosition = null;
    });
  }

  /// ✅ สมัครสมาชิก
  Future<void> _register() async {
    if (_passwordCtl.text != _confirmCtl.text) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("❌ รหัสผ่านไม่ตรงกัน")));
      return;
    }

    if (_addresses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณาเพิ่มที่อยู่อย่างน้อย 1 ที่")),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final email = _emailCtl.text.trim();
      final password = _passwordCtl.text.trim();

      final user = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      String imageUrl = "";
      if (_imageFile != null) {
        imageUrl = await CloudinaryService.uploadImage(
              fromCamera: false,
              file: _imageFile, // ✅ ส่งไฟล์ที่เลือกไป
              folder: "profiles",
            ) ??
            "";
      }

      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.user!.uid)
          .set({
        "uid": user.user!.uid,
        "name": _nameCtl.text.trim(),
        "email": email,
        "phone": _phoneCtl.text.trim(),
        "role": "user",
        "imageUrl": imageUrl,
        "addresses": _addresses, // ✅ ที่อยู่หลายที่
        "createdAt": FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("✅ สมัครสมาชิกสำเร็จ")));
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginUserPage()));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                height: 80,
                color: Colors.green,
                alignment: Alignment.center,
                child: const Text("Delivery AppT&K",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 15),
              const Text("สมัครสมาชิก",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green)),
              const SizedBox(height: 20),
              _buildTextField(_nameCtl, Icons.person, "ชื่อผู้ใช้", false),
              _buildTextField(_emailCtl, Icons.email, "อีเมล", false),
              _buildPhoneField(),
              _buildTextField(_passwordCtl, Icons.lock, "รหัสผ่าน", true),
              _buildTextField(
                  _confirmCtl, Icons.lock_outline, "ยืนยันรหัสผ่าน", true),
              const SizedBox(height: 15),

              // รูปโปรไฟล์
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.green.shade100,
                  backgroundImage:
                      _imageFile != null ? FileImage(_imageFile!) : null,
                  child: _imageFile == null
                      ? const Icon(Icons.person, color: Colors.green, size: 50)
                      : null,
                ),
              ),

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _openMapPicker,
                    icon: const Icon(Icons.map),
                    label: const Text("เลือกจากแผนที่"),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _getCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text("ตำแหน่งปัจจุบัน"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_selectedPosition != null)
                Column(
                  children: [
                    Text(
                        "📍 พิกัด: ${_selectedPosition!.latitude.toStringAsFixed(5)}, ${_selectedPosition!.longitude.toStringAsFixed(5)}"),
                    ElevatedButton.icon(
                      onPressed: _addAddress,
                      icon: const Icon(Icons.add_location_alt),
                      label: const Text("เพิ่มที่อยู่จากพิกัดนี้"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                    ),
                  ],
                ),

              if (_addresses.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: _addresses.map((a) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.home, color: Colors.green),
                          title: Text(a['address']),
                          subtitle: Text(
                              "Lat: ${a['lat'].toStringAsFixed(4)}, Lng: ${a['lng'].toStringAsFixed(4)}"),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () =>
                                setState(() => _addresses.remove(a)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("สมัครสมาชิก"),
                    ),
                  ),
                  const SizedBox(width: 15),
                  SizedBox(
                    width: 120,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginUserPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text("ยกเลิก"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController ctl, IconData icon, String hint, bool obscure) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 6),
      child: TextField(
        controller: ctl,
        obscureText: obscure,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.green),
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Colors.green, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 6),
      child: TextField(
        controller: _phoneCtl,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.phone, color: Colors.green),
          hintText: "เบอร์โทรศัพท์",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Colors.green, width: 2),
          ),
        ),
      ),
    );
  }
}
