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

  /// ✅ แปลงพิกัดเป็นที่อยู่
  Future<void> _getAddressFromLatLng(LatLng? position) async {
    if (position == null) return;

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        final String street = (place.street != null && place.street!.isNotEmpty)
            ? place.street!
            : (place.subLocality?.isNotEmpty ?? false)
                ? place.subLocality!
                : (place.locality?.isNotEmpty ?? false)
                    ? place.locality!
                    : '';

        final String city = place.subAdministrativeArea ?? '';
        final String province = place.administrativeArea ?? '';
        final String country = place.country ?? '';

        final formattedAddress = [street, city, province, country]
            .where((e) => e.isNotEmpty)
            .join(', ');

        setState(() {
          _addressCtl.text = formattedAddress;
        });

        debugPrint("📍 แปลงพิกัดเป็นที่อยู่: $formattedAddress");
      } else {
        _addressCtl.text = "ไม่พบข้อมูลที่อยู่";
      }
    } catch (e) {
      debugPrint("❌ แปลงพิกัดล้มเหลว: $e");
      _addressCtl.text = "ไม่สามารถดึงที่อยู่ได้";
    }
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
      await _getAddressFromLatLng(_selectedPosition);

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
          onPositionSelected: (pos) async {
            setState(() => _selectedPosition = pos);
            await _getAddressFromLatLng(pos);
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

      // ✅ สร้างบัญชีใน Firebase Auth
      UserCredential user = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      String? imageUrl;

      // ✅ อัปโหลดรูปโปรไฟล์ขึ้น Cloudinary (ถ้ามีรูป)
      if (_imageFile != null) {
        try {
          imageUrl = await CloudinaryService.uploadImage(
            fromCamera: false,
            folder: "profiles",
          );

          if (imageUrl != null && imageUrl.isNotEmpty) {
            debugPrint("✅ อัปโหลดขึ้น Cloudinary สำเร็จ: $imageUrl");
          } else {
            debugPrint(
                "⚠️ ไม่สามารถอัปโหลดรูปขึ้น Cloudinary ได้ (imageUrl ว่าง)");
          }
        } catch (e) {
          debugPrint("❌ อัปโหลดรูปไป Cloudinary ล้มเหลว: $e");
        }
      }

      // ✅ บันทึกข้อมูลผู้ใช้ลง Firestore
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
                            'https://tile.thunderforest.com/atlas/{z}/{x}/{y}.png?apikey=$_apiKey',
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
