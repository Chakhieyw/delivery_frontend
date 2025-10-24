import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_profile_rider.dart';

class RiderProfilePage extends StatefulWidget {
  const RiderProfilePage({super.key});

  @override
  State<RiderProfilePage> createState() => _RiderProfilePageState();
}

class _RiderProfilePageState extends State<RiderProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String? name;
  String? phone;
  String? plate;
  String? imageUrl;
  bool _isLoading = true;

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
        setState(() {
          name = doc['name'];
          phone = doc['phone'];
          plate = doc['plate'];
          imageUrl = doc['imageUrl'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("⚠️ โหลดข้อมูล Rider ล้มเหลว: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F4),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // 🟢 Header
                    Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(bottom: 30),
                      child: const Text(
                        "โปรไฟล์ Rider",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),

                    // 🧾 การ์ดโปรไฟล์
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // รูปโปรไฟล์
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.green, width: 3),
                            ),
                            child: CircleAvatar(
                              radius: 55,
                              backgroundColor: Colors.green.shade100,
                              backgroundImage:
                                  (imageUrl != null && imageUrl!.isNotEmpty)
                                      ? NetworkImage(imageUrl!)
                                      : null,
                              child: (imageUrl == null || imageUrl!.isEmpty)
                                  ? const Icon(Icons.person,
                                      size: 70, color: Colors.green)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 15),

                          // ชื่อ
                          Text(
                            name ?? "-",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // เบอร์โทร / ทะเบียนรถ
                          Text(
                            "เบอร์โทร: ${phone ?? '-'}",
                            style: const TextStyle(
                                fontSize: 16, color: Colors.black54),
                          ),
                          Text(
                            "ทะเบียนรถ: ${plate ?? '-'}",
                            style: const TextStyle(
                                fontSize: 16, color: Colors.black54),
                          ),

                          const SizedBox(height: 25),

                          // ปุ่มแก้ไข
                          SizedBox(
                            width: 200,
                            height: 45,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const EditRiderProfilePage(),
                                  ),
                                ).then((_) => fetchRiderData());
                              },
                              icon: const Icon(Icons.edit, color: Colors.white),
                              label: const Text(
                                "แก้ไขโปรไฟล์",
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                elevation: 3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ปุ่ม Logout
                    TextButton.icon(
                      onPressed: () async {
                        await _auth.signOut();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text(
                        "ออกจากระบบ",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
