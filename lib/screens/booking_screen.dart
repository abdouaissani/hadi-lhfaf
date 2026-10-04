import 'package:flutter/material.dart';

import 'my_bookings_screen.dart';
import '../models/service_model.dart';
import '../services/customer_storage.dart';
import '../services/supabase_service.dart';
import 'queue_screen.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({
    super.key,
  });

  @override
  State<BookingScreen> createState() =>
      _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final SupabaseService _service =
      SupabaseService();

  final TextEditingController _nameController =
      TextEditingController();

  final TextEditingController _phoneController =
      TextEditingController();

  List<ServiceModel> _services = [];

  String? _barberId;
  String? _selectedServiceId;

  bool _loadingServices = true;
  bool _booking = false;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  // =========================================================
  // LOAD BARBER + SERVICES
  // =========================================================

  Future<void> _loadServices() async {
    try {
      final String? barberId =
          await _service.getSingleBarber();

      if (barberId == null ||
          barberId.trim().isEmpty) {
        throw Exception('NO_BARBER_FOUND');
      }

      debugPrint(
        'CUSTOMER BARBER ID: $barberId',
      );

      final List<ServiceModel> services =
          await _service.getServices(
        barberId,
      );

      debugPrint(
        'CUSTOMER SERVICES: ${services.length}',
      );

      if (!mounted) return;

      setState(() {
        _barberId = barberId;
        _services = services;
        _loadingServices = false;

        if (_services.isNotEmpty) {
          _selectedServiceId =
              _services.first.id;
        } else {
          _selectedServiceId = null;
        }
      });
    } catch (e, stackTrace) {
      debugPrint(
        'LOAD SERVICES ERROR: $e',
      );

      debugPrint(
        '$stackTrace',
      );

      if (!mounted) return;

      setState(() {
        _services = [];
        _loadingServices = false;
        _barberId = null;
        _selectedServiceId = null;
      });

      if (e.toString().contains(
        'NO_BARBER_FOUND',
      )) {
        _showMessage(
          'لم يتم العثور على الحلاق',
        );
      } else {
        _showMessage(
          'تعذر تحميل الخدمات',
        );
      }
    }
  }

  // =========================================================
  // REFRESH
  // =========================================================

  Future<void> _refresh() async {
    if (_booking) return;

    try {
      String? barberId = _barberId;

      // -------------------------------------------------------
      // GET BARBER IF NOT AVAILABLE
      // -------------------------------------------------------

      if (barberId == null ||
          barberId.trim().isEmpty) {
        barberId =
            await _service.getSingleBarber();

        if (!mounted) return;

        if (barberId == null ||
            barberId.trim().isEmpty) {
          throw Exception('NO_BARBER_FOUND');
        }

        setState(() {
          _barberId = barberId;
        });
      }

      // -------------------------------------------------------
      // GET SERVICES
      // -------------------------------------------------------

      final List<ServiceModel> services =
          await _service.getServices(
        barberId,
      );

      debugPrint(
        'REFRESH SERVICES: ${services.length}',
      );

      if (!mounted) return;

      setState(() {
        _services = services;
        _loadingServices = false;

        if (_services.isEmpty) {
          _selectedServiceId = null;
        } else if (!_services.any(
          (service) =>
              service.id ==
              _selectedServiceId,
        )) {
          _selectedServiceId =
              _services.first.id;
        }
      });
    } catch (e, stackTrace) {
      debugPrint(
        'REFRESH ERROR: $e',
      );

      debugPrint(
        '$stackTrace',
      );

      if (!mounted) return;

      _showMessage(
        'تعذر تحديث الخدمات',
      );
    }
  }

  // =========================================================
  // BOOK QUEUE
  // =========================================================

  Future<void> _bookQueue() async {
    if (_booking) return;

    FocusScope.of(context).unfocus();

    final String name =
        _nameController.text.trim();

    final String phone =
        _phoneController.text.trim();

    // -------------------------------------------------------
    // BARBER
    // -------------------------------------------------------

    if (_barberId == null ||
        _barberId!.trim().isEmpty) {
      _showMessage(
        'تعذر العثور على الحلاق',
      );
      return;
    }

    // -------------------------------------------------------
    // NAME
    // -------------------------------------------------------

    if (name.isEmpty) {
      _showMessage(
        'أدخل الاسم واللقب',
      );
      return;
    }

    // -------------------------------------------------------
    // PHONE
    // -------------------------------------------------------

    if (phone.isEmpty) {
      _showMessage(
        'أدخل رقم الهاتف',
      );
      return;
    }

    // -------------------------------------------------------
    // SERVICE
    // -------------------------------------------------------

    if (_selectedServiceId == null ||
        _selectedServiceId!.trim().isEmpty) {
      _showMessage(
        'اختر الخدمة',
      );
      return;
    }

    setState(() {
      _booking = true;
    });

    try {
      // =======================================================
      // CREATE BOOKING
      // =======================================================

      final Map<String, dynamic> result =
          await _service.createBooking(
        barberId: _barberId!,
        serviceId: _selectedServiceId!,
        name: name,
        phone: phone,
      );

      debugPrint(
        'BOOKING RESULT: $result',
      );

      // =======================================================
      // GET TICKET ID
      // =======================================================

      final String? ticketId =
          result['id']?.toString();

      if (ticketId == null ||
          ticketId.isEmpty ||
          ticketId == 'null') {
        throw Exception(
          'TICKET_ID_NOT_FOUND',
        );
      }

      // =======================================================
      // SAVE TICKET LOCALLY
      // =======================================================

      await CustomerStorage.saveTicketId(
        ticketId,
      );

      debugPrint(
        'TICKET SAVED LOCALLY: $ticketId',
      );

      // =======================================================
      // SAVE CUSTOMER TOKEN
      // =======================================================

      final String? token =
          result['customer_token']
              ?.toString();

      if (token != null &&
          token.isNotEmpty &&
          token != 'null') {
        await CustomerStorage.saveToken(
          token,
        );

        debugPrint(
          'CUSTOMER TOKEN SAVED',
        );
      }

      if (!mounted) return;

      // =======================================================
      // SUCCESS MESSAGE
      // =======================================================

      _showMessage(
        'تم حجز دورك بنجاح 🎫',
      );

      await Future.delayed(
        const Duration(
          milliseconds: 400,
        ),
      );

      if (!mounted) return;

      // =======================================================
      // OPEN QUEUE SCREEN
      // =======================================================

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QueueScreen(
            ticketId: ticketId,
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint(
        'BOOKING ERROR: $e',
      );

      debugPrint(
        '$stackTrace',
      );

      if (!mounted) return;

      final String error =
          e.toString();

      // -------------------------------------------------------
      // QUEUE CLOSED
      // -------------------------------------------------------

      if (error.contains(
        'QUEUE_CLOSED',
      )) {
        _showMessage(
          'الحجز مغلق حالياً',
        );
      }

      // -------------------------------------------------------
      // QUEUE FULL
      // -------------------------------------------------------

      else if (error.contains(
        'QUEUE_FULL',
      )) {
        _showMessage(
          'الطابور ممتلئ حالياً',
        );
      }

      // -------------------------------------------------------
      // INVALID SERVICE
      // -------------------------------------------------------

      else if (error.contains(
        'INVALID_SERVICE',
      )) {
        _showMessage(
          'الخدمة غير متاحة',
        );
      }

      // -------------------------------------------------------
      // BARBER NOT FOUND
      // -------------------------------------------------------

      else if (error.contains(
        'BARBER_NOT_FOUND',
      )) {
        _showMessage(
          'الحلاق غير موجود',
        );
      }

      // -------------------------------------------------------
      // TICKET NOT FOUND
      // -------------------------------------------------------

      else if (error.contains(
        'TICKET_ID_NOT_FOUND',
      )) {
        _showMessage(
          'تم الحجز لكن تعذر الحصول على رقم الدور',
        );
      }

      // -------------------------------------------------------
      // GENERIC ERROR
      // -------------------------------------------------------

      else {
        _showMessage(
          'حدث خطأ أثناء الحجز',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _booking = false;
        });
      }
    }
  }

  // =========================================================
  // MESSAGE
  // =========================================================

  void _showMessage(
    String message,
  ) {
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
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();

    super.dispose();
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0D1726);
    const gold = Color(0xFFD7A84B);
    final bool canBook =
        !_booking &&
        !_loadingServices &&
        _barberId != null &&
        _barberId!.isNotEmpty &&
        _services.isNotEmpty &&
        _selectedServiceId != null;

    InputDecoration fieldDecoration({
      required String label,
      required IconData icon,
      String? hint,
    }) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: navy),
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE7E9EE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: gold, width: 1.5),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6F8),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'حجز دور',
            style: TextStyle(color: navy, fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث الخدمات',
              onPressed: _booking ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded, color: navy),
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            color: gold,
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [Color(0xFF15233A), Color(0xFF0D1726)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: navy.withValues(alpha: .18),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Column(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Color(0x22D7A84B),
                          child: Icon(Icons.content_cut_rounded, color: gold, size: 30),
                        ),
                        SizedBox(height: 14),
                        Text(
                          'LHadi Coiffure',
                          style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'احجز دورك بسهولة وبدون انتظار',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE7E9EE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('بيانات الزبون', style: TextStyle(color: navy, fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 15),
                        TextField(
                          controller: _nameController,
                          enabled: !_booking,
                          textInputAction: TextInputAction.next,
                          decoration: fieldDecoration(label: 'الاسم واللقب', icon: Icons.person_outline_rounded, hint: 'مثال: محمد بن علي'),
                        ),
                        const SizedBox(height: 13),
                        TextField(
                          controller: _phoneController,
                          enabled: !_booking,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          decoration: fieldDecoration(label: 'رقم الهاتف', icon: Icons.phone_outlined, hint: '05xxxxxxxx'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE7E9EE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.content_cut_rounded, color: navy),
                            SizedBox(width: 10),
                            Text('اختر الخدمة', style: TextStyle(color: navy, fontSize: 18, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        const SizedBox(height: 13),
                        if (_loadingServices)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator(color: gold)),
                          )
                        else if (_services.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(color: const Color(0xFFF7F8FA), borderRadius: BorderRadius.circular(16)),
                            child: const Text('لا توجد خدمات متاحة حالياً', textAlign: TextAlign.center),
                          )
                        else
                          DropdownButtonFormField<String>(
                            initialValue: _selectedServiceId,
                            decoration: fieldDecoration(label: 'الخدمة', icon: Icons.spa_outlined),
                            items: _services.map((service) {
                              return DropdownMenuItem<String>(
                                value: service.id,
                                child: Text('${service.name}  •  ${service.price.toStringAsFixed(0)} DA', overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: _booking ? null : (value) => setState(() => _selectedServiceId = value),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 58,
                    child: FilledButton.icon(
                      onPressed: canBook ? _bookQueue : null,
                      icon: _booking
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.confirmation_number_outlined),
                      label: Text(_booking ? 'جاري الحجز...' : 'احجز دوري', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      style: FilledButton.styleFrom(
                        backgroundColor: navy,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFD7D9DE),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _booking ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyBookingsScreen())),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('حجوزاتي', style: TextStyle(fontWeight: FontWeight.w800)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: navy,
                      minimumSize: const Size.fromHeight(52),
                      side: const BorderSide(color: Color(0xFFD9DCE2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('حجزك محفوظ على هذا الهاتف ويمكنك متابعته في أي وقت.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
