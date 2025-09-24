import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:delivery_frontend/page/login_user.dart';

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

  /// 📌 เลือกรูปจาก Gallery
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
      debugPrint("📌 เลือกรูป path = ${picked.path}");
      debugPrint("📌 exists = ${_imageFile!.existsSync()}");
      if (_imageFile!.existsSync()) {
        debugPrint("📌 file size = ${_imageFile!.lengthSync()} bytes");
      }
    } else {
      debugPrint("⚠️ ไม่ได้เลือกรูป");
    }
  }

  /// 📌 สมัครสมาชิก
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

      // ✅ สมัคร Firebase Auth
      UserCredential user = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      debugPrint("📌 สมัครสำเร็จ uid=${user.user!.uid}");

      // ✅ อัปโหลดรูปไป Firebase Storage
      String? imageUrl;
      if (_imageFile != null) {
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child("user_images")
              .child("${user.user!.uid}.jpg");

          debugPrint("📌 เริ่มอัปโหลดไฟล์: ${_imageFile!.path}");
          final bytes = await _imageFile!.readAsBytes();
          debugPrint("📌 bytes length = ${bytes.length}");

          final uploadTask = await ref.putData(bytes);
          debugPrint("📌 Upload สำเร็จ: ${uploadTask.metadata?.fullPath}");

          imageUrl = await ref.getDownloadURL();
          debugPrint("📌 imageUrl: $imageUrl");
        } catch (e) {
          debugPrint("🔥 Upload Error: $e");
        }
      } else {
        debugPrint("⚠️ ไม่มีการเลือกรูป");
      }

      // ✅ บันทึกข้อมูลลง Firestore
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
        "createdAt": FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ สมัครสมาชิกสำเร็จ")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginUserPage()),
      );
    } on FirebaseAuthException catch (e) {
      String msg = "เกิดข้อผิดพลาด";
      if (e.code == 'email-already-in-use') {
        msg = "❌ อีเมลนี้ถูกใช้แล้ว";
      } else if (e.code == 'weak-password') {
        msg = "❌ รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร";
      }
      debugPrint("🔥 FirebaseAuth Error: ${e.code}");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      debugPrint("🔥 Error ตอนสมัคร: $e");
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
              // Header
              Container(
                height: 80,
                width: double.infinity,
                color: Colors.green,
                alignment: Alignment.center,
                child: const Text(
                  "Delivery AppT&K",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "สมัครสมาชิก",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),

              const SizedBox(height: 20),

              _buildTextField(_nameCtl, Icons.person, "ชื่อผู้ใช้", false),
              _buildTextField(_emailCtl, Icons.email, "อีเมล", false),
              _buildPhoneField(),
              _buildTextField(_passwordCtl, Icons.lock, "รหัสผ่าน", true),
              _buildTextField(
                  _confirmCtl, Icons.lock_outline, "ยืนยันรหัสผ่าน", true),
              _buildTextField(_addressCtl, Icons.location_on,
                  "ที่อยู่ (เพิ่มที่อยู่)", false),

              const SizedBox(height: 10),

              // รูปโปรไฟล์
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(_imageFile!, fit: BoxFit.cover),
                        )
                      : const Icon(Icons.person, size: 60, color: Colors.green),
                ),
              ),

              const SizedBox(height: 20),

              // ปุ่มสมัคร + ยกเลิก
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
                      onPressed: () => Navigator.pop(context),
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

              const SizedBox(height: 20),

              // ลิงก์เข้าสู่ระบบ
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("หากเป็นสมาชิกอยู่แล้วกลับไปที่หน้า "),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      "เข้าสู่ระบบ",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Footer
              Container(
                height: 40,
                width: double.infinity,
                color: Colors.green,
              ),
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Colors.green),
          ),
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Colors.green),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Colors.green, width: 2),
          ),
        ),
      ),
    );
  }
}
