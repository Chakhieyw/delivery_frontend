import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPickerPage extends StatefulWidget {
  final String apiKey;
  final Function(LatLng) onPositionSelected;

  const MapPickerPage({
    super.key,
    required this.apiKey,
    required this.onPositionSelected,
  });

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  LatLng _selected = LatLng(13.7563, 100.5018); // default: Bangkok

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("เลือกตำแหน่งของคุณ"),
          backgroundColor: Colors.green),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _selected,
              initialZoom: 14,
              onTap: (tapPosition, point) {
                setState(() => _selected = point);
              },
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
                    point: _selected,
                    width: 60,
                    height: 60,
                    child: const Icon(Icons.location_pin,
                        color: Colors.red, size: 45),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 50,
            right: 50,
            child: ElevatedButton(
              onPressed: () {
                widget.onPositionSelected(_selected);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("ยืนยันตำแหน่งนี้"),
            ),
          ),
        ],
      ),
    );
  }
}
