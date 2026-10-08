import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/delivery_address_details.dart';

class CheckoutLocationMap extends StatefulWidget {
  final double? latitude, longitude;
  final bool enabled;
  final ValueChanged<LatLng> onSelected;
  final TileProvider? tileProvider;
  const CheckoutLocationMap({
    super.key,
    this.latitude,
    this.longitude,
    this.enabled = true,
    required this.onSelected,
    this.tileProvider,
  });
  @override
  State<CheckoutLocationMap> createState() => _CheckoutLocationMapState();
}

class _CheckoutLocationMapState extends State<CheckoutLocationMap> {
  final MapController _controller = MapController();
  bool _ready = false;
  // Viewport only: never submitted as a selected customer location.
  static const _initialView = LatLng(9.0765, 7.3986);
  bool get _selected =>
      validDeliveryCoordinates(widget.latitude, widget.longitude);
  @override
  void didUpdateWidget(CheckoutLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready &&
        _selected &&
        (oldWidget.latitude != widget.latitude ||
            oldWidget.longitude != widget.longitude)) {
      final next = LatLng(widget.latitude!, widget.longitude!);
      final center = _controller.camera.center;
      if ((center.latitude - next.latitude).abs() > 0.000001 ||
          (center.longitude - next.longitude).abs() > 0.000001) {
        _controller.move(
          next,
          validDeliveryCoordinates(oldWidget.latitude, oldWidget.longitude)
              ? _controller.camera.zoom
              : 16,
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 230,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: _selected
                      ? LatLng(widget.latitude!, widget.longitude!)
                      : _initialView,
                  initialZoom: _selected ? 16 : 11,
                  onMapReady: () {
                    _ready = true;
                  },
                  interactionOptions: InteractionOptions(
                    flags: widget.enabled
                        ? InteractiveFlag.drag |
                              InteractiveFlag.pinchZoom |
                              InteractiveFlag.doubleTapZoom
                        : InteractiveFlag.none,
                  ),
                  onTap: (_, point) {
                    if (widget.enabled) {
                      _controller.move(point, _controller.camera.zoom);
                      widget.onSelected(point);
                    }
                  },
                  onPositionChanged: (camera, hasGesture) {
                    if (hasGesture && widget.enabled) {
                      widget.onSelected(camera.center);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.naijago.naija_go',
                    tileProvider: widget.tileProvider,
                  ),
                ],
              ),
              Center(
                child: IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 48),
                    child: Icon(
                      Icons.location_pin,
                      key: const Key('delivery-location-pin'),
                      size: 48,
                      color: _selected ? const Color(0xFF000080) : Colors.grey,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 6,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(3),
                  child: const Text(
                    '? OpenStreetMap contributors',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        _selected
            ? 'Drag the map or tap to move your delivery pin.'
            : 'Search, use GPS, or tap the map to select a delivery location.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}
