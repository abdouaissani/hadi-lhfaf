import 'package:flutter/material.dart';

import '../models/service_model.dart';
import '../services/supabase_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({
    super.key,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final SupabaseService _service = SupabaseService();

  String _barberId = '';

  bool _loading = true;
  bool _queueEnabled = true;
  bool _nextLoading = false;
  bool _logoutLoading = false;
  bool _queueToggleLoading = false;

  List<ServiceModel> _services = <ServiceModel>[];

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
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      String barberId = '';

      // محاولة استخدام Auth User ID
      final userBarber = await _service.getBarber(user.id);

      if (userBarber != null) {
        barberId = user.id;
      } else {
        // إذا لم يكن Auth ID موجودًا في barbers
        barberId = await _service.getSingleBarber();
      }

      if (barberId.isEmpty) {
        if (!mounted) {
          return;
        }

        setState(() {
          _loading = false;
        });

        _showMessage(
          'لم يتم العثور على حساب الحلاق',
        );

        return;
      }

      final enabled = await _service.isQueueEnabled(
        barberId,
      );

      if (!mounted) {
        return;
      }

      _barberId = barberId;

      setState(() {
        _queueEnabled = enabled;
        _loading = false;
      });

      await _loadServices();
    } catch (e) {
      debugPrint('INITIALIZE ERROR: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

      _showMessage(
        'تعذر تحميل لوحة التحكم: $e',
      );
    }
  }

  // =========================================================
  // SERVICES
  // =========================================================

  Future<void> _loadServices() async {
    if (_barberId.isEmpty) {
      return;
    }

    try {
      final services = await _service.getAllServices(
        _barberId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _services = services;
      });
    } catch (e) {
      debugPrint('LOAD SERVICES ERROR: $e');

      if (!mounted) {
        return;
      }

      _showMessage(
        'تعذر تحميل الخدمات',
      );
    }
  }

  // =========================================================
  // QUEUE TOGGLE
  // =========================================================

  Future<void> _toggleQueue(bool value) async {
    if (_barberId.isEmpty || _queueToggleLoading) {
      return;
    }

    final oldValue = _queueEnabled;

    setState(() {
      _queueEnabled = value;
      _queueToggleLoading = true;
    });

    try {
      await _service.setQueueEnabled(
        _barberId,
        value,
      );

      if (mounted) {
        _showMessage(
          value
              ? 'تم فتح استقبال الحجوزات'
              : 'تم إغلاق استقبال الحجوزات',
        );
      }
    } catch (e) {
      debugPrint('TOGGLE QUEUE ERROR: $e');

      if (mounted) {
        setState(() {
          _queueEnabled = oldValue;
        });

        _showMessage(
          'تعذر تغيير حالة الحجز',
        );
      }
    } finally {
      // لا يوجد return داخل finally
      if (mounted) {
        setState(() {
          _queueToggleLoading = false;
        });
      }
    }
  }

  // =========================================================
  // ADD SERVICE
  // =========================================================

  Future<void> _showAddServiceDialog() async {
    if (_barberId.isEmpty) {
      _showMessage(
        'لم يتم العثور على حساب الحلاق',
      );
      return;
    }

    final nameController = TextEditingController();
    final priceController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: const Text(
                  'إضافة خدمة',
                ),
                content: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'اسم الخدمة',
                            hintText: 'مثال: قص شعر',
                            prefixIcon: const Icon(
                              Icons.content_cut,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            final text =
                                value?.trim() ?? '';

                            if (text.isEmpty) {
                              return 'أدخل اسم الخدمة';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: priceController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'السعر',
                            hintText: 'مثال: 500',
                            prefixIcon: const Icon(
                              Icons.payments_outlined,
                            ),
                            suffixText: 'DA',
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            final text =
                                value?.trim() ?? '';

                            if (text.isEmpty) {
                              return 'أدخل السعر';
                            }

                            final price =
                                double.tryParse(
                              text.replaceAll(',', '.'),
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
                    onPressed: saving
                        ? null
                        : () {
                            Navigator.of(
                              dialogContext,
                            ).pop();
                          },
                    child: const Text('إلغاء'),
                  ),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!
                                .validate()) {
                              return;
                            }

                            setDialogState(() {
                              saving = true;
                            });

                            try {
                              final price =
                                  double.parse(
                                priceController.text
                                    .trim()
                                    .replaceAll(',', '.'),
                              );

                              await _service.addService(
                                barberId: _barberId,
                                name: nameController.text
                                    .trim(),
                                price: price,
                              );

                              if (!dialogContext.mounted) {
                                return;
                              }

                              Navigator.of(
                                dialogContext,
                              ).pop();

                              await _loadServices();

                              if (mounted) {
                                _showMessage(
                                  'تمت إضافة الخدمة بنجاح',
                                );
                              }
                            } catch (e) {
                              debugPrint(
                                'ADD SERVICE ERROR: $e',
                              );

                              if (!dialogContext.mounted) {
                                return;
                              }

                              setDialogState(() {
                                saving = false;
                              });

                              _showMessage(
                                'تعذر إضافة الخدمة: $e',
                              );
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('إضافة'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    priceController.dispose();
  }

  // =========================================================
  // EDIT SERVICE
  // =========================================================

  Future<void> _showEditServiceDialog(
    ServiceModel service,
  ) async {
    final nameController = TextEditingController(
      text: service.name,
    );

    final priceController = TextEditingController(
      text: service.price.toString(),
    );

    final formKey = GlobalKey<FormState>();

    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: const Text(
                  'تعديل الخدمة',
                ),
                content: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'اسم الخدمة',
                            prefixIcon: const Icon(
                              Icons.content_cut,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            final text =
                                value?.trim() ?? '';

                            if (text.isEmpty) {
                              return 'أدخل اسم الخدمة';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: priceController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'السعر',
                            suffixText: 'DA',
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            final text =
                                value?.trim() ?? '';

                            final price =
                                double.tryParse(
                              text.replaceAll(',', '.'),
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
                    onPressed: saving
                        ? null
                        : () {
                            Navigator.of(
                              dialogContext,
                            ).pop();
                          },
                    child: const Text('إلغاء'),
                  ),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!
                                .validate()) {
                              return;
                            }

                            setDialogState(() {
                              saving = true;
                            });

                            try {
                              final price =
                                  double.parse(
                                priceController.text
                                    .trim()
                                    .replaceAll(',', '.'),
                              );

                              await _service.updateService(
                                serviceId: service.id,
                                name: nameController.text
                                    .trim(),
                                price: price,
                              );

                              if (!dialogContext.mounted) {
                                return;
                              }

                              Navigator.of(
                                dialogContext,
                              ).pop();

                              await _loadServices();

                              if (mounted) {
                                _showMessage(
                                  'تم تعديل الخدمة بنجاح',
                                );
                              }
                            } catch (e) {
                              debugPrint(
                                'UPDATE SERVICE ERROR: $e',
                              );

                              if (!dialogContext.mounted) {
                                return;
                              }

                              setDialogState(() {
                                saving = false;
                              });

                              _showMessage(
                                'تعذر تعديل الخدمة',
                              );
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('حفظ'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    priceController.dispose();
  }

  // =========================================================
  // TOGGLE SERVICE
  // =========================================================

  Future<void> _toggleService(
    ServiceModel service,
  ) async {
    try {
      await _service.setServiceActive(
        serviceId: service.id,
        active: !service.isActive,
      );

      await _loadServices();

      if (mounted) {
        _showMessage(
          service.isActive
              ? 'تم تعطيل الخدمة'
              : 'تم تفعيل الخدمة',
        );
      }
    } catch (e) {
      debugPrint(
        'TOGGLE SERVICE ERROR: $e',
      );

      if (mounted) {
        _showMessage(
          'تعذر تغيير حالة الخدمة',
        );
      }
    }
  }

  // =========================================================
  // DELETE SERVICE
  // =========================================================

  Future<void> _deleteService(
    ServiceModel service,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('حذف الخدمة'),
            content: Text(
              'هل أنت متأكد من حذف "${service.name}"؟',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(false);
                },
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(true);
                },
                child: const Text('حذف'),
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
      await _service.deleteService(
        service.id,
      );

      await _loadServices();

      if (mounted) {
        _showMessage(
          'تم حذف الخدمة',
        );
      }
    } catch (e) {
      debugPrint(
        'DELETE SERVICE ERROR: $e',
      );

      if (mounted) {
        _showMessage(
          e.toString().replaceFirst(
                'Exception: ',
                '',
              ),
        );
      }
    }
  }

  // =========================================================
  // NEXT CUSTOMER
  // =========================================================

  Future<void> _nextCustomer() async {
    if (_barberId.isEmpty || _nextLoading) {
      return;
    }

    setState(() {
      _nextLoading = true;
    });

    try {
      final result = await _service.nextQueueTicket(
        _barberId,
      );

      if (!mounted) {
        return;
      }

      final message =
          result['message']?.toString() ?? '';

      if (message == 'NO_MORE_CUSTOMERS') {
        _showMessage(
          'لا يوجد زبائن في الانتظار',
        );
      } else {
        final number =
            result['ticket_number']?.toString() ?? '';

        if (number.isEmpty || number == 'null') {
          _showMessage(
            'تم استدعاء الزبون التالي',
          );
        } else {
          _showMessage(
            'تم استدعاء الدور #$number',
          );
        }
      }
    } catch (e) {
      debugPrint(
        'NEXT CUSTOMER ERROR: $e',
      );

      if (mounted) {
        _showMessage(
          'حدث خطأ أثناء استدعاء الدور التالي',
        );
      }
    } finally {
      // تم إصلاح مشكلة control_flow_in_finally
      if (mounted) {
        setState(() {
          _nextLoading = false;
        });
      }
    }
  }

  // =========================================================
  // COMPLETE OLD TICKET
  // =========================================================

  Future<void> _completeOldTicket(
    Map<String, dynamic> ticket,
  ) async {
    final id =
        ticket['id']?.toString() ?? '';

    if (id.isEmpty) {
      return;
    }

    final number =
        ticket['ticket_number']?.toString() ?? '--';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text(
              'إنهاء الدور القديم',
            ),
            content: Text(
              'هل تريد إنهاء الدور #$number وحذفه نهائياً؟',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(false);
                },
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(true);
                },
                child: const Text(
                  'إنهاء وحذف',
                ),
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
      await _service.completeTicket(id);

      await _service.deleteTicket(id);

      if (mounted) {
        _showMessage(
          'تم إنهاء وحذف الدور #$number',
        );
      }
    } catch (e) {
      debugPrint(
        'COMPLETE OLD TICKET ERROR: $e',
      );

      if (mounted) {
        _showMessage(
          'تعذر إنهاء الدور: $e',
        );
      }
    }
  }

  // =========================================================
  // DELETE OLD TICKET
  // =========================================================

  Future<void> _deleteOldTicket(
    Map<String, dynamic> ticket,
  ) async {
    final id =
        ticket['id']?.toString() ?? '';

    if (id.isEmpty) {
      return;
    }

    try {
      await _service.deleteTicket(id);

      if (mounted) {
        _showMessage(
          'تم حذف الدور',
        );
      }
    } catch (e) {
      debugPrint(
        'DELETE OLD TICKET ERROR: $e',
      );

      if (mounted) {
        _showMessage(
          'تعذر حذف الدور',
        );
      }
    }
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> _logout() async {
    if (_logoutLoading) {
      return;
    }

    setState(() {
      _logoutLoading = true;
    });

    try {
      await _service.barberLogout();

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint(
        'LOGOUT ERROR: $e',
      );

      if (mounted) {
        setState(() {
          _logoutLoading = false;
        });

        _showMessage(
          'تعذر تسجيل الخروج',
        );
      }
    }
  }

  // =========================================================
  // MESSAGE
  // =========================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    final messenger =
        ScaffoldMessenger.maybeOf(context);

    if (messenger == null) {
      return;
    }

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.right,
        ),
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
  // DISPLAY DATE
  // =========================================================

  String _displayDate(String date) {
    if (date.isEmpty) {
      return '';
    }

    final parts = date.split('-');

    if (parts.length != 3) {
      return date;
    }

    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  // =========================================================
  // STATUS
  // =========================================================

  String _statusText(String status) {
    switch (status) {
      case 'waiting':
        return 'في الانتظار';

      case 'serving':
        return 'يتم خدمته';

      case 'completed':
        return 'مكتمل';

      case 'cancelled':
        return 'ملغى';

      case 'skipped':
        return 'تم تخطيه';

      default:
        return status;
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_barberId.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text(
            'لم يتم العثور على حساب الحلاق',
          ),
        ),
      );
    }

    final barberId = _barberId;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'لوحة الحلاق',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'تسجيل الخروج',
              onPressed:
                  _logoutLoading ? null : _logout,
              icon: _logoutLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.logout,
                    ),
            ),
          ],
        ),
        body: StreamBuilder<
            List<Map<String, dynamic>>>(
          stream: _service.watchQueue(barberId),
          builder: (
            context,
            snapshot,
          ) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding:
                      const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 60,
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'حدث خطأ في تحميل الطابور',
                        textAlign:
                            TextAlign.center,
                      ),
                      const SizedBox(height: 15),
                      Text(
                        snapshot.error.toString(),
                        textAlign:
                            TextAlign.center,
                      ),
                      const SizedBox(height: 15),
                      FilledButton(
                        onPressed: () {
                          setState(() {});
                        },
                        child: const Text(
                          'إعادة المحاولة',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child:
                    CircularProgressIndicator(),
              );
            }

            final tickets =
                snapshot.data ??
                    <Map<String, dynamic>>[];

            final today = _todayDate();

            // =================================================
            // حجوزات اليوم
            // =================================================

            final todayTickets =
                tickets.where((ticket) {
              return ticket['queue_date']
                      ?.toString() ==
                  today;
            }).toList();

            // =================================================
            // الحجوزات القديمة غير المكتملة
            // =================================================

            final oldTickets =
                tickets.where((ticket) {
              final date =
                  ticket['queue_date']
                          ?.toString() ??
                      '';

              final status =
                  ticket['status']
                          ?.toString() ??
                      '';

              final old =
                  date.isNotEmpty &&
                      date.compareTo(today) < 0;

              final unfinished =
                  status == 'waiting' ||
                      status == 'serving';

              return old && unfinished;
            }).toList();

            oldTickets.sort(
              (a, b) {
                final aDate =
                    a['queue_date']
                            ?.toString() ??
                        '';

                final bDate =
                    b['queue_date']
                            ?.toString() ??
                        '';

                final dateCompare =
                    bDate.compareTo(aDate);

                if (dateCompare != 0) {
                  return dateCompare;
                }

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

                return aNumber.compareTo(
                  bNumber,
                );
              },
            );

            // =================================================
            // الدور الحالي
            // =================================================

            final serving =
                todayTickets.where((ticket) {
              return ticket['status']
                      ?.toString() ==
                  'serving';
            }).toList();

            int currentNumber = 0;

            if (serving.isNotEmpty) {
              currentNumber =
                  int.tryParse(
                        serving.first[
                                    'ticket_number']
                                ?.toString() ??
                            '',
                      ) ??
                      0;
            }

            // =================================================
            // المنتظرين
            // =================================================

            final waiting =
                todayTickets.where((ticket) {
              return ticket['status']
                      ?.toString() ==
                  'waiting';
            }).toList();

            waiting.sort(
              (a, b) {
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

                return aNumber.compareTo(
                  bNumber,
                );
              },
            );

            return RefreshIndicator(
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
                    const EdgeInsets.all(16),
                children: [
                  // =================================================
                  // DATE
                  // =================================================

                  Container(
                    padding:
                        const EdgeInsets.all(16),
                    decoration:
                        BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(18),
                      border: Border.all(
                        color:
                            Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              const Text(
                                'تاريخ اليوم',
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                              const SizedBox(
                                height: 4,
                              ),
                              Text(
                                _displayDate(today),
                                style:
                                    const TextStyle(
                                  fontSize: 18,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // =================================================
                  // QUEUE STATUS
                  // =================================================

                  Container(
                    padding:
                        const EdgeInsets.all(16),
                    decoration:
                        BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(18),
                      border: Border.all(
                        color:
                            Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration:
                              BoxDecoration(
                            shape:
                                BoxShape.circle,
                            color: _queueEnabled
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              const Text(
                                'حالة الحجز',
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                              Text(
                                _queueEnabled
                                    ? 'استقبال الحجوزات مفتوح'
                                    : 'استقبال الحجوزات مغلق',
                                style: TextStyle(
                                  color: _queueEnabled
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _queueEnabled,
                          onChanged:
                              _queueToggleLoading
                                  ? null
                                  : _toggleQueue,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // =================================================
                  // CURRENT
                  // =================================================

                  Container(
                    padding:
                        const EdgeInsets.all(25),
                    decoration:
                        BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(22),
                      border: Border.all(
                        color:
                            Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'الدور الحالي',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentNumber == 0
                              ? '--'
                              : '#$currentNumber',
                          style:
                              const TextStyle(
                            fontSize: 58,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'عدد المنتظرين: ${waiting.length}',
                          style:
                              const TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        if (currentNumber != 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            'الحلاق يخدم الدور #$currentNumber',
                            style: TextStyle(
                              color:
                                  Colors.green.shade700,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // =================================================
                  // NEXT
                  // =================================================

                  SizedBox(
                    height: 60,
                    child: FilledButton.icon(
                      onPressed:
                          _nextLoading ||
                                  waiting.isEmpty
                              ? null
                              : _nextCustomer,
                      icon: _nextLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.arrow_forward,
                            ),
                      label: Text(
                        waiting.isEmpty
                            ? 'لا يوجد دور تالٍ'
                            : 'استدعاء التالي',
                        style:
                            const TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // =================================================
                  // OLD TICKETS
                  // =================================================

                  if (oldTickets.isNotEmpty) ...[
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'أدوار سابقة غير مكتملة',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                        CircleAvatar(
                          radius: 18,
                          child: Text(
                            '${oldTickets.length}',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Container(
                      padding:
                          const EdgeInsets.all(12),
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.orange.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius:
                            BorderRadius.circular(15),
                        border: Border.all(
                          color:
                              Colors.orange.withValues(
                            alpha: 0.30,
                          ),
                        ),
                      ),
                      child: const Text(
                        'هذه أدوار من أيام سابقة ولم يتم إكمالها. أكمل الدور ثم احذفه نهائياً.',
                        textAlign:
                            TextAlign.right,
                      ),
                    ),

                    const SizedBox(height: 12),

                    ...oldTickets.map(
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

                        final date =
                            ticket['queue_date']
                                    ?.toString() ??
                                '';

                        final status =
                            ticket['status']
                                    ?.toString() ??
                                '';

                        return Card(
                          margin:
                              const EdgeInsets.only(
                            bottom: 10,
                          ),
                          child: Padding(
                            padding:
                                const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                ListTile(
                                  leading:
                                      CircleAvatar(
                                    child: Text(
                                      '#$number',
                                      style:
                                          const TextStyle(
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    name,
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'التاريخ: ${_displayDate(date)}'
                                    '${phone.isEmpty ? '' : '\nالهاتف: $phone'}'
                                    '\nالحالة: ${_statusText(status)}',
                                  ),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child:
                                          FilledButton
                                              .icon(
                                        onPressed: () =>
                                            _completeOldTicket(
                                          ticket,
                                        ),
                                        icon:
                                            const Icon(
                                          Icons.check,
                                        ),
                                        label:
                                            const Text(
                                          'إنهاء وحذف',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 8,
                                    ),
                                    IconButton(
                                      tooltip:
                                          'حذف فقط',
                                      onPressed: () =>
                                          _deleteOldTicket(
                                        ticket,
                                      ),
                                      icon:
                                          const Icon(
                                        Icons
                                            .delete_outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                  ],

                  // =================================================
                  // TODAY BOOKINGS
                  // =================================================

                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'حجوزات اليوم',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                      CircleAvatar(
                        radius: 18,
                        child: Text(
                          '${waiting.length}',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (waiting.isEmpty)
                    Container(
                      padding:
                          const EdgeInsets.all(30),
                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(18),
                        border: Border.all(
                          color:
                              Colors.grey.shade300,
                        ),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons
                                .event_available_outlined,
                            size: 55,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'لا يوجد زبائن في الانتظار',
                            textAlign:
                                TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
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

                        return Card(
                          margin:
                              const EdgeInsets.only(
                            bottom: 10,
                          ),
                          child: ListTile(
                            leading:
                                CircleAvatar(
                              child: Text(
                                '#$number',
                                style:
                                    const TextStyle(
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Text(
                              name,
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            subtitle:
                                phone.isEmpty
                                    ? const Text(
                                        'في الانتظار',
                                      )
                                    : Text(
                                        '$phone\nفي الانتظار',
                                      ),
                            trailing:
                                const Icon(
                              Icons
                                  .hourglass_empty,
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 30),

                  // =================================================
                  // SERVICES
                  // =================================================

                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'الخدمات',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed:
                            _showAddServiceDialog,
                        icon: const Icon(
                          Icons.add,
                        ),
                        label: const Text(
                          'إضافة',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (_services.isEmpty)
                    Container(
                      padding:
                          const EdgeInsets.all(25),
                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(18),
                        border: Border.all(
                          color:
                              Colors.grey.shade300,
                        ),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons
                                .content_cut_outlined,
                            size: 50,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'لا توجد خدمات',
                          ),
                        ],
                      ),
                    )
                  else
                    ..._services.map(
                      (service) {
                        return Card(
                          margin:
                              const EdgeInsets.only(
                            bottom: 10,
                          ),
                          child: ListTile(
                            leading:
                                const CircleAvatar(
                              child: Icon(
                                Icons.content_cut,
                              ),
                            ),
                            title: Text(
                              service.name,
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${service.price.toStringAsFixed(0)} DA'
                              '${service.isActive ? '' : ' • غير مفعلة'}',
                            ),
                            trailing:
                                PopupMenuButton<String>(
                              onSelected:
                                  (value) {
                                switch (value) {
                                  case 'edit':
                                    _showEditServiceDialog(
                                      service,
                                    );
                                    break;

                                  case 'active':
                                    _toggleService(
                                      service,
                                    );
                                    break;

                                  case 'delete':
                                    _deleteService(
                                      service,
                                    );
                                    break;
                                }
                              },
                              itemBuilder:
                                  (context) {
                                return [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child:
                                        Text('تعديل'),
                                  ),
                                  PopupMenuItem(
                                    value: 'active',
                                    child: Text(
                                      service.isActive
                                          ? 'تعطيل'
                                          : 'تفعيل',
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child:
                                        Text('حذف'),
                                  ),
                                ];
                              },
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}