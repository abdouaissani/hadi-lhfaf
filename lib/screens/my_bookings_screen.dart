import 'package:flutter/material.dart';

import '../services/customer_storage.dart';
import '../services/supabase_service.dart';
import 'queue_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({
    super.key,
  });

  @override
  State<MyBookingsScreen> createState() =>
      _MyBookingsScreenState();
}

class _MyBookingsScreenState
    extends State<MyBookingsScreen> {
  final SupabaseService _service =
      SupabaseService();

  bool _loading = true;

  List<Map<String, dynamic>> _bookings = [];

  @override
  void initState() {
    super.initState();

    _loadBookings();
  }

  // =========================================================
  // LOAD BOOKINGS
  // =========================================================

  Future<void> _loadBookings() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final List<String> ticketIds =
          await CustomerStorage.getTicketIds();

      final List<Map<String, dynamic>>
          bookings = [];

      for (final String ticketId
          in ticketIds) {
        try {
          final ticket =
              await _service.getTicket(
            ticketId,
          );

          if (ticket != null) {
            bookings.add(ticket);
          }
        } catch (e) {
          debugPrint(
            'GET BOOKING ERROR $ticketId: $e',
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _bookings = bookings;
        _loading = false;
      });
    } catch (e) {
      debugPrint(
        'LOAD BOOKINGS ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _message(
        'تعذر تحميل الحجوزات',
      );
    }
  }

  // =========================================================
  // DELETE BOOKING FROM PHONE
  // =========================================================

  Future<void> _removeBooking(
    String ticketId,
  ) async {
    await CustomerStorage.removeTicketId(
      ticketId,
    );

    await _loadBookings();
  }

  // =========================================================
  // STATUS
  // =========================================================

  String _statusText(
    String? status,
  ) {
    switch (status) {
      case 'waiting':
        return 'في الانتظار';

      case 'serving':
        return 'حان دورك';

      case 'completed':
        return 'مكتمل';

      case 'cancelled':
        return 'ملغى';

      default:
        return 'غير معروف';
    }
  }

  Color _statusColor(
    String? status,
  ) {
    switch (status) {
      case 'serving':
        return Colors.green;

      case 'completed':
        return Colors.blue;

      case 'cancelled':
        return Colors.red;

      default:
        return Colors.orange;
    }
  }

  IconData _statusIcon(
    String? status,
  ) {
    switch (status) {
      case 'serving':
        return Icons.notifications_active;

      case 'completed':
        return Icons.check_circle_outline;

      case 'cancelled':
        return Icons.cancel_outlined;

      default:
        return Icons.hourglass_top;
    }
  }

  // =========================================================
  // TICKET NUMBER
  // =========================================================

  int _ticketNumber(
    Map<String, dynamic> ticket,
  ) {
    return int.tryParse(
          ticket['ticket_number']
                  ?.toString() ??
              '',
        ) ??
        0;
  }

  // =========================================================
  // CURRENT NUMBER
  // =========================================================

  int _currentNumber(
    Map<String, dynamic> ticket,
  ) {
    // نحاول قراءة الرقم الحالي من الحجز
    // إذا كان موجوداً في قاعدة البيانات.

    final dynamic value =
        ticket['current_ticket_number'] ??
            ticket['current_number'] ??
            ticket['serving_number'];

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  // =========================================================
  // MESSAGE
  // =========================================================

  void _message(
    String text,
  ) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          text,
          textAlign: TextAlign.right,
        ),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // =========================================================
  // DELETE CONFIRMATION
  // =========================================================

  Future<void> _confirmDelete(
    Map<String, dynamic> ticket,
  ) async {
    final String? ticketId =
        ticket['id']?.toString();

    if (ticketId == null ||
        ticketId.isEmpty) {
      return;
    }

    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection:
              TextDirection.rtl,
          child: AlertDialog(
            title: const Text(
              'حذف الحجز',
            ),
            content: const Text(
              'هل تريد إزالة هذا الحجز من قائمة حجوزاتك على هذا الهاتف؟\n\nلن يتم حذف الحجز من قاعدة البيانات.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context)
                      .pop(false);
                },
                child: const Text(
                  'إلغاء',
                ),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context)
                      .pop(true);
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

    if (confirmed == true) {
      await _removeBooking(
        ticketId,
      );
    }
  }

  // =========================================================
  // BOOKING CARD
  // =========================================================

  Widget _bookingCard(
    Map<String, dynamic> ticket,
  ) {
    final String ticketId =
        ticket['id']?.toString() ?? '';

    final String status =
        ticket['status']?.toString() ??
            'waiting';

    final int ticketNumber =
        _ticketNumber(ticket);

    final int currentNumber =
        _currentNumber(ticket);

    final String customerName =
        ticket['customer_name']
                ?.toString() ??
            '';

    final Color statusColor =
        _statusColor(status);

    final bool active =
        status == 'waiting' ||
        status == 'serving';

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(
              alpha: 0.05,
            ),
            blurRadius: 15,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(
          18,
        ),
        child: Column(
          children: [
            // =====================================================
            // HEADER
            // =====================================================

            Row(
              children: [
                Container(
                  width: 55,
                  height: 55,
                  decoration:
                      BoxDecoration(
                    color: statusColor
                        .withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),
                  child: Icon(
                    _statusIcon(
                      status,
                    ),
                    color:
                        statusColor,
                  ),
                ),

                const SizedBox(
                  width: 14,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        customerName
                                .isEmpty
                            ? 'حجزي'
                            : customerName,
                        style:
                            const TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      Text(
                        _statusText(
                          status,
                        ),
                        style:
                            TextStyle(
                          color:
                              statusColor,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // DELETE
                IconButton(
                  tooltip:
                      'إزالة من حجوزاتي',
                  onPressed:
                      () => _confirmDelete(
                    ticket,
                  ),
                  icon:
                      const Icon(
                    Icons
                        .delete_outline,
                    color:
                        Colors.grey,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 18,
            ),

            // =====================================================
            // TICKET NUMBER
            // =====================================================

            Container(
              width:
                  double.infinity,
              padding:
                  const EdgeInsets
                      .symmetric(
                vertical: 18,
              ),
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFF0D1726,
                ),
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'رقم دورك',
                    style:
                        TextStyle(
                      color:
                          Colors.white70,
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    '#$ticketNumber',
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontSize: 40,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            // =====================================================
            // CURRENT NUMBER
            // =====================================================

            if (active &&
                currentNumber > 0)
              Container(
                padding:
                    const EdgeInsets
                        .all(
                  14,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors
                      .grey
                      .shade100,
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons
                          .record_voice_over_outlined,
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child:
                          Text(
                        'الحلاق وصل حالياً إلى الدور #$currentNumber',
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (active)
              const SizedBox(
                height: 15,
              ),

            // =====================================================
            // OPEN QUEUE
            // =====================================================

            if (active)
              SizedBox(
                width:
                    double.infinity,
                height: 52,
                child:
                    FilledButton.icon(
                  onPressed:
                      ticketId.isEmpty
                          ? null
                          : () {
                              Navigator.of(
                                context,
                              ).push(
                                MaterialPageRoute(
                                  builder:
                                      (_) =>
                                          QueueScreen(
                                    ticketId:
                                        ticketId,
                                  ),
                                ),
                              );
                            },
                  icon:
                      const Icon(
                    Icons
                        .visibility_outlined,
                  ),
                  label:
                      const Text(
                    'متابعة دوري',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Directionality(
      textDirection:
          TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'حجوزاتي',
            style: TextStyle(
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip:
                  'تحديث',
              onPressed:
                  _loading
                      ? null
                      : _loadBookings,
              icon:
                  const Icon(
                Icons.refresh,
              ),
            ),
          ],
        ),

        // =====================================================
        // BODY
        // =====================================================

        body: RefreshIndicator(
          onRefresh:
              _loadBookings,
          child: _loading
              ? const Center(
                  child:
                      CircularProgressIndicator(),
                )
              : _bookings.isEmpty
                  ? ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(
                          height: 130,
                        ),
                        Icon(
                          Icons
                              .receipt_long_outlined,
                          size: 80,
                          color: Colors
                              .grey
                              .shade400,
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        const Text(
                          'لا توجد حجوزات',
                          textAlign:
                              TextAlign.center,
                          style:
                              TextStyle(
                            fontSize:
                                22,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        const Text(
                          'عندما تحجز دوراً سيظهر هنا.',
                          textAlign:
                              TextAlign.center,
                          style:
                              TextStyle(
                            color:
                                Colors.grey,
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      padding:
                          const EdgeInsets
                              .all(
                        18,
                      ),
                      children: [
                        const Text(
                          'حجوزاتك على هذا الهاتف',
                          style:
                              TextStyle(
                            fontSize:
                                20,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),

                        const SizedBox(
                          height: 6,
                        ),

                        const Text(
                          'اضغط على "متابعة دوري" لمعرفة آخر حالة للطابور.',
                          style:
                              TextStyle(
                            color:
                                Colors.grey,
                          ),
                        ),

                        const SizedBox(
                          height: 18,
                        ),

                        ..._bookings.map(
                          _bookingCard,
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}