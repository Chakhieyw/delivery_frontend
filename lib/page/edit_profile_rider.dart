import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditProfileRiderPage extends StatefulWidget {
  const EditProfileRiderPage({super.key});

  @override
  State<EditProfileRiderPage> createState() => _EditProfileRiderPageState();
}

class _EditProfileRiderPageState extends State<EditProfileRiderPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _plateController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchRiderData();
  }

  Future<void> fetchRiderData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('riders').doc(user.uid).get();
      if (doc.exists) {
        _nameController.text = doc['name'] ?? '';
        _phoneController.text = doc['phone'] ?? '';
        _plateController.text = doc['plate'] ?? '';
      }
    } catch (e) {
      print("Error loading rider data: $e");
    }
  }

  Future<void> saveProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (_nameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _plateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ กรุณากรอกข้อมูลให้ครบถ้วน")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _firestore.collection('riders').doc(user.uid).update({
        'name': _nameController.text,
        'phone': _phoneController.text,
        'plate': _plateController.text,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ บันทึกข้อมูลสำเร็จ")),
      );

      Navigator.pop(context); // กลับไปหน้าโปรไฟล์
    } catch (e) {
      print("Error updating profile: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ เกิดข้อผิดพลาดในการบันทึกข้อมูล")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
        child: Center(
          child: Column(
            children: [
              // 🔹 Card หลัก
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // รูปโปรไฟล์
                    CircleAvatar(
                      radius: 45,
                      backgroundColor: const Color(0xFF4CAF50),
                      child: const Icon(Icons.person,
                          color: Colors.white, size: 55),
                    ),
                    const SizedBox(height: 25),

                    // ช่องกรอกชื่อ
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_outline,
                            color: Colors.green),
                        hintText: "ชื่อ–นามสกุล",
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Colors.green, width: 1.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Colors.green, width: 1.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // ช่องกรอกเบอร์โทรศัพท์
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        prefixIcon:
                            const Icon(Icons.phone, color: Colors.green),
                        hintText: "เบอร์โทรศัพท์",
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Colors.green, width: 1.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Colors.green, width: 1.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // ช่องกรอกทะเบียนรถ
                    TextField(
                      controller: _plateController,
                      decoration: InputDecoration(
                        prefixIcon:
                            const Icon(Icons.credit_card, color: Colors.green),
                        hintText: "ทะเบียนรถ",
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Colors.green, width: 1.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Colors.green, width: 1.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // 🔹 ปุ่มกลับและบันทึก
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // ปุ่มกลับ
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            minimumSize: const Size(130, 45),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text("กลับ",
                              style: TextStyle(color: Colors.white)),
                        ),

                        // ปุ่มบันทึกข้อมูล
                        ElevatedButton(
                          onPressed: _isLoading ? null : saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            minimumSize: const Size(130, 45),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text("บันทึกข้อมูล",
                                  style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
