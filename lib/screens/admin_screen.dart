import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import 'barber_location_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // =========================================================
  // COLORS
  // =========================================================

  static const Color navy = Color(0xFF0D1726);
  static const Color navyLight = Color(0xFF182A45);
  static const Color gold = Color(0xFFD7A84B);
  static const Color background = Color(0xFFF5F6F8);
  static const Color green = Color(0xFF19A463);
  static const Color red = Color(0xFFE5484D);
  static const Color orange = Color(0xFFE99A35);

  final SupabaseService _service = SupabaseService();

  String? _barberId;

  bool _loading = true;
  bool _queueEnabled = true;
  bool _nextLoading = false;
  bool _logoutLoading = false;

  List<Map<String, dynamic>> _services = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // =========================================================
  // INITIALIZE
  // =========================================================

  Future<void> _initialize() async {
    try {
      final user = _service.currentUser;

      if (user == null) {
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      _barberId = user.id;

      final enabled = await _service.isQueueEnabled(user.id);

      await _loadServices();

      if (!mounted) return;

      setState(() {
        _queueEnabled = enabled;
        _loading = false;
      });
    } catch (e) {
      debugPrint('INITIALIZE ERROR: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage('تعذر تحميل لوحة التحكم');
    }
  }

  // =========================================================
  // LOAD SERVICES
  // =========================================================

  Future<void> _loadServices() async {
    if (_barberId == null) return;

    try {
      final services =
          await _service.getAllServices(_barberId!);

      if (!mounted) return;

      setState(() {
        _services = services;
      });
    } catch (e) {
      debugPrint('LOAD SERVICES ERROR: $e');

      if (!mounted) return;

      _showMessage('تعذر تحميل الخدمات');
    }
  }

  // =========================================================
  // NEXT CUSTOMER
  // =========================================================

  Future<void> _nextCustomer() async {
    if (_barberId == null || _nextLoading) return;

    setState(() {
      _nextLoading = true;
    });

    try {
      final result =
          await _service.nextQueueTicket(_barberId!);

      if (!mounted) return;

      final message =
          result['message']?.toString();

      if (message == 'NO_MORE_CUSTOMERS') {
        _showMessage(
          'لا يوجد زبائن في الانتظار',
        );
      } else {
        final number =
            result['ticket_number']?.toString();

        _showMessage(
          number == null
              ? 'تم استدعاء الزبون التالي'
              : 'تم استدعاء الزبون رقم $number',
        );
      }
    } catch (e) {
      debugPrint('NEXT CUSTOMER ERROR: $e');

      if (!mounted) return;

      _showMessage(
        'حدث خطأ أثناء استدعاء الدور التالي',
      );
    } finally {
      if (mounted) {
        setState(() {
          _nextLoading = false;
        });
      }
    }
  }

  // =========================================================
  // TOGGLE QUEUE
  // =========================================================

  Future<void> _toggleQueue(bool value) async {
    if (_barberId == null) return;

    final oldValue = _queueEnabled;

    setState(() {
      _queueEnabled = value;
    });

    try {
      await _service.setQueueEnabled(
        _barberId!,
        value,
      );

      if (!mounted) return;

      _showMessage(
        value
            ? 'تم فتح استقبال الحجوزات'
            : 'تم إغلاق استقبال الحجوزات',
      );
    } catch (e) {
      debugPrint('QUEUE TOGGLE ERROR: $e');

      if (!mounted) return;

      setState(() {
        _queueEnabled = oldValue;
      });

      _showMessage(
        'تعذر تغيير حالة الحجز',
      );
    }
  }

  // =========================================================
  // LOCATION
  // =========================================================

  Future<void> _openLocation() async {
    if (_barberId == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BarberLocationScreen(
          barberId: _barberId!,
        ),
      ),
    );
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> _logout() async {
    if (_logoutLoading) return;

    setState(() {
      _logoutLoading = true;
    });

    try {
      await _service.barberLogout();

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('LOGOUT ERROR: $e');

      if (!mounted) return;

      setState(() {
        _logoutLoading = false;
      });

      _showMessage(
        'تعذر تسجيل الخروج',
      );
    }
  }

  // =========================================================
  // ADD SERVICE
  // =========================================================

  Future<void> _showAddServiceDialog() async {
    final result =
        await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) {
        return const _ServiceDialog(
          title: 'إضافة خدمة',
          buttonText: 'إضافة',
        );
      },
    );

    if (!mounted || result == null) return;

    final name =
        result['name']?.toString() ?? '';

    final price =
        result['price'] as double?;

    if (name.isEmpty || price == null) return;

    try {
      await _service.addService(
        barberId: _barberId!,
        name: name,
        price: price,
      );

      await _loadServices();

      if (!mounted) return;

      _showMessage(
        'تمت إضافة الخدمة بنجاح',
      );
    } catch (e) {
      debugPrint(
        'ADD SERVICE ERROR: $e',
      );

      if (!mounted) return;

      _showMessage(
        'تعذر إضافة الخدمة',
      );
    }
  }

  // =========================================================
  // EDIT SERVICE
  // =========================================================

  Future<void> _showEditServiceDialog(
    Map<String, dynamic> service,
  ) async {
    final id =
        service['id']?.toString();

    if (id == null || id.isEmpty) return;

    final oldName =
        service['name']?.toString() ?? '';

    final oldPrice =
        double.tryParse(
              service['price']?.toString() ?? '0',
            ) ??
            0;

    final result =
        await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) {
        return _ServiceDialog(
          title: 'تعديل الخدمة',
          buttonText: 'حفظ',
          initialName: oldName,
          initialPrice: oldPrice,
        );
      },
    );

    if (!mounted || result == null) return;

    final name =
        result['name']?.toString() ?? '';

    final price =
        result['price'] as double?;

    if (name.isEmpty || price == null) return;

    try {
      await _service.updateService(
        serviceId: id,
        name: name,
        price: price,
      );

      await _loadServices();

      if (!mounted) return;

      _showMessage(
        'تم تعديل الخدمة',
      );
    } catch (e) {
      debugPrint(
        'UPDATE SERVICE ERROR: $e',
      );

      if (!mounted) return;

      _showMessage(
        'تعذر تعديل الخدمة',
      );
    }
  }

  // =========================================================
  // TOGGLE SERVICE
  // =========================================================

  Future<void> _toggleService(
    Map<String, dynamic> service,
    bool value,
  ) async {
    final id =
        service['id']?.toString();

    if (id == null || id.isEmpty) return;

    try {
      await _service.setServiceActive(
        serviceId: id,
        active: value,
      );

      await _loadServices();

      if (!mounted) return;

      _showMessage(
        value
            ? 'تم تفعيل الخدمة'
            : 'تم تعطيل الخدمة',
      );
    } catch (e) {
      debugPrint(
        'TOGGLE SERVICE ERROR: $e',
      );

      if (!mounted) return;

      _showMessage(
        'تعذر تغيير حالة الخدمة',
      );
    }
  }

  // =========================================================
  // DELETE SERVICE
  // =========================================================

  Future<void> _deleteService(
    Map<String, dynamic> service,
  ) async {
    final id =
        service['id']?.toString();

    if (id == null || id.isEmpty) return;

    final name =
        service['name']?.toString() ??
            'هذه الخدمة';

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(24),
            ),
            title: const Text(
              'حذف الخدمة',
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
            content: Text(
              'هل أنت متأكد من حذف "$name"؟',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    false,
                  );
                },
                child: const Text(
                  'إلغاء',
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: red,
                ),
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                },
                child: const Text(
                  'حذف',
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    try {
      await _service.deleteService(id);

      await _loadServices();

      if (!mounted) return;

      _showMessage(
        'تم حذف الخدمة',
      );
    } catch (e) {
      debugPrint(
        'DELETE SERVICE ERROR: $e',
      );

      if (!mounted) return;

      _showMessage(
        'تعذر حذف الخدمة',
      );
    }
  }

  // =========================================================
  // MESSAGE
  // =========================================================

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
        behavior:
            SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // =========================================================
  // TODAY
  // =========================================================

  String _todayDate() {
    final now = DateTime.now();

    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // =========================================================
  // SECTION TITLE
  // =========================================================

  Widget _sectionTitle({
    required String title,
    String? subtitle,
    Widget? action,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: navy,
                  fontSize: 20,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null) action,
      ],
    );
  }

  // =========================================================
  // QUEUE CONTROL
  // =========================================================

  Widget _buildQueueControl() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: .05),
            blurRadius: 20,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _queueEnabled
                  ? green.withValues(alpha: .10)
                  : red.withValues(alpha: .10),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: Icon(
              _queueEnabled
                  ? Icons.lock_open_rounded
                  : Icons.lock_rounded,
              color: _queueEnabled
                  ? green
                  : red,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'استقبال الحجوزات',
                  style: TextStyle(
                    color: navy,
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _queueEnabled
                      ? 'الحجز مفتوح الآن'
                      : 'الحجز مغلق الآن',
                  style: TextStyle(
                    color: _queueEnabled
                        ? green
                        : red,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _queueEnabled,
            activeColor: gold,
            onChanged: _toggleQueue,
          ),
        ],
      ),
    );
  }

  // =========================================================
  // CURRENT SERVING
  // =========================================================

  Widget _buildCurrentServing(
    List<Map<String, dynamic>> todayTickets,
  ) {
    final serving =
        todayTickets.where(
      (ticket) =>
          ticket['status']
              ?.toString()
              .toLowerCase() ==
          'serving',
    ).toList();

    int number = 0;

    if (serving.isNotEmpty) {
      number =
          int.tryParse(
                serving.first[
                            'ticket_number']
                        ?.toString() ??
                    '',
              ) ??
              0;
    }

    final waiting =
        todayTickets.where(
      (ticket) =>
          ticket['status']
              ?.toString()
              .toLowerCase() ==
          'waiting',
    ).length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            navyLight,
            navy,
          ],
        ),
        borderRadius:
            BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color:
                navy.withValues(alpha: .18),
            blurRadius: 24,
            offset:
                const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: gold.withValues(
                    alpha: .14,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: const Icon(
                  Icons.person_pin_circle_rounded,
                  color: gold,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الدور الحالي',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'الزبون الموجود على الكرسي',
                      style: TextStyle(
                        color:
                            Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: green.withValues(
                    alpha: .15,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: Text(
                  '$waiting منتظر',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(
              vertical: 20,
            ),
            decoration: BoxDecoration(
              color: Colors.white
                  .withValues(alpha: .07),
              borderRadius:
                  BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white
                    .withValues(alpha: .08),
              ),
            ),
            child: Column(
              children: [
                Text(
                  number == 0
                      ? '--'
                      : '#$number',
                  style: const TextStyle(
                    color: gold,
                    fontSize: 56,
                    height: 1,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  number == 0
                      ? 'لا يوجد زبون حالياً'
                      : 'يتم خدمته الآن',
                  style: const TextStyle(
                    color:
                        Colors.white70,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: navy,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    17,
                  ),
                ),
              ),
              onPressed:
                  _nextLoading
                      ? null
                      : _nextCustomer,
              icon: _nextLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons
                          .arrow_back_rounded,
                    ),
              label: Text(
                _nextLoading
                    ? 'جاري الاستدعاء...'
                    : 'استدعاء الزبون التالي',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // WAITING SECTION
  // =========================================================

  Widget _buildWaitingSection(
    List<Map<String, dynamic>> todayTickets,
  ) {
    final waiting =
        todayTickets.where(
      (ticket) =>
          ticket['status']
              ?.toString()
              .toLowerCase() ==
          'waiting',
    ).toList();

    waiting.sort((a, b) {
      final aNumber =
          int.tryParse(
                a['ticket_number']
                        ?.toString() ??
                    '',
              ) ??
              0;

      final bNumber =
          int.tryParse(
                b['ticket_number']
                        ?.toString() ??
                    '',
              ) ??
              0;

      return aNumber.compareTo(bNumber);
    });

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          title: 'قائمة الانتظار',
          subtitle:
              'الزبائن المنتظرون اليوم',
          action: Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: gold.withValues(
                alpha: .12,
              ),
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
            ),
            child: Text(
              '${waiting.length}',
              style: const TextStyle(
                color: navy,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (waiting.isEmpty)
          _emptyCard(
            icon:
                Icons.event_available_rounded,
            title:
                'لا يوجد زبائن في الانتظار',
            subtitle:
                'قائمة الانتظار فارغة حالياً',
          )
        else
          ...waiting.map(
            (ticket) {
              final number =
                  ticket['ticket_number']
                          ?.toString() ??
                      '--';

              final name =
                  ticket['customer_name']
                          ?.toString() ??
                      'بدون اسم';

              final phone =
                  ticket['phone']
                          ?.toString() ??
                      '';

              return Container(
                margin:
                    const EdgeInsets.only(
                  bottom: 10,
                ),
                padding:
                    const EdgeInsets.all(
                  15,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(
                        alpha: .035,
                      ),
                      blurRadius: 14,
                      offset:
                          const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment:
                          Alignment.center,
                      decoration:
                          BoxDecoration(
                        color:
                            navy,
                        borderRadius:
                            BorderRadius
                                .circular(
                          15,
                        ),
                      ),
                      child: Text(
                        '#$number',
                        style:
                            const TextStyle(
                          color:
                              gold,
                          fontSize:
                              13,
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 13,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            name,
                            style:
                                const TextStyle(
                              color:
                                  navy,
                              fontSize:
                                  14,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                          if (phone
                              .isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets
                                      .only(
                                top: 4,
                              ),
                              child: Text(
                                phone,
                                style:
                                    TextStyle(
                                  color: Colors
                                      .grey
                                      .shade600,
                                  fontSize:
                                      11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 9,
                        vertical: 7,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            orange.withValues(
                          alpha: .10,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                      ),
                      child: const Icon(
                        Icons
                            .hourglass_top_rounded,
                        color:
                            orange,
                        size: 19,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // =========================================================
  // LOCATION CARD
  // =========================================================

  Widget _buildLocationCard() {
    return InkWell(
      borderRadius:
          BorderRadius.circular(22),
      onTap: _openLocation,
      child: Container(
        padding:
            const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(
                alpha: .045,
              ),
              blurRadius: 18,
              offset:
                  const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: red.withValues(
                  alpha: .10,
                ),
                borderRadius:
                    BorderRadius.circular(
                  17,
                ),
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: red,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'موقع المحل',
                    style: TextStyle(
                      color: navy,
                      fontSize: 15,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'حدد أو عدّل موقع LHadi Coiffure على الخريطة',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: navy.withValues(
                  alpha: .06,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: navy,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // SERVICES
  // =========================================================

  Widget _buildServicesSection() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          title: 'الخدمات',
          subtitle:
              'إدارة خدمات وأسعار الحلاق',
          action: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: navy,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),
            ),
            onPressed:
                _showAddServiceDialog,
            icon: const Icon(
              Icons.add_rounded,
              size: 18,
            ),
            label: const Text(
              'إضافة',
              style: TextStyle(
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_services.isEmpty)
          _emptyCard(
            icon:
                Icons.content_cut_rounded,
            title:
                'لا توجد خدمات',
            subtitle:
                'أضف أول خدمة للحلاق',
          )
        else
          ..._services.map(
            (service) {
              final name =
                  service['name']
                          ?.toString() ??
                      'بدون اسم';

              final price =
                  double.tryParse(
                        service['price']
                                ?.toString() ??
                            '0',
                      ) ??
                      0;

              final active =
                  service['is_active'] ==
                      true;

              return Container(
                margin:
                    const EdgeInsets.only(
                  bottom: 10,
                ),
                padding:
                    const EdgeInsets.all(
                  15,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(
                        alpha: .035,
                      ),
                      blurRadius: 14,
                      offset:
                          const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration:
                          BoxDecoration(
                        color:
                            gold.withValues(
                          alpha: .12,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          15,
                        ),
                      ),
                      child: const Icon(
                        Icons
                            .content_cut_rounded,
                        color: gold,
                      ),
                    ),
                    const SizedBox(
                      width: 13,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            name,
                            style:
                                const TextStyle(
                              color:
                                  navy,
                              fontSize:
                                  14,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Row(
                            children: [
                              Text(
                                '${price.toStringAsFixed(0)} DA',
                                style:
                                    const TextStyle(
                                  color:
                                      gold,
                                  fontSize:
                                      13,
                                  fontWeight:
                                      FontWeight
                                          .w900,
                                ),
                              ),
                              const SizedBox(
                                width: 8,
                              ),
                              Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal:
                                      7,
                                  vertical:
                                      4,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color:
                                      active
                                          ? green.withValues(
                                              alpha:
                                                  .10,
                                            )
                                          : red.withValues(
                                              alpha:
                                                  .10,
                                            ),
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    8,
                                  ),
                                ),
                                child: Text(
                                  active
                                      ? 'مفعّلة'
                                      : 'متوقفة',
                                  style:
                                      TextStyle(
                                    color:
                                        active
                                            ? green
                                            : red,
                                    fontSize:
                                        9,
                                    fontWeight:
                                        FontWeight
                                            .w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                      ),
                      onSelected:
                          (value) {
                        if (value ==
                            'edit') {
                          _showEditServiceDialog(
                            service,
                          );
                        } else if (value ==
                            'active') {
                          _toggleService(
                            service,
                            !active,
                          );
                        } else if (value ==
                            'delete') {
                          _deleteService(
                            service,
                          );
                        }
                      },
                      itemBuilder:
                          (context) {
                        return [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text(
                              'تعديل',
                            ),
                          ),
                          PopupMenuItem(
                            value: 'active',
                            child: Text(
                              active
                                  ? 'تعطيل'
                                  : 'تفعيل',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'حذف',
                            ),
                          ),
                        ];
                      },
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // =========================================================
  // EMPTY CARD
  // =========================================================

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color:
                  navy.withValues(alpha: .06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: navy,
              size: 28,
            ),
          ),
          const SizedBox(height: 13),
          Text(
            title,
            style: const TextStyle(
              color: navy,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color:
                  Colors.grey.shade600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _buildHeader() {
    return Container(
      padding:
          const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            navyLight,
            navy,
          ],
        ),
        borderRadius:
            BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color:
                navy.withValues(alpha: .18),
            blurRadius: 24,
            offset:
                const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: gold.withValues(
                alpha: .13,
              ),
              borderRadius:
                  BorderRadius.circular(19),
              border: Border.all(
                color: gold.withValues(
                  alpha: .20,
                ),
              ),
            ),
            child: const Icon(
              Icons.content_cut_rounded,
              color: gold,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحباً بك 👋',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'LHadi Coiffure',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'لوحة إدارة الحلاق',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: background,
        body: Center(
          child:
              CircularProgressIndicator(
            color: gold,
          ),
        ),
      );
    }

    if (_barberId == null) {
      return const Scaffold(
        backgroundColor: background,
        body: Center(
          child: Text(
            'لم يتم العثور على حساب الحلاق',
          ),
        ),
      );
    }

    return Directionality(
      textDirection:
          TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            background,
        appBar: AppBar(
          backgroundColor:
              Colors.white,
          surfaceTintColor:
              Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Text(
                'LHadi Coiffure',
                style: TextStyle(
                  color: navy,
                  fontSize: 17,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              Text(
                'لوحة الحلاق',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: () async {
                await _loadServices();

                if (mounted) {
                  setState(() {});
                }
              },
              icon: const Icon(
                Icons.refresh_rounded,
                color: navy,
              ),
            ),
            IconButton(
              tooltip:
                  'تسجيل الخروج',
              onPressed:
                  _logoutLoading
                      ? null
                      : _logout,
              icon: _logoutLoading
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color: navy,
                      ),
                    )
                  : const Icon(
                      Icons
                          .logout_rounded,
                      color: navy,
                    ),
            ),
          ],
        ),
        body:
            StreamBuilder<
                List<
                    Map<String,
                        dynamic>>>(
          stream:
              _service.watchQueue(
            _barberId!,
          ),
          builder:
              (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: _emptyCard(
                  icon: Icons
                      .error_outline_rounded,
                  title:
                      'حدث خطأ في الطابور',
                  subtitle:
                      'حاول تحديث الصفحة مرة أخرى',
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child:
                    CircularProgressIndicator(
                  color: gold,
                ),
              );
            }

            final tickets =
                snapshot.data ?? [];

            final today =
                _todayDate();

            final todayTickets =
                tickets.where(
              (ticket) =>
                  ticket['queue_date']
                      ?.toString() ==
                  today,
            ).toList();

            return RefreshIndicator(
              color: gold,
              onRefresh: () async {
                await _loadServices();

                if (mounted) {
                  setState(() {});
                }
              },
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  35,
                ),
                children: [
                  _buildHeader(),

                  const SizedBox(
                    height: 15,
                  ),

                  _buildQueueControl(),

                  const SizedBox(
                    height: 15,
                  ),

                  _buildCurrentServing(
                    todayTickets,
                  ),

                  const SizedBox(
                    height: 22,
                  ),

                  _buildWaitingSection(
                    todayTickets,
                  ),

                  const SizedBox(
                    height: 22,
                  ),

                  _buildLocationCard(),

                  const SizedBox(
                    height: 22,
                  ),

                  _buildServicesSection(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// =============================================================
// SERVICE DIALOG
// =============================================================

class _ServiceDialog
    extends StatefulWidget {
  final String title;
  final String buttonText;
  final String initialName;
  final double? initialPrice;

  const _ServiceDialog({
    required this.title,
    required this.buttonText,
    this.initialName = '',
    this.initialPrice,
  });

  @override
  State<_ServiceDialog> createState() =>
      _ServiceDialogState();
}

class _ServiceDialogState
    extends State<_ServiceDialog> {
  late final TextEditingController
      _nameController;

  late final TextEditingController
      _priceController;

  final _formKey =
      GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    _nameController =
        TextEditingController(
      text: widget.initialName,
    );

    _priceController =
        TextEditingController(
      text: widget.initialPrice == null
          ? ''
          : widget.initialPrice!
              .toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    final price =
        double.tryParse(
      _priceController.text
          .trim()
          .replaceAll(',', '.'),
    );

    if (price == null || price < 0) {
      return;
    }

    Navigator.of(context).pop({
      'name':
          _nameController.text.trim(),
      'price': price,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection:
          TextDirection.rtl,
      child: AlertDialog(
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(26),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color:
                _AdminDashboardState.navy,
            fontWeight:
                FontWeight.w900,
          ),
        ),
        content: Form(
          key: _formKey,
          child:
              SingleChildScrollView(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                TextFormField(
                  controller:
                      _nameController,
                  decoration:
                      InputDecoration(
                    labelText:
                        'اسم الخدمة',
                    hintText:
                        'مثال: قص شعر',
                    prefixIcon:
                        const Icon(
                      Icons
                          .content_cut_rounded,
                    ),
                    filled: true,
                    fillColor:
                        Colors.grey
                            .shade100,
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        16,
                      ),
                      borderSide:
                          BorderSide.none,
                    ),
                  ),
                  validator:
                      (value) {
                    if (value == null ||
                        value
                            .trim()
                            .isEmpty) {
                      return 'أدخل اسم الخدمة';
                    }

                    return null;
                  },
                ),
                const SizedBox(
                  height: 14,
                ),
                TextFormField(
                  controller:
                      _priceController,
                  keyboardType:
                      const TextInputType
                          .numberWithOptions(
                    decimal: true,
                  ),
                  decoration:
                      InputDecoration(
                    labelText:
                        'السعر',
                    hintText:
                        'مثال: 500',
                    prefixIcon:
                        const Icon(
                      Icons
                          .payments_outlined,
                    ),
                    suffixText:
                        'DA',
                    filled: true,
                    fillColor:
                        Colors.grey
                            .shade100,
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        16,
                      ),
                      borderSide:
                          BorderSide.none,
                    ),
                  ),
                  validator:
                      (value) {
                    if (value == null ||
                        value
                            .trim()
                            .isEmpty) {
                      return 'أدخل السعر';
                    }

                    final price =
                        double.tryParse(
                      value
                          .trim()
                          .replaceAll(
                            ',',
                            '.',
                          ),
                    );

                    if (price == null ||
                        price < 0) {
                      return 'السعر غير صحيح';
                    }

                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context)
                  .pop();
            },
            child:
                const Text('إلغاء'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(
              backgroundColor:
                  _AdminDashboardState
                      .navy,
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),
            ),
            onPressed: _submit,
            child: Text(
              widget.buttonText,
            ),
          ),
        ],
      ),
    );
  }
}