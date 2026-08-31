import 'dart:async';

import 'package:flutter/material.dart';

import '../services/supabase_service.dart';

class QueueScreen extends StatefulWidget {
  final String ticketId;

  const QueueScreen({
    super.key,
    required this.ticketId,
  });

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  final SupabaseService _service =
      SupabaseService();

  StreamSubscription<
      Map<String, dynamic>?>? _subscription;

  Timer? _refreshTimer;

  Map<String, dynamic>? _ticket;

  int _peopleBefore = 0;
  int _currentNumber = 0;

  bool _loading = true;
  bool _notFound = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();

    _loadAll();

    _listenToTicket();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        _loadQueueInfo(
          showLoading: false,
        );
      },
    );
  }

  // =========================================================
  // LOAD
  // =========================================================

  Future<void> _loadAll() async {
    await _loadTicket();

    if (_ticket != null) {
      await _loadQueueInfo(
        showLoading: false,
      );
    }
  }

  Future<void> _loadTicket() async {
    try {
      final ticket =
          await _service.getTicket(
        widget.ticketId,
      );

      if (!mounted) return;

      if (ticket == null) {
        setState(() {
          _loading = false;
          _notFound = true;
        });

        return;
      }

      setState(() {
        _ticket = ticket;
        _loading = false;
        _notFound = false;
      });
    } catch (e) {
      debugPrint(
        'LOAD TICKET ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadQueueInfo({
    bool showLoading = false,
  }) async {
    if (_refreshing) return;

    _refreshing = true;

    if (showLoading && mounted) {
      setState(() {});
    }

    try {
      final info =
          await _service.getCustomerQueueInfo(
        widget.ticketId,
      );

      if (!mounted) return;

      final ticket =
          info['ticket'] as Map<String, dynamic>?;

      setState(() {
        _ticket = ticket;
        _peopleBefore =
            int.tryParse(
                  info['people_before']
                          ?.toString() ??
                      '',
                ) ??
                0;

        _currentNumber =
            int.tryParse(
                  info['current_number']
                          ?.toString() ??
                      '',
                ) ??
                0;

        _notFound = false;
      });
    } catch (e) {
      debugPrint(
        'LOAD QUEUE INFO ERROR: $e',
      );
    } finally {
      _refreshing = false;
    }
  }

  // =========================================================
  // REALTIME
  // =========================================================

  void _listenToTicket() {
    _subscription = _service
        .watchCustomerTicket(
          widget.ticketId,
        )
        .listen(
      (ticket) {
        if (!mounted) return;

        if (ticket == null) {
          setState(() {
            _ticket = null;
            _notFound = true;
          });

          return;
        }

        setState(() {
          _ticket = ticket;
          _notFound = false;
        });

        _loadQueueInfo(
          showLoading: false,
        );
      },
      onError: (error) {
        debugPrint(
          'REALTIME ERROR: $error',
        );
      },
    );
  }

  // =========================================================
  // GETTERS
  // =========================================================

  String get _status {
    return _ticket?['status']
            ?.toString() ??
        'waiting';
  }

  int get _ticketNumber {
    return int.tryParse(
          _ticket?['ticket_number']
                  ?.toString() ??
              '',
        ) ??
        0;
  }

  String get _customerName {
    return _ticket?['customer_name']
            ?.toString() ??
        '';
  }

  // =========================================================
  // STATUS
  // =========================================================

  String get _statusTitle {
    switch (_status) {
      case 'serving':
        return 'حان دورك!';

      case 'completed':
        return 'تم الانتهاء';

      case 'cancelled':
        return 'تم إلغاء الدور';

      case 'skipped':
        return 'تم تجاوز الدور';

      default:
        return 'أنت في قائمة الانتظار';
    }
  }

  Color _statusColor() {
    switch (_status) {
      case 'serving':
        return Colors.green;

      case 'completed':
        return Colors.blue;

      case 'cancelled':
        return Colors.red;

      case 'skipped':
        return Colors.red;

      default:
        return Colors.orange;
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_notFound || _ticket == null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('دوري'),
            centerTitle: true,
          ),
          body: const Center(
            child: Text(
              'لم يتم العثور على الحجز',
              style: TextStyle(
                fontSize: 18,
              ),
            ),
          ),
        ),
      );
    }

    final color = _statusColor();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Hadi Lhafaf',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadAll();
            },
            child: ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 15),

                Text(
                  'مرحباً $_customerName 👋',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 25),

                // =================================================
                // MY NUMBER
                // =================================================

                Container(
                  padding:
                      const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'رقم دورك',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '#$_ticketNumber',
                        style: const TextStyle(
                          fontSize: 62,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // =================================================
                // PEOPLE BEFORE ME
                // =================================================

                if (_status == 'waiting')
                  Container(
                    padding:
                        const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 45,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'الأشخاص الذين قبلك',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$_peopleBefore',
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // =================================================
                // CURRENT BARBER NUMBER
                // =================================================

                Container(
                  padding:
                      const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.content_cut,
                        size: 40,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'الدور الحالي عند الحلاق',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _currentNumber == 0
                            ? '--'
                            : '#$_currentNumber',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // =================================================
                // STATUS
                // =================================================

                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 25,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(20),
                    border: Border.all(
                      color: color.withValues(
                        alpha: 0.35,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _statusTitle,
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight:
                              FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _status == 'serving'
                            ? 'توجه إلى الحلاق الآن ✂️'
                            : _status == 'waiting'
                                ? 'انتظر حتى يحين دورك'
                                : _status == 'completed'
                                    ? 'تم إكمال خدمتك'
                                    : '',
                        textAlign:
                            TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                if (_status == 'waiting')
                  Container(
                    padding:
                        const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color:
                          Colors.grey.shade100,
                      borderRadius:
                          BorderRadius.circular(15),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons
                              .wifi_tethering,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'المعلومات تتحدث تلقائياً عند تغير الدور.',
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_status == 'serving')
                  Container(
                    padding:
                        const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.green,
                      ),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.content_cut,
                          size: 45,
                          color: Colors.green,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'الحلاق في انتظارك ✂️',
                          textAlign:
                              TextAlign.center,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 30),

                const Text(
                  'لا تغلق التطبيق إذا كنت تنتظر دورك',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _subscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }
}