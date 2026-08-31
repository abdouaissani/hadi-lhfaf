import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final SupabaseService _service = SupabaseService();

  String? _barberId;

  bool _queueEnabled = true;
  bool _loading = true;
  bool _working = false;

  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // تأكد أن الحلاق داخل بحساب Supabase
      final user = _service.currentUser;

      if (user == null) {
        throw Exception('ADMIN_NOT_LOGGED_IN');
      }

      debugPrint('ADMIN USER: ${user.id}');
      debugPrint('ADMIN EMAIL: ${user.email}');

      final id = await _service.getSingleBarber();

      debugPrint('BARBER ID: $id');

      final enabled =
          await _service.isQueueEnabled(id);

      if (!mounted) return;

      setState(() {
        _barberId = id;
        _queueEnabled = enabled;
        _loading = false;
        _error = null;
      });
    } catch (e, stackTrace) {
      debugPrint('==============================');
      debugPrint('ADMIN LOAD ERROR');
      debugPrint('$e');
      debugPrint('$stackTrace');
      debugPrint('==============================');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _barberId = null;
        _error = e.toString();
      });
    }
  }

  Future<void> _next() async {
    if (_barberId == null || _working) return;

    setState(() {
      _working = true;
    });

    try {
      final result =
          await _service.nextQueueTicket(_barberId!);

      final message =
          result['message']?.toString();

      if (message == 'NO_MORE_CUSTOMERS') {
        _message('لا يوجد زبائن في الانتظار');
      } else {
        final number =
            result['ticket_number']?.toString() ?? '—';

        _message('تم استدعاء الدور #$number');

        final id = result['id']?.toString();

        if (id != null &&
            id.isNotEmpty &&
            id != 'null') {
          try {
            await _service.sendQueueNotification(
              ticketId: id,
              type: 'your_turn',
            );
          } catch (e) {
            debugPrint(
              'NOTIFICATION ERROR: $e',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('NEXT ERROR: $e');
      _message('تعذر استدعاء الدور');
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _complete(String ticketId) async {
    try {
      await _service.completeTicket(ticketId);
      _message('تم إنهاء الدور');
    } catch (e) {
      debugPrint('COMPLETE ERROR: $e');
      _message('تعذر إنهاء الدور');
    }
  }

  Future<void> _cancel(String ticketId) async {
    try {
      await _service.cancelTicket(ticketId);
      _message('تم إلغاء الدور');
    } catch (e) {
      debugPrint('CANCEL ERROR: $e');
      _message('تعذر إلغاء الدور');
    }
  }

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

      _message(
        value
            ? 'تم فتح الحجز'
            : 'تم إغلاق الحجز',
      );
    } catch (e) {
      debugPrint(
        'TOGGLE QUEUE ERROR: $e',
      );

      if (mounted) {
        setState(() {
          _queueEnabled = oldValue;
        });
      }

      _message('تعذر تغيير حالة الحجز');
    }
  }

  Future<void> _logout() async {
    try {
      await _service.barberLogout();
    } catch (e) {
      debugPrint('LOGOUT ERROR: $e');
    }

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            text,
            textAlign: TextAlign.right,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0D1726);
    const gold = Color(0xFFD7A84B);

    // ==============================
    // LOADING
    // ==============================

    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // ==============================
    // ERROR
    // ==============================

    if (_error != null || _barberId == null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text(
              'لوحة الحلاق',
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 70,
                    color: Colors.red,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'تعذر فتح لوحة الحلاق',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    _error ?? 'BARBER_ID_NOT_FOUND',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 25),

                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(
                      Icons.refresh,
                    ),
                    label: const Text(
                      'إعادة المحاولة',
                    ),
                  ),

                  const SizedBox(height: 10),

                  OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(
                      Icons.logout,
                    ),
                    label: const Text(
                      'تسجيل الخروج',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ==============================
    // ADMIN
    // ==============================

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'لوحة الحلاق',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _loading
                  ? null
                  : _load,
              icon: const Icon(
                Icons.refresh,
              ),
            ),
            IconButton(
              tooltip: 'خروج',
              onPressed: _logout,
              icon: const Icon(
                Icons.logout,
              ),
            ),
          ],
        ),

        body: StreamBuilder<
            List<Map<String, dynamic>>>(
          stream: _service.watchQueue(
            _barberId!,
          ),

          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding:
                      const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.cloud_off,
                        size: 60,
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'تعذر تحميل الطابور',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        snapshot.error.toString(),
                        textAlign:
                            TextAlign.center,
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final rows =
                snapshot.data ?? [];

            final waiting = rows.where((r) {
              final status =
                  r['status']
                      ?.toString()
                      .toLowerCase();

              return status == 'waiting';
            }).toList();

            final serving = rows.where((r) {
              final status =
                  r['status']
                      ?.toString()
                      .toLowerCase();

              return status == 'serving';
            }).toList();

            return ListView(
              padding:
                  const EdgeInsets.all(18),
              children: [
                Container(
                  padding:
                      const EdgeInsets.all(20),
                  decoration:
                      BoxDecoration(
                    gradient:
                        const LinearGradient(
                      colors: [
                        navy,
                        Color(0xFF1A2A40),
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                gold,
                            child: Icon(
                              Icons.content_cut,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'إدارة الطابور',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      SwitchListTile(
                        contentPadding:
                            EdgeInsets.zero,
                        value: _queueEnabled,
                        onChanged:
                            _toggleQueue,
                        title: const Text(
                          'الحجز مفتوح',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          _queueEnabled
                              ? 'الزبائن يستطيعون الحجز الآن'
                              : 'الحجز مغلق',
                          style:
                              const TextStyle(
                            color: Colors.white70,
                          ),
                        ),
                        activeThumbColor:
                            gold,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        title: 'ينتظرون',
                        value:
                            '${waiting.length}',
                        icon:
                            Icons.people_outline,
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: _Stat(
                        title: 'يخدم الآن',
                        value: serving.isEmpty
                            ? '—'
                            : '#${serving.first['ticket_number']}',
                        icon:
                            Icons.content_cut,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                SizedBox(
                  height: 60,
                  child: FilledButton.icon(
                    onPressed:
                        !_queueEnabled ||
                                _working
                            ? null
                            : _next,
                    icon: _working
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
                                .notifications_active_outlined,
                          ),
                    label: const Text(
                      'استدعاء الزبون التالي',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    style:
                        FilledButton.styleFrom(
                      backgroundColor: navy,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          18,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                const Text(
                  'الطابور',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 10),

                if (rows.isEmpty)
                  const Padding(
                    padding:
                        EdgeInsets.all(30),
                    child: Center(
                      child: Text(
                        'لا يوجد حجوزات حالياً',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),

                ...rows.map(
                  (row) => _TicketCard(
                    row: row,
                    onComplete: () =>
                        _complete(
                      row['id'].toString(),
                    ),
                    onCancel: () =>
                        _cancel(
                      row['id'].toString(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _Stat({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              const Color(0xFFE4E7EB),
        ),
      ),
      child: Column(
        children: [
          Icon(icon),
          const SizedBox(height: 8),
          Text(
            title,
            style:
                const TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style:
                const TextStyle(
              fontSize: 25,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketCard
    extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  const _TicketCard({
    required this.row,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final status =
        row['status']
                ?.toString()
                .toLowerCase() ??
            'waiting';

    final number =
        row['ticket_number']
                ?.toString() ??
            '—';

    final name =
        row['customer_name']
                ?.toString() ??
            'زبون';

    final phone =
        row['phone']
                ?.toString() ??
            '';

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: status == 'serving'
              ? Colors.green.withValues(
                  alpha: .5,
                )
              : const Color(
                  0xFFE4E7EB,
                ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment:
                Alignment.center,
            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
              color:
                  const Color(0xFFF3F4F6),
            ),
            child: Text(
              '#$number',
              style:
                  const TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style:
                      const TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                if (phone.isNotEmpty)
                  Text(
                    phone,
                    style:
                        const TextStyle(
                      color: Colors.grey,
                    ),
                  ),

                const SizedBox(height: 3),

                Text(
                  status == 'serving'
                      ? 'يخدم الآن'
                      : status == 'waiting'
                          ? 'ينتظر'
                          : status,
                  style: TextStyle(
                    color:
                        status == 'serving'
                            ? Colors.green
                            : Colors.grey,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          if (status == 'serving')
            IconButton(
              tooltip: 'إنهاء',
              onPressed:
                  onComplete,
              icon:
                  const Icon(
                Icons
                    .check_circle_outline,
              ),
            )
          else if (status == 'waiting')
            IconButton(
              tooltip: 'إلغاء',
              onPressed:
                  onCancel,
              icon:
                  const Icon(
                Icons
                    .cancel_outlined,
              ),
            ),
        ],
      ),
    );
  }
}