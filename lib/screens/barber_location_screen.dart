import 'package:flutter/material.dart';

import '../services/supabase_service.dart';

class BarberLocationScreen extends StatefulWidget {
  final String barberId;

  const BarberLocationScreen({
    super.key,
    required this.barberId,
  });

  @override
  State<BarberLocationScreen> createState() =>
      _BarberLocationScreenState();
}

class _BarberLocationScreenState
    extends State<BarberLocationScreen> {
  final SupabaseService _service = SupabaseService();

  final TextEditingController _locationController =
      TextEditingController();

  final TextEditingController _latitudeController =
      TextEditingController();

  final TextEditingController _longitudeController =
      TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      final data = await _service.getBarberLocation(
        widget.barberId,
      );

      if (!mounted) return;

      final latitude =
          (data?['latitude'] as num?)?.toDouble();
      final longitude =
          (data?['longitude'] as num?)?.toDouble();

      if (latitude != null && longitude != null) {
        _latitudeController.text =
            latitude.toString();
        _longitudeController.text =
            longitude.toString();
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'تعذر تحميل موقع المحل: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // =========================================================
  // PARSE COPIED LOCATION
  // =========================================================

  void _pasteLocation() {
    final text = _locationController.text.trim();

    if (text.isEmpty) {
      _showMessage(
        'الصق رابط Google Maps أو الإحداثيات أولاً',
      );
      return;
    }

    // يدعم مثلاً:
    // 33.5731,-7.5898
    // 33.5731, -7.5898
    // https://www.google.com/maps/@33.5731,-7.5898,17z
    // https://maps.google.com/?q=33.5731,-7.5898
    final regex = RegExp(
      r'(-?\d+(?:\.\d+)?)\s*[,;]\s*(-?\d+(?:\.\d+)?)',
    );

    final match = regex.firstMatch(text);

    if (match == null) {
      _showMessage(
        'لم أستطع استخراج الإحداثيات من النص',
      );
      return;
    }

    final latitude =
        double.tryParse(match.group(1) ?? '');
    final longitude =
        double.tryParse(match.group(2) ?? '');

    if (!_validCoordinates(latitude, longitude)) {
      _showMessage(
        'الإحداثيات غير صحيحة',
      );
      return;
    }

    _latitudeController.text =
        latitude!.toString();
    _longitudeController.text =
        longitude!.toString();

    FocusScope.of(context).unfocus();

    _showMessage(
      'تم استخراج الموقع بنجاح 📍',
    );
  }

  bool _validCoordinates(
    double? latitude,
    double? longitude,
  ) {
    if (latitude == null || longitude == null) {
      return false;
    }

    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  // =========================================================
  // SAVE
  // =========================================================

  Future<void> _saveLocation() async {
    if (_saving) return;

    final latitude = double.tryParse(
      _latitudeController.text.trim().replaceAll(',', '.'),
    );

    final longitude = double.tryParse(
      _longitudeController.text.trim().replaceAll(',', '.'),
    );

    if (!_validCoordinates(latitude, longitude)) {
      _showMessage(
        'أدخل إحداثيات صحيحة: خط العرض وخط الطول',
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
    });

    try {
      await _service.updateBarberLocation(
        barberId: widget.barberId,
        latitude: latitude!,
        longitude: longitude!,
      );

      if (!mounted) return;

      _showMessage(
        'تم حفظ موقع المحل بنجاح 📍',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'تعذر حفظ الموقع: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.right,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _locationController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0D1726);
    const gold = Color(0xFFD7A84B);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6F8),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          title: const Text('موقع المحل', style: TextStyle(color: navy, fontWeight: FontWeight.w900)),
          centerTitle: true,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: gold))
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF182A45), navy]),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: const Row(
                          children: [
                            CircleAvatar(backgroundColor: Color(0x22D7A84B), child: Icon(Icons.location_on_rounded, color: gold)),
                            SizedBox(width: 13),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('موقع Hadi Coiffure', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)), SizedBox(height: 4), Text('حدّد موقع المحل ليظهر للزبائن بدقة.', style: TextStyle(color: Colors.white70))])),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE7E9EE))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          TextField(
                            controller: _locationController,
                            maxLines: 3,
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              labelText: 'رابط Google Maps أو الإحداثيات',
                              hintText: '33.5731,-7.5898',
                              prefixIcon: const Icon(Icons.link_rounded, color: navy),
                              suffixIcon: IconButton(onPressed: _pasteLocation, icon: const Icon(Icons.my_location_rounded, color: gold)),
                              filled: true,
                              fillColor: const Color(0xFFF7F8FA),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(onPressed: _pasteLocation, icon: const Icon(Icons.location_searching_rounded), label: const Text('استخراج الإحداثيات')), 
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(child: TextField(controller: _latitudeController, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'خط العرض', prefixIcon: Icon(Icons.north_rounded)))),
                            const SizedBox(width: 10),
                            Expanded(child: TextField(controller: _longitudeController, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'خط الطول', prefixIcon: Icon(Icons.east_rounded)))),
                          ]),
                          const SizedBox(height: 18),
                          SizedBox(height: 56, child: FilledButton.icon(onPressed: _saving ? null : _saveLocation, icon: _saving ? const SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded), label: Text(_saving ? 'جاري الحفظ...' : 'حفظ موقع المحل', style: const TextStyle(fontWeight: FontWeight.w900)), style: FilledButton.styleFrom(backgroundColor: navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))))),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
