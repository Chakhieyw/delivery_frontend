import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:delivery_frontend/page/login_user.dart';
import 'package:delivery_frontend/page/MapPickerPage.dart';

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
  final _addressCtl = TextEditingController();

  File? _imageFile;
  bool _loading = false;
  LatLng? _selectedPosition;

  final String _apiKey = "YOUR_THUNDERFOREST_API_KEY"; // ใส่ key ที่ได้มาที่นี่

  /// ✅ เลือกรูปจาก Gallery
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  /// ✅ ดึงตำแหน่งปัจจุบัน
  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ กรุณาอนุญาตให้เข้าถึงตำแหน่ง")),
        );
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _selectedPosition = LatLng(pos.latitude, pos.longitude);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text("📍 พิกัดปัจจุบัน: ${pos.latitude}, ${pos.longitude}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ ไม่สามารถดึงตำแหน่งได้: $e")),
      );
    }
  }

  /// ✅ เปิดหน้าเลือกตำแหน่งบนแผนที่
  Future<void> _openMapPicker() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerPage(
          apiKey: _apiKey,
          onPositionSelected: (pos) {
            setState(() => _selectedPosition = pos);
          },
        ),
      ),
    );
  }

  /// ✅ สมัครสมาชิก
  Future<void> _register() async {
    if (_passwordCtl.text != _confirmCtl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ รหัสผ่านไม่ตรงกัน")),
      );
      return;
    }

    if (_phoneCtl.text.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ กรุณากรอกเบอร์โทรศัพท์ 10 หลัก")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final email = _emailCtl.text.trim();
      final password = _passwordCtl.text.trim();

      UserCredential user = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      String? imageUrl;

      if (_imageFile != null) {
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child("user_images/${user.user!.uid}.jpg");
          await ref.putFile(_imageFile!);
          imageUrl = await ref.getDownloadURL();
        } catch (e) {
          debugPrint("🔥 Upload error: $e");
          imageUrl = null;
        }
      } else {
        // 🔹 ถ้าไม่มีรูป ให้ใช้ภาพโปรไฟล์เริ่มต้นจาก URL หรือ assets
        imageUrl =
            "https://firebasestorage.googleapis.com/v0/b/YOUR_PROJECT_ID.appspot.com/o/defaults%2Fdefault_user.png?alt=media";
      }

      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.user!.uid)
          .set({
        "name": _nameCtl.text.trim(),
        "email": email,
        "phone": _phoneCtl.text.trim(),
        "address": _addressCtl.text.trim(),
        "role": "user",
        "imageUrl": imageUrl ?? "",
        "password": _passwordCtl.text.trim(),
        "location": {
          "lat": _selectedPosition?.latitude,
          "lng": _selectedPosition?.longitude,
        },
        "createdAt": FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ สมัครสมาชิกสำเร็จ")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginUserPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
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
              const SizedBox(height: 20),
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

              const SizedBox(height: 10),
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

              // ปุ่มเลือกตำแหน่ง
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _openMapPicker,
                    icon: const Icon(Icons.map),
                    label: const Text("เลือกตำแหน่งจากแผนที่"),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _getCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text("ใช้ตำแหน่งปัจจุบัน"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // แสดง mini map
              if (_selectedPosition != null) ...[
                Text(
                  "พิกัดที่เลือก: ${_selectedPosition!.latitude.toStringAsFixed(5)}, ${_selectedPosition!.longitude.toStringAsFixed(5)}",
                  style: const TextStyle(color: Colors.black54),
                ),
                SizedBox(
                  height: 200,
                  width: 340,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _selectedPosition!,
                      initialZoom: 15,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.thunderforest.com/atlas/{z}/{x}/{y}.png?apikey=12183dd51e894a75b97d6786c14a83ac',
                        userAgentPackageName: 'com.example.delivery_frontend',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 60,
                            height: 60,
                            point: _selectedPosition!,
                            child: const Icon(Icons.location_pin,
                                color: Colors.red, size: 45),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 20),
                const Text(
                  "📍 ยังไม่ได้เลือกตำแหน่ง",
                  style: TextStyle(color: Colors.grey),
                ),
              ],

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
