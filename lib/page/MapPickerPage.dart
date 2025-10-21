import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPickerPage extends StatefulWidget {
  final String apiKey;
  final Function(LatLng) onPositionSelected;

  const MapPickerPage({
    super.key,
    this.apiKey = '', // ✅ เพิ่ม default เพื่อป้องกัน error เวลาไม่ได้ส่งค่า
    required this.onPositionSelected,
  });

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  LatLng _selected = LatLng(13.7563, 100.5018); // 🏙 ค่าเริ่มต้น: กรุงเทพฯ

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("เลือกตำแหน่งของคุณ"),
        backgroundColor: Colors.green,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _selected,
              initialZoom: 15,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all, // ✅ เปิดให้ลาก/ซูม/แตะได้หมด
              ),
              onTap: (tapPosition, point) {
                setState(() => _selected = point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    // ✅ แนะนำใช้ OpenStreetMap (ไม่ต้องใช้ apiKey)
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.kongphob.deliveryapp',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selected,
                    width: 60,
                    height: 60,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 45,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 🔹 ปุ่มยืนยันตำแหน่ง
          Positioned(
            bottom: 25,
            left: 40,
            right: 40,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text("ยืนยันตำแหน่งนี้"),
              onPressed: () {
                widget.onPositionSelected(_selected);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
