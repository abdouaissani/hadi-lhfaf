import 'dart:async';

import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import 'barber_location_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  static const Color navy = Color(0xFF0D1726);
  static const Color gold = Color(0xFFD7A84B);
  static const Color background = Color(0xFFF5F6F8);

  final SupabaseService _service = SupabaseService();

  String? _barberId;

  bool _loading = true;
  bool _queueEnabled = true;
  bool _nextLoading = false;

  List<Map<String, dynamic>> _allTickets = [];
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _services = [];

  StreamSubscription<List<Map<String, dynamic>>>? _queueSubscription;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    super.dispose();
  }

  // =========================================================
  // INITIALIZE
  // =========================================================

  Future<void> _initialize() async {
    try {
      final user = _service.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
        return;
      }

      _barberId = user.id;

      await Future.wait([
        _loadQueueStatus(),
        _loadAnnouncements(),
        _loadServices(),
      ]);

      _startQueueStream();
    } catch (e) {
      debugPrint('ADMIN INITIALIZE ERROR: $e');

      if (mounted) {
        _showError('حدث خطأ أثناء تحميل لوحة الحلاق');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // =========================================================
  // QUEUE STREAM
  // =========================================================

  void _startQueueStream() {
    final barberId = _barberId;

    if (barberId == null || barberId.isEmpty) {
      return;
    }

    _queueSubscription?.cancel();

    _queueSubscription = _service.watchQueue(barberId).listen(
      (tickets) {
        if (!mounted) return;

        setState(() {
          _allTickets = List<Map<String, dynamic>>.from(tickets);
        });
      },
      onError: (error) {
        debugPrint('QUEUE STREAM ERROR: $error');
      },
    );
  }

  // =========================================================
  // LOAD DATA
  // =========================================================

  Future<void> _loadQueueStatus() async {
    final barberId = _barberId;

    if (barberId == null) return;

    try {
      final enabled = await _service.isQueueEnabled(barberId);

      if (!mounted) return;

      setState(() {
        _queueEnabled = enabled;
      });
    } catch (e) {
      debugPrint('LOAD QUEUE STATUS ERROR: $e');
    }
  }

  Future<void> _loadAnnouncements() async {
    final barberId = _barberId;

    if (barberId == null) return;

    try {
      final data = await _service.getAllAnnouncements(barberId);

      if (!mounted) return;

      setState(() {
        _announcements = data;
      });
    } catch (e) {
      debugPrint('LOAD ANNOUNCEMENTS ERROR: $e');
    }
  }

  Future<void> _loadServices() async {
    final barberId = _barberId;

    if (barberId == null) return;

    try {
      final data = await _service.getAllServices(barberId);

      if (!mounted) return;

      setState(() {
        _services = data;
      });
    } catch (e) {
      debugPrint('LOAD SERVICES ERROR: $e');
    }
  }

  // =========================================================
  // DATE HELPERS
  // =========================================================

  String _todayDate() {
    final now = DateTime.now();

    final month = now.month.toString().padLeft(2, '0');

    final day = now.day.toString().padLeft(2, '0');

    return '${now.year}-$month-$day';
  }

  String _ticketDate(
    Map<String, dynamic> ticket,
  ) {
    return ticket['queue_date']?.toString() ?? '';
  }

  bool _isToday(
    Map<String, dynamic> ticket,
  ) {
    return _ticketDate(ticket) == _todayDate();
  }

  bool _isOld(
    Map<String, dynamic> ticket,
  ) {
    final date = _ticketDate(ticket);

    if (date.isEmpty) {
      return false;
    }

    return date.compareTo(_todayDate()) < 0;
  }

  // =========================================================
  // STATUS
  // =========================================================

  String _status(
    Map<String, dynamic> ticket,
  ) {
    return ticket['status']?.toString().toLowerCase() ?? '';
  }

  bool _isWaiting(
    Map<String, dynamic> ticket,
  ) {
    return _status(ticket) == 'waiting';
  }

  bool _isServing(
    Map<String, dynamic> ticket,
  ) {
    return _status(ticket) == 'serving';
  }

  bool _isCompleted(
    Map<String, dynamic> ticket,
  ) {
    return _status(ticket) == 'completed';
  }

  bool _isCancelled(
    Map<String, dynamic> ticket,
  ) {
    return _status(ticket) == 'cancelled';
  }

  // =========================================================
  // TICKET NUMBER
  // =========================================================

  int _ticketNumber(
    Map<String, dynamic> ticket,
  ) {
    return int.tryParse(
          ticket['ticket_number']?.toString() ?? '',
        ) ??
        0;
  }

  // =========================================================
  // CURRENT SERVING
  // =========================================================

  Map<String, dynamic>? get _currentServing {
    final list = _allTickets
        .where(
          (ticket) => _isToday(ticket) && _isServing(ticket),
        )
        .toList();

    if (list.isEmpty) {
      return null;
    }

    list.sort(
      (a, b) => _ticketNumber(a).compareTo(
        _ticketNumber(b),
      ),
    );

    return list.first;
  }

  // =========================================================
  // WAITING
  // =========================================================

  List<Map<String, dynamic>> get _waitingToday {
    final list = _allTickets
        .where(
          (ticket) => _isToday(ticket) && _isWaiting(ticket),
        )
        .toList();

    list.sort(
      (a, b) => _ticketNumber(a).compareTo(
        _ticketNumber(b),
      ),
    );

    return list;
  }

  // =========================================================
  // OLD BOOKINGS
  // =========================================================

  List<Map<String, dynamic>> get _oldIncompleteTickets {
    final list = _allTickets
        .where(
          (ticket) =>
              _isOld(ticket) && !_isCompleted(ticket) && !_isCancelled(ticket),
        )
        .toList();

    list.sort(
      (a, b) {
        final dateA = _ticketDate(a);
        final dateB = _ticketDate(b);

        final dateCompare = dateB.compareTo(dateA);

        if (dateCompare != 0) {
          return dateCompare;
        }

        return _ticketNumber(a).compareTo(
          _ticketNumber(b),
        );
      },
    );

    return list;
  }

  // =========================================================
  // NEXT CUSTOMER
  // =========================================================

  Future<void> _nextCustomer() async {
    final barberId = _barberId;

    if (barberId == null || barberId.isEmpty || _nextLoading) {
      return;
    }

    setState(() {
      _nextLoading = true;
    });

    try {
      final result = await _service.nextQueueTicket(barberId);

      if (!mounted) return;

      final message = result['message']?.toString();

      if (message == 'NO_MORE_CUSTOMERS') {
        _showMessage(
          'لا يوجد زبائن آخرون في قائمة الانتظار',
        );
        return;
      }

      final ticketNumber = result['ticket_number']?.toString();

      _showMessage(
        ticketNumber == null
            ? 'تم استدعاء الزبون التالي'
            : 'تم استدعاء الزبون رقم $ticketNumber',
      );
    } catch (e) {
      debugPrint('NEXT CUSTOMER ERROR: $e');

      if (mounted) {
        _showError(
          'تعذر استدعاء الزبون التالي',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _nextLoading = false;
        });
      }
    }
  }

  // =========================================================
  // DELETE OLD TICKET
  // =========================================================

  Future<void> _completeAndDeleteOldTicket(
    Map<String, dynamic> ticket,
  ) async {
    final id = ticket['id']?.toString();

    if (id == null || id.isEmpty) {
      _showError('رقم الحجز غير موجود');
      return;
    }

    if (!_isOld(ticket)) {
      _showError('هذا الحجز ليس حجزاً قديماً.');
      return;
    }

    final number = _ticketNumber(ticket);
    final date = _ticketDate(ticket);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text(
              'إكمال الحجز',
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
            content: Text(
              'هل تريد إكمال وحذف الحجز رقم $number؟\n\n'
              'تاريخ الحجز: $date\n\n'
              'بعد الحذف لن يظهر هذا الحجز مرة أخرى.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    false,
                  );
                },
                child: const Text('إلغاء'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: navy,
                ),
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                },
                child: const Text('إكمال وحذف'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _service.deleteTicket(id);

      if (!mounted) return;

      setState(() {
        _allTickets.removeWhere(
          (item) => item['id']?.toString() == id,
        );
      });

      _showMessage(
        'تم إكمال وحذف الحجز رقم $number ✓',
      );
    } catch (e) {
      debugPrint(
        'DELETE OLD TICKET ERROR: $e',
      );

      if (mounted) {
        _showError(
          'تعذر حذف الحجز.\n'
          'تأكد من وجود DELETE Policy في Supabase.',
        );
      }
    }
  }

  // =========================================================
  // QUEUE TOGGLE
  // =========================================================

  Future<void> _toggleQueue(
    bool value,
  ) async {
    final barberId = _barberId;

    if (barberId == null) return;

    try {
      await _service.setQueueEnabled(
        barberId,
        value,
      );

      if (!mounted) return;

      setState(() {
        _queueEnabled = value;
      });

      _showMessage(
        value ? 'تم فتح الحجز' : 'تم إغلاق الحجز',
      );
    } catch (e) {
      debugPrint('TOGGLE QUEUE ERROR: $e');

      if (mounted) {
        _showError(
          'تعذر تغيير حالة الحجز',
        );
      }
    }
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> _logout() async {
    try {
      await _service.barberLogout();

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        _showError('تعذر تسجيل الخروج');
      }
    }
  }

  // =========================================================
  // QUEUE CONTROL
  // =========================================================

  Widget _buildQueueControl() {
    return _sectionCard(
      title: 'حالة الحجز',
      icon: Icons.people_alt_outlined,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _queueEnabled
                    ? Colors.green.withValues(alpha: .10)
                    : Colors.red.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                _queueEnabled
                    ? Icons.check_circle_outline
                    : Icons.pause_circle_outline,
                color: _queueEnabled ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _queueEnabled ? 'الحجز مفتوح' : 'الحجز مغلق',
                    style: const TextStyle(
                      color: navy,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _queueEnabled
                        ? 'الزبائن يستطيعون أخذ رقم'
                        : 'الزبائن لا يستطيعون الحجز',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _queueEnabled,
              onChanged: _toggleQueue,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // CURRENT SERVING
  // =========================================================

  Widget _buildCurrentServing() {
    final current = _currentServing;

    final number = current == null ? '--' : _ticketNumber(current).toString();

    final name = current == null
        ? 'لا يوجد زبون قيد الخدمة'
        : current['customer_name']?.toString() ?? 'زبون';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF182A45),
            navy,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: .16),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_pin_circle_outlined,
                color: Colors.white70,
                size: 19,
              ),
              SizedBox(width: 7),
              Text(
                'الزبون الحالي',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            number,
            style: const TextStyle(
              color: gold,
              fontSize: 56,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: _nextLoading ? null : _nextCustomer,
              icon: _nextLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: navy,
                      ),
                    )
                  : const Icon(
                      Icons.arrow_forward_rounded,
                    ),
              label: Text(
                _nextLoading ? 'جاري الاستدعاء...' : 'استدعاء التالي',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: navy,
                disabledBackgroundColor: gold.withValues(alpha: .55),
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

  Widget _buildWaitingSection() {
    final waiting = _waitingToday;

    return _sectionCard(
      title: 'قائمة الانتظار اليوم',
      icon: Icons.format_list_numbered_rounded,
      trailing: _countBadge(
        waiting.length,
        navy,
      ),
      child: waiting.isEmpty
          ? _emptyState(
              'لا يوجد زبائن في الانتظار',
              Icons.people_outline,
            )
          : Column(
              children: waiting
                  .map(
                    (ticket) => _buildTicketRow(ticket),
                  )
                  .toList(),
            ),
    );
  }

  // =========================================================
  // OLD BOOKINGS
  // =========================================================

  Widget _buildOldBookingsSection() {
    final old = _oldIncompleteTickets;

    return _sectionCard(
      title: 'حجوزات سابقة غير مكتملة',
      icon: Icons.history_rounded,
      trailing: old.isEmpty
          ? null
          : _countBadge(
              old.length,
              Colors.orange,
            ),
      child: old.isEmpty
          ? _emptyState(
              'لا توجد حجوزات سابقة غير مكتملة',
              Icons.history_toggle_off,
            )
          : Column(
              children: old
                  .map(
                    (ticket) => _buildOldTicketRow(ticket),
                  )
                  .toList(),
            ),
    );
  }

  // =========================================================
  // TICKET ROW
  // =========================================================

  Widget _buildTicketRow(
    Map<String, dynamic> ticket,
  ) {
    final number = _ticketNumber(ticket);

    final name = ticket['customer_name']?.toString() ?? 'زبون';

    final phone = ticket['phone']?.toString() ?? '';

    final status = _status(ticket);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _numberBox(
            number,
            navy,
            gold,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (phone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      phone,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _statusBadge(status),
        ],
      ),
    );
  }

  // =========================================================
  // OLD TICKET ROW
  // =========================================================

  Widget _buildOldTicketRow(
    Map<String, dynamic> ticket,
  ) {
    final number = _ticketNumber(ticket);

    final name = ticket['customer_name']?.toString() ?? 'زبون';

    final phone = ticket['phone']?.toString() ?? '';

    final date = _ticketDate(ticket);
    final status = _status(ticket);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.orange.withValues(alpha: .18),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _numberBox(
                number,
                Colors.orange,
                Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: navy,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'التاريخ: $date',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                    if (phone.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 3,
                        ),
                        child: Text(
                          phone,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _statusBadge(status),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () {
                _completeAndDeleteOldTicket(
                  ticket,
                );
              },
              icon: const Icon(
                Icons.check_circle_outline,
              ),
              label: const Text(
                'إكمال وحذف الحجز',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // LOCATION
  // =========================================================

  Widget _buildLocationCard() {
    final barberId = _barberId;

    return _sectionCard(
      title: 'موقع المحل',
      icon: Icons.location_on_outlined,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.location_on_outlined,
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تعديل موقع المحل',
                    style: TextStyle(
                      color: navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'تحديد موقع  على الخريطة',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: barberId == null
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BarberLocationScreen(
                            barberId: barberId,
                          ),
                        ),
                      );
                    },
              icon: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: navy,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // ANNOUNCEMENTS
  // =========================================================

  Widget _buildAnnouncementsSection() {
    return _sectionCard(
      title: 'الإعلانات',
      icon: Icons.campaign_outlined,
      trailing: IconButton(
        onPressed: _addAnnouncement,
        icon: const Icon(
          Icons.add_circle_outline_rounded,
          color: navy,
        ),
      ),
      child: _announcements.isEmpty
          ? _emptyState(
              'لا توجد إعلانات',
              Icons.campaign_outlined,
            )
          : Column(
              children: _announcements.map(
                (announcement) {
                  final title = announcement['title']?.toString() ?? 'إعلان';

                  final active = announcement['is_active'] == true;

                  return Container(
                    margin: const EdgeInsets.only(
                      bottom: 10,
                    ),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.campaign_rounded,
                          color: navy,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: navy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Switch(
                          value: active,
                          onChanged: (_) {
                            _toggleAnnouncement(
                              announcement,
                            );
                          },
                        ),
                        IconButton(
                          onPressed: () {
                            _deleteAnnouncement(
                              announcement,
                            );
                          },
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ).toList(),
            ),
    );
  }

  // =========================================================
  // SERVICES
  // =========================================================

  Widget _buildServicesSection() {
    return _sectionCard(
      title: 'الخدمات',
      icon: Icons.content_cut_rounded,
      trailing: IconButton(
        onPressed: _addService,
        icon: const Icon(
          Icons.add_circle_outline_rounded,
          color: navy,
        ),
      ),
      child: _services.isEmpty
          ? _emptyState(
              'لا توجد خدمات',
              Icons.content_cut_outlined,
            )
          : Column(
              children: _services.map(
                (service) {
                  final name = service['name']?.toString() ?? 'خدمة';

                  final price = service['price']?.toString() ?? '';

                  final active = service['is_active'] == true;

                  return Container(
                    margin: const EdgeInsets.only(
                      bottom: 10,
                    ),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: gold.withValues(
                              alpha: .12,
                            ),
                            borderRadius: BorderRadius.circular(
                              14,
                            ),
                          ),
                          child: const Icon(
                            Icons.content_cut_rounded,
                            color: navy,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: navy,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$price دج',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: active,
                          onChanged: (_) {
                            _toggleService(
                              service,
                            );
                          },
                        ),
                        IconButton(
                          onPressed: () {
                            _deleteService(
                              service,
                            );
                          },
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ).toList(),
            ),
    );
  }

  // =========================================================
  // ADD ANNOUNCEMENT
  // =========================================================

  Future<void> _addAnnouncement() async {
    final barberId = _barberId;

    if (barberId == null) return;

    final titleController = TextEditingController();

    final contentController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text(
              'إضافة إعلان',
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'العنوان',
                      prefixIcon: Icon(
                        Icons.title,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'محتوى الإعلان',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(
                        Icons.notes,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    false,
                  );
                },
                child: const Text('إلغاء'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: navy,
                ),
                onPressed: () async {
                  final title = titleController.text.trim();

                  if (title.isEmpty) return;

                  try {
                    await _service.addAnnouncement(
                      barberId: barberId,
                      title: title,
                      content: contentController.text.trim(),
                    );

                    if (dialogContext.mounted) {
                      Navigator.pop(
                        dialogContext,
                        true,
                      );
                    }
                  } catch (e) {
                    debugPrint(
                      'ADD ANNOUNCEMENT ERROR: $e',
                    );
                  }
                },
                child: const Text('إضافة'),
              ),
            ],
          ),
        );
      },
    );

    titleController.dispose();
    contentController.dispose();

    if (result == true) {
      await _loadAnnouncements();

      if (mounted) {
        _showMessage('تمت إضافة الإعلان');
      }
    }
  }

  // =========================================================
  // DELETE ANNOUNCEMENT
  // =========================================================

  Future<void> _deleteAnnouncement(
    Map<String, dynamic> announcement,
  ) async {
    final id = announcement['id']?.toString();

    if (id == null || id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('حذف الإعلان'),
            content: const Text(
              'هل تريد حذف هذا الإعلان؟',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    false,
                  );
                },
                child: const Text('إلغاء'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                },
                child: const Text('حذف'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _service.deleteAnnouncement(id);
      await _loadAnnouncements();

      if (mounted) {
        _showMessage('تم حذف الإعلان');
      }
    } catch (e) {
      debugPrint(
        'DELETE ANNOUNCEMENT ERROR: $e',
      );

      if (mounted) {
        _showError('تعذر حذف الإعلان');
      }
    }
  }

  // =========================================================
  // TOGGLE ANNOUNCEMENT
  // =========================================================

  Future<void> _toggleAnnouncement(
    Map<String, dynamic> announcement,
  ) async {
    final id = announcement['id']?.toString();

    if (id == null || id.isEmpty) return;

    final current = announcement['is_active'] == true;

    try {
      await _service.setAnnouncementActive(
        announcementId: id,
        active: !current,
      );

      await _loadAnnouncements();
    } catch (e) {
      debugPrint(
        'TOGGLE ANNOUNCEMENT ERROR: $e',
      );

      if (mounted) {
        _showError(
          'تعذر تغيير حالة الإعلان',
        );
      }
    }
  }

  // =========================================================
  // ADD SERVICE
  // =========================================================

  Future<void> _addService() async {
    final barberId = _barberId;

    if (barberId == null) return;

    final nameController = TextEditingController();

    final priceController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text(
              'إضافة خدمة',
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الخدمة',
                    prefixIcon: Icon(
                      Icons.content_cut,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'السعر',
                    prefixIcon: Icon(
                      Icons.payments_outlined,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    false,
                  );
                },
                child: const Text('إلغاء'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: navy,
                ),
                onPressed: () async {
                  final name = nameController.text.trim();

                  final price = double.tryParse(
                    priceController.text.trim(),
                  );

                  if (name.isEmpty || price == null) {
                    return;
                  }

                  try {
                    await _service.addService(
                      barberId: barberId,
                      name: name,
                      price: price,
                    );

                    if (dialogContext.mounted) {
                      Navigator.pop(
                        dialogContext,
                        true,
                      );
                    }
                  } catch (e) {
                    debugPrint(
                      'ADD SERVICE ERROR: $e',
                    );
                  }
                },
                child: const Text('إضافة'),
              ),
            ],
          ),
        );
      },
    );

    nameController.dispose();
    priceController.dispose();

    if (result == true) {
      await _loadServices();

      if (mounted) {
        _showMessage('تمت إضافة الخدمة');
      }
    }
  }

  // =========================================================
  // DELETE SERVICE
  // =========================================================

  Future<void> _deleteService(
    Map<String, dynamic> service,
  ) async {
    final id = service['id']?.toString();

    if (id == null || id.isEmpty) return;

    final name = service['name']?.toString() ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('حذف الخدمة'),
            content: Text(
              'هل تريد حذف "$name"؟',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    false,
                  );
                },
                child: const Text('إلغاء'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                },
                child: const Text('حذف'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _service.deleteService(id);
      await _loadServices();

      if (mounted) {
        _showMessage('تم حذف الخدمة');
      }
    } catch (e) {
      debugPrint(
        'DELETE SERVICE ERROR: $e',
      );

      if (mounted) {
        _showError('تعذر حذف الخدمة');
      }
    }
  }

  // =========================================================
  // TOGGLE SERVICE
  // =========================================================

  Future<void> _toggleService(
    Map<String, dynamic> service,
  ) async {
    final id = service['id']?.toString();

    if (id == null || id.isEmpty) return;

    final active = service['is_active'] == true;

    try {
      await _service.setServiceActive(
        serviceId: id,
        active: !active,
      );

      await _loadServices();
    } catch (e) {
      debugPrint(
        'TOGGLE SERVICE ERROR: $e',
      );

      if (mounted) {
        _showError(
          'تعذر تغيير حالة الخدمة',
        );
      }
    }
  }

  // =========================================================
  // UI HELPERS
  // =========================================================

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .025),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  color: navy.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: navy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _numberBox(
    int number,
    Color backgroundColor,
    Color textColor,
  ) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        '$number',
        style: TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _countBadge(
    int count,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _emptyState(
    String text,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.grey.shade400,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    String text;

    Color color;

    switch (status) {
      case 'waiting':
        text = 'انتظار';
        color = Colors.orange;
        break;

      case 'serving':
        text = 'قيد الخدمة';
        color = Colors.green;
        break;

      case 'completed':
        text = 'مكتمل';
        color = Colors.blue;
        break;

      case 'cancelled':
        text = 'ملغى';
        color = Colors.red;
        break;

      default:
        text = status.isEmpty ? 'غير معروف' : status;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // =========================================================
  // SNACKBAR
  // =========================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textDirection: TextDirection.rtl,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textDirection: TextDirection.rtl,
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'LHadi Coiffure',
                style: TextStyle(
                  color: navy,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              Text(
                'لوحة الحلاق',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: () async {
                await Future.wait([
                  _loadQueueStatus(),
                  _loadAnnouncements(),
                  _loadServices(),
                ]);
              },
              icon: const Icon(
                Icons.refresh_rounded,
                color: navy,
              ),
            ),
            IconButton(
              tooltip: 'تسجيل الخروج',
              onPressed: _logout,
              icon: const Icon(
                Icons.logout_rounded,
                color: navy,
              ),
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: gold,
                ),
              )
            : RefreshIndicator(
                color: gold,
                onRefresh: () async {
                  await Future.wait([
                    _loadQueueStatus(),
                    _loadAnnouncements(),
                    _loadServices(),
                  ]);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    32,
                  ),
                  children: [
                    // HEADER
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            Color(0xFF182A45),
                            navy,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: navy.withValues(
                              alpha: .16,
                            ),
                            blurRadius: 22,
                            offset: const Offset(
                              0,
                              9,
                            ),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 30,
                            backgroundColor: Color(0x22D7A84B),
                            child: Icon(
                              Icons.content_cut_rounded,
                              color: gold,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'مرحباً بك 👋',
                                  style: TextStyle(
                                    color: Colors.white70,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'إدارة LHadi Coiffure',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'تحكم في الطابور والخدمات والحجوزات.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    _buildQueueControl(),

                    const SizedBox(height: 14),

                    _buildCurrentServing(),

                    const SizedBox(height: 14),

                    _buildWaitingSection(),

                    const SizedBox(height: 14),

                    _buildOldBookingsSection(),

                    const SizedBox(height: 14),

                    _buildLocationCard(),

                    const SizedBox(height: 14),

                    _buildAnnouncementsSection(),

                    const SizedBox(height: 14),

                    _buildServicesSection(),
                  ],
                ),
              ),
      ),
    );
  }
}
