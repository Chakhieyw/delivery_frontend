import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPickerPage extends StatefulWidget {
  final LatLng? initialPosition;
  final Function(LatLng) onPositionSelected;

  const MapPickerPage({
    super.key,
    this.initialPosition,
    required this.onPositionSelected,
  });

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  LatLng? _selectedPosition;

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialPosition ??
        const LatLng(13.736717, 100.523186); // Default = กรุงเทพฯ
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("เลือกตำแหน่งบนแผนที่"),
        backgroundColor: Colors.green,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _selectedPosition!,
              initialZoom: 14,
              onTap: (tapPos, point) {
                setState(() => _selectedPosition = point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.thunderforest.com/atlas/{z}/{x}/{y}.png?apikey=12183dd51e894a75b97d6786c14a83ac',
                userAgentPackageName: 'com.example.delivery_frontend',
              ),
              if (_selectedPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPosition!,
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
            bottom: 30,
            left: 60,
            right: 60,
            child: ElevatedButton(
              onPressed: () {
                widget.onPositionSelected(_selectedPosition!);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text("เลือกตำแหน่งนี้",
                  style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }
}
