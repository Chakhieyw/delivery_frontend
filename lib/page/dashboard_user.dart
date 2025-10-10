import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DashboardUserPage extends StatefulWidget {
  const DashboardUserPage({super.key});

  @override
  State<DashboardUserPage> createState() => _DashboardUserPageState();
}

class _DashboardUserPageState extends State<DashboardUserPage>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  String? _userName;
  String? _userImage;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      setState(() {
        _userName = doc['name'] ?? 'ผู้ใช้';
        _userImage = doc['imageUrl'] ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.green,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: _userImage != null && _userImage!.isNotEmpty
                  ? NetworkImage(_userImage!)
                  : null,
              child: _userImage == null || _userImage!.isEmpty
                  ? const Icon(Icons.person, color: Colors.green)
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              _userName ?? "กำลังโหลด...",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                await _auth.signOut();
                if (!mounted) return;
                Navigator.pop(context);
              },
            )
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.orange,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.home), text: "หน้าหลัก"),
            Tab(icon: Icon(Icons.location_on), text: "ติดตาม"),
            Tab(icon: Icon(Icons.add_box), text: "สร้าง"),
            Tab(icon: Icon(Icons.history), text: "ประวัติ"),
            Tab(icon: Icon(Icons.person), text: "โปรไฟล์"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _HomeTab(),
          _TrackTab(),
          _CreateOrderTab(),
          _HistoryTab(),
          _ProfileTab(),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("📦 หน้าหลัก",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("ดูคำสั่งซื้อและสถานะการจัดส่งล่าสุดได้ที่นี่"),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text("ดูออเดอร์"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackTab extends StatelessWidget {
  const _TrackTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text("🚚 หน้าติดตามออเดอร์"),
    );
  }
}

class _CreateOrderTab extends StatelessWidget {
  const _CreateOrderTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text("➕ หน้าสร้างออเดอร์ใหม่"),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text("📜 หน้าประวัติคำสั่งซื้อ"),
    );
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String? name;
  String? email;
  String? phone;
  String? address;
  String? imageUrl;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          name = doc['name'] ?? '-';
          email = doc['email'] ?? '-';
          phone = doc['phone'] ?? '-';
          address = doc['address'] ?? '-';
          imageUrl = doc['imageUrl'] ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching profile: $e");
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 🔹 รูปโปรไฟล์
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.green.shade100,
              backgroundImage: (imageUrl != null && imageUrl!.isNotEmpty)
                  ? NetworkImage(imageUrl!)
                  : null,
              child: (imageUrl == null || imageUrl!.isEmpty)
                  ? const Icon(Icons.person, color: Colors.green, size: 70)
                  : null,
            ),
            const SizedBox(height: 20),

            // 🔹 ชื่อผู้ใช้
            Text(
              name ?? "ไม่พบชื่อ",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 10),

            // 🔹 รายละเอียดอื่น ๆ
            _buildInfoRow(Icons.email, "อีเมล", email ?? "-"),
            _buildInfoRow(Icons.phone, "เบอร์โทรศัพท์", phone ?? "-"),
            _buildInfoRow(Icons.home, "ที่อยู่", address ?? "-"),

            const SizedBox(height: 20),

            // 🔹 ปุ่มแก้ไข (จะเพิ่มหน้าแก้ไขภายหลังได้)
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("✏️ ฟังก์ชันแก้ไขกำลังพัฒนา")),
                );
              },
              icon: const Icon(Icons.edit),
              label: const Text("แก้ไขข้อมูล"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 ฟังก์ชันสร้างแถวข้อมูล
  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.green),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text(value,
                    style:
                        const TextStyle(color: Colors.black87, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
