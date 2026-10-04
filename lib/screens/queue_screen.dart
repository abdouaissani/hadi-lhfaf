import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/customer_storage.dart';
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
  final SupabaseService _service = SupabaseService();

  Timer? _timer;
  StreamSubscription<Map<String, dynamic>?>? _ticketSubscription;

  Map<String, dynamic>? _ticket;

  int _peopleBefore = 0;
  int _currentNumber = 0;

  bool _loading = true;
  bool _error = false;

  String _status = 'waiting';

  bool _oneBeforeNotified = false;
  bool _servingNotified = false;

  @override
  void initState() {
    super.initState();

    _loadQueueInfo();

    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        _loadQueueInfo(showLoading: false);
      },
    );

    _startRealtimeListener();
  }

  // ============================================================
  // REALTIME
  // ============================================================

  void _startRealtimeListener() {
    try {
      _ticketSubscription = _service
          .watchCustomerTicket(widget.ticketId)
          .listen(
        (data) {
          if (!mounted) return;

          if (data == null) {
            _handleTicketDeleted();
            return;
          }

          _applyTicketData(data);

          _loadQueueInfo(showLoading: false);
        },
        onError: (error) {
          debugPrint(
            'QUEUE REALTIME ERROR: $error',
          );
        },
      );
    } catch (e) {
      debugPrint(
        'START REALTIME ERROR: $e',
      );
    }
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadQueueInfo({
    bool showLoading = true,
  }) async {
    if (!mounted) return;

    if (showLoading) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }

    try {
      final ticket = await _service.getTicket(
        widget.ticketId,
      );

      if (!mounted) return;

      if (ticket == null) {
        await _handleTicketDeleted();
        return;
      }

      _applyTicketData(ticket);

      // ----------------------------------------------------------
      // معلومات الطابور

      // ----------------------------------------------------------

      try {
        final info = await _service.getCustomerQueueInfo(
          widget.ticketId,
        );

        if (!mounted) return;

        _applyQueueInfo(info);
      } catch (e) {
        debugPrint(
          'GET CUSTOMER QUEUE INFO ERROR: $e',
        );
      }

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = false;
      });
    } catch (e, stackTrace) {
      debugPrint(
        'LOAD QUEUE ERROR: $e',
      );
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  // ============================================================
  // DELETE TICKET
  // ============================================================

  Future<void> _handleTicketDeleted() async {
    await CustomerStorage.removeTicketId(
      widget.ticketId,
    );

    if (!mounted) return;

    setState(() {
      _ticket = null;
      _loading = false;
      _error = false;
    });

    _timer?.cancel();

    await _ticketSubscription?.cancel();

    _ticketSubscription = null;

    _showMessage(
      'انتهت صلاحية هذا الحجز وتم حذفه.',
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign:
                TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          duration:
              const Duration(seconds: 3),
        ),
      );
  }

  // ============================================================
  // DATA HELPERS
  // ============================================================

  int _toInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  void _applyTicketData(
    Map<String, dynamic>? data,
  ) {
    if (!mounted || data == null) return;

    final ticket = Map<String, dynamic>.from(data);

    String status = _status;

    final rawStatus = ticket['status'];

    if (rawStatus != null) {
      status = rawStatus
          .toString()
          .trim()
          .toLowerCase();
    }

    setState(() {
      _ticket = ticket;
      _status = status;
      _error = false;
    });
  }

  void _applyQueueInfo(
    Map<String, dynamic>? info,
  ) {
    if (!mounted || info == null) return;

    final dynamic nestedTicket = info['ticket'];

    Map<String, dynamic> ticketData;

    if (nestedTicket is Map) {
      ticketData = Map<String, dynamic>.from(nestedTicket);
    } else {
      ticketData = Map<String, dynamic>.from(info);
    }

    final int ticketNumber = _toInt(
      ticketData['ticket_number'] ??
          info['ticket_number'],
    );

    if (ticketNumber > 0) {
      ticketData['ticket_number'] = ticketNumber;
    }

    // عدد الأشخاص الذين ينتظرون قبلك.
    final int peopleBefore = _toInt(
      info['waiting_ahead'] ??
          info['people_before'],
    );

    // الدور الذي يخدمه الحلاق حاليًا.
    int currentNumber = _toInt(
      info['current_number'],
    );

    final dynamic currentServing = info['current_serving'];

    if (currentNumber <= 0 &&
        currentServing is Map) {
      currentNumber = _toInt(
        currentServing['ticket_number'],
      );
    }

    // إذا لم يوجد عميل قيد الخدمة حاليًا.
    if (currentServing == null) {
      currentNumber = 0;
    }

    String status = _status;

    final rawStatus = ticketData['status'];

    if (rawStatus != null) {
      status = rawStatus
          .toString()
          .trim()
          .toLowerCase();
    }

    setState(() {
      _ticket = ticketData;
      _peopleBefore = peopleBefore;
      _currentNumber = currentNumber;
      _status = status;
      _loading = false;
      _error = false;
    });

    _checkNotifications(
      peopleBefore: peopleBefore,
      status: status,
    );
  }

  int _getRealTicketNumber() {
    if (_ticket == null) return 0;

    final values = <dynamic>[
      _ticket!['ticket_number'],
      _ticket!['ticketNumber'],
      _ticket!['queue_number'],
      _ticket!['queueNumber'],
      _ticket!['number'],
    ];

    for (final value in values) {
      final number = _toInt(value);
      if (number > 0) {
        return number;
      }
    }

    return 0;
  }

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  void _checkNotifications({
    required int peopleBefore,
    required String status,
  }) {
    final isServing =
        status == 'serving' ||
        status == 'in_progress' ||
        status == 'in-progress' ||
        status == 'called';

    if (isServing && !_servingNotified) {
      _servingNotified = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showMessage('حان دورك الآن ✂️');
        }
      });
    }

    if (!isServing && peopleBefore != 1) {
      _oneBeforeNotified = false;
    }

    if (peopleBefore == 1 &&
        !isServing &&
        !_oneBeforeNotified) {
      _oneBeforeNotified = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showMessage('بقي شخص واحد قبلك 🔔');
        }
      });
    }

    if (!isServing) {
      _servingNotified = false;
    }
  }

  // ============================================================
  // STATUS TEXT
  // ============================================================

  String _getStatusText() {
    switch (_status) {
      case 'serving':
      case 'in_progress':
      case 'in-progress':
      case 'called':
        return 'حان دورك الآن';

      case 'completed':
      case 'done':
      case 'finished':
        return 'تم إكمال الحجز';

      case 'cancelled':
      case 'canceled':
        return 'تم إلغاء الحجز';

      case 'skipped':
        return 'تم تجاوز الحجز';

      case 'waiting':
      case 'pending':
      default:
        return 'في الانتظار';
    }
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color _getStatusColor() {
    switch (_status) {
      case 'serving':
      case 'in_progress':
      case 'in-progress':
      case 'called':
        return Colors.green;

      case 'completed':
      case 'done':
      case 'finished':
        return Colors.blue;

      case 'cancelled':
      case 'canceled':
      case 'skipped':
        return Colors.red;

      case 'waiting':
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
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
              'تعذر تحميل معلومات الحجز',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                _loadQueueInfo();
              },
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'إعادة المحاولة',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent() {
    if (_ticket == null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.event_busy,
                size: 70,
                color: Colors.grey,
              ),
              const SizedBox(height: 20),
              const Text(
                'هذا الحجز لم يعد موجودًا',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'ربما انتهت مدة الحجز البالغة 48 ساعة.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 25),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context)
                      .pop();
                },
                icon: const Icon(
                  Icons.arrow_back,
                ),
                label: const Text(
                  'العودة',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          _loadQueueInfo(
        showLoading: false,
      ),
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.all(18),
        children: [
          _buildCustomerName(),

          const SizedBox(height: 18),

          _buildStatusCard(),

          const SizedBox(height: 18),

          _buildTicketNumber(),

          const SizedBox(height: 18),

          _buildPeopleBefore(),

          const SizedBox(height: 18),

          _buildCurrentNumber(),

          const SizedBox(height: 18),

          _buildRemainingTurns(),

          const SizedBox(height: 18),

          _buildQueueOrder(),

          const SizedBox(height: 25),

          _buildRefreshButton(),

          const SizedBox(height: 20),

          const Text(
            'يتم تحديث حالة الطابور تلقائيًا.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 15),

          const Text(
            '🔔 سيصدر تنبيه عند بقاء شخص واحد قبلك وعند وصول دورك.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 15),
        ],
      ),
    );
  }

  // ============================================================
  // CUSTOMER NAME
  // ============================================================

  Widget _buildCustomerName() {
    final name =
        _ticket?['customer_name']
            ?.toString()
            .trim();

    if (name == null || name.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      'مرحبًا $name 👋',
      textAlign:
          TextAlign.center,
      style: const TextStyle(
        fontSize: 19,
        fontWeight:
            FontWeight.w600,
      ),
    );
  }

  // ============================================================
  // STATUS CARD
  // ============================================================

  Widget _buildStatusCard() {
    final color =
        _getStatusColor();

    final isServing =
        _status == 'serving' ||
        _status == 'in_progress' ||
        _status == 'in-progress' ||
        _status == 'called';

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color:
            color.withOpacity(0.10),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              color.withOpacity(0.30),
        ),
      ),
      child: Column(
        children: [
          Icon(
            isServing
                ? Icons.content_cut
                : Icons.access_time,
            size: 55,
            color: color,
          ),
          const SizedBox(height: 12),
          Text(
            _getStatusText(),
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight:
                  FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TICKET NUMBER
  // ============================================================

  Widget _buildTicketNumber() {
    final ticketNumber =
        _getRealTicketNumber();

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        vertical: 25,
        horizontal: 20,
      ),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(20),
        color: Theme.of(context)
            .colorScheme
            .primary
            .withOpacity(0.08),
      ),
      child: Column(
        children: [
          const Text(
            'رقم تذكرتك',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ticketNumber > 0
                ? '#$ticketNumber'
                : '-',
            style: const TextStyle(
              fontSize: 50,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PEOPLE BEFORE
  // ============================================================

  Widget _buildPeopleBefore() {
    if (_status != 'waiting' &&
        _status != 'pending') {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.orange
            .withOpacity(0.08),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: Colors.orange
              .withOpacity(0.25),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.people_alt_outlined,
            size: 45,
            color: Colors.orange,
          ),
          const SizedBox(height: 10),
          const Text(
            'الأشخاص الذين قبلك',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _peopleBefore.toString(),
            style: const TextStyle(
              fontSize: 42,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _peopleBefore == 1
                ? 'بقي شخص واحد فقط'
                : 'أشخاص في الانتظار قبلك',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color:
                  Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CURRENT NUMBER
  // ============================================================

  Widget _buildCurrentNumber() {
    if (_currentNumber <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.blue
            .withOpacity(0.08),
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.content_cut,
            color: Colors.blue,
            size: 40,
          ),
          const SizedBox(height: 8),
          const Text(
            'الدور الحالي',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '#$_currentNumber',
            textAlign:
                TextAlign.center,
            style: const TextStyle(
              fontSize: 34,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REMAINING TURNS
  // ============================================================

  Widget _buildRemainingTurns() {
    if (_status != 'waiting' &&
        _status != 'pending') {
      return const SizedBox.shrink();
    }

    final ticketNumber =
        _getRealTicketNumber();

    if (ticketNumber <= 0 ||
        _currentNumber <= 0) {
      return const SizedBox.shrink();
    }

    final remainingTurns =
        (ticketNumber -
                _currentNumber)
            .clamp(0, 999999);

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.green
            .withOpacity(0.08),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: Colors.green
              .withOpacity(0.25),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.hourglass_bottom,
            size: 45,
            color: Colors.green,
          ),
          const SizedBox(height: 10),
          const Text(
            'باقي لك',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$remainingTurns',
            style: const TextStyle(
              fontSize: 42,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            remainingTurns == 1
                ? 'دور واحد فقط'
                : 'أدوار حتى يصل دورك',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color:
                  Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QUEUE ORDER
  // ============================================================

  Widget _buildQueueOrder() {
    if (_status != 'waiting' &&
        _status != 'pending') {
      return const SizedBox.shrink();
    }

    final ticketNumber =
        _getRealTicketNumber();

    if (ticketNumber <= 0 ||
        _currentNumber <= 0 ||
        ticketNumber < _currentNumber) {
      return const SizedBox.shrink();
    }

    final numbers = <int>[];

    final gap =
        ticketNumber -
            _currentNumber;

    if (gap <= 6) {
      for (
        int number =
            _currentNumber;
        number <= ticketNumber;
        number++
      ) {
        numbers.add(number);
      }
    } else {
      numbers.add(_currentNumber);
      numbers.add(
        _currentNumber + 1,
      );
      numbers.add(
        _currentNumber + 2,
      );
      numbers.add(-1);
      numbers.add(
        ticketNumber - 1,
      );
      numbers.add(ticketNumber);
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: Colors.blue
              .withOpacity(0.18),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'ترتيب الأدوار',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'من الدور الحالي حتى دورك',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color:
                  Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment:
                WrapAlignment.center,
            crossAxisAlignment:
                WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 10,
            children: [
              for (
                int i = 0;
                i < numbers.length;
                i++
              ) ...[
                _buildQueueNumber(
                  numbers[i],
                  ticketNumber,
                ),
                if (i <
                        numbers.length - 1 &&
                    numbers[i] != -1)
                  Icon(
                    Icons
                        .arrow_back_rounded,
                    size: 20,
                    color: Colors
                        .grey.shade500,
                  ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment:
                WrapAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildQueueLegend(
                Icons.circle,
                'الدور الحالي',
              ),
              _buildQueueLegend(
                Icons.person,
                'دورك',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QUEUE NUMBER
  // ============================================================

  Widget _buildQueueNumber(
    int number,
    int ticketNumber,
  ) {
    if (number == -1) {
      return Text(
        '•••',
        style: TextStyle(
          fontSize: 22,
          fontWeight:
              FontWeight.bold,
          color:
              Colors.grey.shade500,
        ),
      );
    }

    final isCurrent =
        number == _currentNumber;

    final isMine =
        number == ticketNumber;

    return Container(
      constraints:
          const BoxConstraints(
        minWidth: 58,
        minHeight: 58,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: isMine
              ? Colors.green
              : isCurrent
                  ? Colors.blue
                  : Colors.grey.shade300,
          width:
              isMine || isCurrent
                  ? 2
                  : 1,
        ),
        color: isMine
            ? Colors.green
                .withOpacity(0.10)
            : isCurrent
                ? Colors.blue
                    .withOpacity(0.10)
                : Colors.grey
                    .withOpacity(0.06),
      ),
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Text(
            '#$number',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
              color: isMine
                  ? Colors.green.shade700
                  : isCurrent
                      ? Colors.blue.shade700
                      : null,
            ),
          ),
          if (isMine)
            const Text(
              'دورك',
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.w600,
                color:
                    Colors.green,
              ),
            )
          else if (isCurrent)
            const Text(
              'الآن',
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.w600,
                color: Colors.blue,
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // QUEUE LEGEND
  // ============================================================

  Widget _buildQueueLegend(
    IconData icon,
    String label,
  ) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color:
              Colors.grey.shade600,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color:
                Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // REFRESH BUTTON
  // ============================================================

  Widget _buildRefreshButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () {
          _loadQueueInfo();
        },
        icon: const Icon(
          Icons.refresh,
        ),
        label: const Text(
          'تحديث حالة الطابور',
          style: TextStyle(
            fontSize: 16,
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _timer?.cancel();
    _ticketSubscription?.cancel();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

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
            'حالة الحجز',
          ),
          centerTitle: true,
        ),
        body: _loading &&
                _ticket == null
            ? _buildLoading()
            : _error &&
                    _ticket == null
                ? _buildError()
                : _buildContent(),
      ),
    );
  }
}
