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

class _BookingScreenState
    extends State<BookingScreen> {
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
      final String barberId =
          await _service.getSingleBarber();

      final List<ServiceModel> services =
          await _service.getServices(
        barberId,
      );

      if (!mounted) return;

      setState(() {
        _barberId = barberId;
        _services = services;
        _loadingServices = false;

        if (_services.isNotEmpty) {
          _selectedServiceId =
              _services.first.id;
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
        _loadingServices = false;
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
  // BOOK
  // =========================================================

  Future<void> _bookQueue() async {
    if (_booking) return;

    FocusScope.of(context).unfocus();

    final String name =
        _nameController.text.trim();

    final String phone =
        _phoneController.text.trim();

    if (_barberId == null) {
      _showMessage(
        'تعذر العثور على الحلاق',
      );
      return;
    }

    if (name.isEmpty) {
      _showMessage(
        'أدخل الاسم واللقب',
      );
      return;
    }

    if (phone.isEmpty) {
      _showMessage(
        'أدخل رقم الهاتف',
      );
      return;
    }

    if (_selectedServiceId == null) {
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
      // SAVE TOKEN IF AVAILABLE
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
      }

      if (!mounted) return;

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
      // OPEN QUEUE
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

      if (error.contains(
        'QUEUE_CLOSED',
      )) {
        _showMessage(
          'الحجز مغلق حالياً',
        );
      } else if (error.contains(
        'QUEUE_FULL',
      )) {
        _showMessage(
          'الطابور ممتلئ حالياً',
        );
      } else if (error.contains(
        'INVALID_SERVICE',
      )) {
        _showMessage(
          'الخدمة غير متاحة',
        );
      } else {
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
  Widget build(
    BuildContext context,
  ) {
    final bool canBook =
        !_booking &&
        !_loadingServices &&
        _barberId != null &&
        _services.isNotEmpty &&
        _selectedServiceId != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'حجز دور',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 15),

                const Icon(
                  Icons.content_cut,
                  size: 70,
                ),

                const SizedBox(height: 15),

                const Text(
                  'احجز دورك بسهولة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'أدخل معلوماتك واختر الخدمة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 30),

                // =================================================
                // NAME
                // =================================================

                TextField(
                  controller: _nameController,
                  enabled: !_booking,
                  textInputAction:
                      TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'الاسم واللقب',
                    hintText: 'مثال: محمد بن علي',
                    prefixIcon: const Icon(
                      Icons.person_outline,
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // =================================================
                // PHONE
                // =================================================

                TextField(
                  controller: _phoneController,
                  enabled: !_booking,
                  keyboardType:
                      TextInputType.phone,
                  textInputAction:
                      TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف',
                    hintText: '05xxxxxxxx',
                    prefixIcon: const Icon(
                      Icons.phone_outlined,
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // =================================================
                // SERVICES
                // =================================================

                if (_loadingServices)
                  const Center(
                    child: Padding(
                      padding:
                          EdgeInsets.all(20),
                      child:
                          CircularProgressIndicator(),
                    ),
                  )
                else if (_services.isEmpty)
                  Container(
                    padding:
                        const EdgeInsets.all(18),
                    decoration:
                        BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(14),
                      color:
                          Colors.grey.shade100,
                    ),
                    child: const Text(
                      'لا توجد خدمات متاحة حالياً',
                      textAlign:
                          TextAlign.center,
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue:
                        _selectedServiceId,
                    decoration:
                        InputDecoration(
                      labelText:
                          'اختر الخدمة',
                      prefixIcon:
                          const Icon(
                        Icons.content_cut,
                      ),
                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                    ),
                    items:
                        _services.map(
                      (service) {
                        return DropdownMenuItem<
                            String>(
                          value:
                              service.id,
                          child: Text(
                            '${service.name} - ${service.price.toStringAsFixed(0)} DA',
                          ),
                        );
                      },
                    ).toList(),
                    onChanged: _booking
                        ? null
                        : (value) {
                            setState(() {
                              _selectedServiceId =
                                  value;
                            });
                          },
                  ),

                const SizedBox(height: 30),

                // =================================================
                // BOOK BUTTON
                // =================================================

                SizedBox(
                  height: 58,
                  child: FilledButton.icon(
                    onPressed:
                        canBook
                            ? _bookQueue
                            : null,
                    icon: _booking
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons
                                .confirmation_number,
                          ),
                    label: Text(
                      _booking
                          ? 'جاري الحجز...'
                          : 'احجز دوري',
                      style:
                          const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // =================================================
                // MY BOOKINGS BUTTON
                // =================================================

                OutlinedButton.icon(
                  onPressed: _booking
                      ? null
                      : () {
                          Navigator.of(
                            context,
                          ).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                   MyBookingsScreen(),
                            ),
                          );
                        },
                  icon: const Icon(
                    Icons.receipt_long_outlined,
                  ),
                  label: const Text(
                    'عرض حجوزاتي',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'حجزك سيبقى محفوظاً على هذا الهاتف',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}