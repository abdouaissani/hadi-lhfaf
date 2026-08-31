import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/service_model.dart';
import 'notification_service.dart';

class SupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // =========================================================
  // AUTH
  // =========================================================

  User? get currentUser {
    return _supabase.auth.currentUser;
  }

  Future<void> barberLogin({
    required String email,
    required String password,
  }) async {
    await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> barberLogout() async {
    await _supabase.auth.signOut();
  }

  // =========================================================
  // BARBER
  // =========================================================

  Future<String> getSingleBarber() async {
    try {
      final response = await _supabase
          .from('barbers')
          .select('id')
          .limit(1);

      if (response.isEmpty) {
        throw Exception('NO_BARBER_FOUND');
      }

      final id = response.first['id']?.toString() ?? '';

      if (id.isEmpty || id == 'null') {
        throw Exception('BARBER_ID_NOT_FOUND');
      }

      return id;
    } catch (e) {
      debugPrint('GET SINGLE BARBER ERROR: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getBarber(
    String barberId,
  ) async {
    try {
      if (barberId.isEmpty) {
        return null;
      }

      final response = await _supabase
          .from('barbers')
          .select()
          .eq('id', barberId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('GET BARBER ERROR: $e');
      rethrow;
    }
  }

  // =========================================================
  // QUEUE STATUS
  // =========================================================

  Future<bool> isQueueEnabled(
    String barberId,
  ) async {
    try {
      if (barberId.isEmpty) {
        return false;
      }

      final response = await _supabase
          .from('barbers')
          .select('queue_enabled')
          .eq('id', barberId)
          .maybeSingle();

      if (response == null) {
        return false;
      }

      return response['queue_enabled'] == true;
    } catch (e) {
      debugPrint('QUEUE STATUS ERROR: $e');
      rethrow;
    }
  }

  Future<void> setQueueEnabled(
    String barberId,
    bool enabled,
  ) async {
    try {
      if (barberId.isEmpty) {
        throw Exception('BARBER_ID_NOT_FOUND');
      }

      await _supabase
          .from('barbers')
          .update({
            'queue_enabled': enabled,
          })
          .eq('id', barberId);
    } catch (e) {
      debugPrint('SET QUEUE STATUS ERROR: $e');
      rethrow;
    }
  }

  // =========================================================
  // SERVICES - CUSTOMER
  // =========================================================

  Future<List<ServiceModel>> getServices(
    String barberId,
  ) async {
    try {
      final response = await _supabase
          .from('services')
          .select()
          .eq('barber_id', barberId)
          .eq('is_active', true)
          .order('name');

      return response
          .map<ServiceModel>(
            (item) => ServiceModel.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('GET SERVICES ERROR: $e');
      rethrow;
    }
  }

  // =========================================================
  // SERVICES - ADMIN
  // =========================================================

  Future<List<ServiceModel>> getAllServices(
    String barberId,
  ) async {
    try {
      final response = await _supabase
          .from('services')
          .select()
          .eq('barber_id', barberId)
          .order('name');

      return response
          .map<ServiceModel>(
            (item) => ServiceModel.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('GET ALL SERVICES ERROR: $e');
      rethrow;
    }
  }

  // =========================================================
  // ADD SERVICE
  // =========================================================

  Future<ServiceModel> addService({
    required String barberId,
    required String name,
    required double price,
  }) async {
    try {
      final cleanName = name.trim();

      if (barberId.isEmpty) {
        throw Exception('BARBER_ID_NOT_FOUND');
      }

      if (cleanName.isEmpty) {
        throw Exception('SERVICE_NAME_REQUIRED');
      }

      if (price < 0) {
        throw Exception('INVALID_PRICE');
      }

      final barber = await _supabase
          .from('barbers')
          .select('id')
          .eq('id', barberId)
          .maybeSingle();

      if (barber == null) {
        throw Exception('BARBER_NOT_FOUND');
      }

      final response = await _supabase
          .from('services')
          .insert({
            'barber_id': barberId,
            'name': cleanName,
            'price': price,
            'is_active': true,
          })
          .select()
          .single();

      return ServiceModel.fromMap(
        Map<String, dynamic>.from(response),
      );
    } catch (e) {
      debugPrint('ADD SERVICE ERROR: $e');
      rethrow;
    }
  }

  // =========================================================
  // UPDATE SERVICE
  // =========================================================

  Future<void> updateService({
    required String serviceId,
    required String name,
    required double price,
  }) async {
    try {
      final cleanName = name.trim();

      if (cleanName.isEmpty) {
        throw Exception('SERVICE_NAME_REQUIRED');
      }

      if (price < 0) {
        throw Exception('INVALID_PRICE');
      }

      await _supabase
          .from('services')
          .update({
            'name': cleanName,
            'price': price,
          })
          .eq('id', serviceId);
    } catch (e) {
      debugPrint('UPDATE SERVICE ERROR: $e');
      rethrow;
    }
  }

  // =========================================================
  // ACTIVE SERVICE
  // =========================================================

  Future<void> setServiceActive({
    required String serviceId,
    required bool active,
  }) async {
    try {
      await _supabase
          .from('services')
          .update({
            'is_active': active,
          })
          .eq('id', serviceId);
    } catch (e) {
      debugPrint('SET SERVICE ACTIVE ERROR: $e');
      rethrow;
    }
  }

  // =========================================================
  // DELETE SERVICE
  // =========================================================

  Future<void> deleteService(
    String serviceId,
  ) async {
    try {
      await _supabase
          .from('services')
          .delete()
          .eq('id', serviceId);
    } on PostgrestException catch (e) {
      debugPrint('DELETE SERVICE ERROR: $e');

      if (e.code == '23503') {
        throw Exception(
          'لا يمكن حذف هذه الخدمة لأنها مرتبطة بحجوزات سابقة. عطّلها بدلاً من حذفها.',
        );
      }

      rethrow;
    }
  }

  // =========================================================
  // CREATE BOOKING
  // =========================================================

  Future<Map<String, dynamic>> createBooking({
    required String barberId,
    required String serviceId,
    required String name,
    required String phone,
  }) async {
    try {
      final cleanName = name.trim();
      final cleanPhone = phone.trim();

      if (barberId.isEmpty) {
        throw Exception('BARBER_ID_NOT_FOUND');
      }

      if (serviceId.isEmpty) {
        throw Exception('INVALID_SERVICE');
      }

      if (cleanName.isEmpty) {
        throw Exception('CUSTOMER_NAME_REQUIRED');
      }

      if (cleanPhone.isEmpty) {
        throw Exception('CUSTOMER_PHONE_REQUIRED');
      }

      // -------------------------------------------------------
      // التحقق من الحلاق
      // -------------------------------------------------------

      final barber = await _supabase
          .from('barbers')
          .select('id, queue_enabled')
          .eq('id', barberId)
          .maybeSingle();

      if (barber == null) {
        throw Exception('BARBER_NOT_FOUND');
      }

      if (barber['queue_enabled'] != true) {
        throw Exception('QUEUE_CLOSED');
      }

      // -------------------------------------------------------
      // التحقق من الخدمة
      // -------------------------------------------------------

      final service = await _supabase
          .from('services')
          .select('id')
          .eq('id', serviceId)
          .eq('barber_id', barberId)
          .eq('is_active', true)
          .maybeSingle();

      if (service == null) {
        throw Exception('INVALID_SERVICE');
      }

      // -------------------------------------------------------
      // RPC
      // -------------------------------------------------------

      final response = await _supabase.rpc(
        'create_queue_ticket',
        params: {
          'p_barber_id': barberId,
          'p_service_id': serviceId,
          'p_customer_name': cleanName,
          'p_phone': cleanPhone,
        },
      );

      debugPrint(
        'CREATE BOOKING RESPONSE: $response',
      );

      if (response is! Map) {
        throw Exception('BOOKING_FAILED');
      }

      final result = Map<String, dynamic>.from(response);

      final ticketId = result['id']?.toString() ?? '';

      if (ticketId.isEmpty || ticketId == 'null') {
        throw Exception('TICKET_ID_NOT_FOUND');
      }

      // -------------------------------------------------------
      // FCM TOKEN
      // -------------------------------------------------------

      try {
        final token = await NotificationService
            .instance
            .getToken();

        if (token != null && token.isNotEmpty) {
          await _supabase
              .from('queue_tickets')
              .update({
                'fcm_token': token,
              })
              .eq('id', ticketId);
        }
      } catch (e) {
        debugPrint(
          'FCM TOKEN SAVE ERROR: $e',
        );
      }

      // -------------------------------------------------------
      // جلب الحجز
      // -------------------------------------------------------

      final savedTicket = await getTicket(ticketId);

      if (savedTicket != null) {
        return savedTicket;
      }

      return result;
    } on PostgrestException catch (e) {
      debugPrint(
        'CREATE BOOKING POSTGRES ERROR: ${e.message}',
      );

      debugPrint(
        'CODE: ${e.code}',
      );

      final message = e.message.toUpperCase();

      if (message.contains('INVALID_BARBER')) {
        throw Exception('BARBER_NOT_FOUND');
      }

      if (message.contains('QUEUE_CLOSED')) {
        throw Exception('QUEUE_CLOSED');
      }

      if (message.contains('QUEUE_FULL')) {
        throw Exception('QUEUE_FULL');
      }

      if (message.contains('INVALID_SERVICE')) {
        throw Exception('INVALID_SERVICE');
      }

      if (message.contains('DUPLICATE_BOOKING')) {
        throw Exception('DUPLICATE_BOOKING');
      }

      rethrow;
    } catch (e) {
      debugPrint(
        'CREATE BOOKING ERROR: $e',
      );
      rethrow;
    }
  }

  // =========================================================
  // GET TICKET
  // =========================================================

  Future<Map<String, dynamic>?> getTicket(
    String ticketId,
  ) async {
    try {
      final response = await _supabase
          .from('queue_tickets')
          .select()
          .eq('id', ticketId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('GET TICKET ERROR: $e');
      rethrow;
    }
  }

  // =========================================================
  // CUSTOMER QUEUE INFO
  // =========================================================

  Future<Map<String, dynamic>> getCustomerQueueInfo(
    String ticketId,
  ) async {
    final ticket = await getTicket(ticketId);

    if (ticket == null) {
      throw Exception('TICKET_NOT_FOUND');
    }

    final barberId = ticket['barber_id']?.toString() ?? '';
    final queueDate = ticket['queue_date']?.toString() ?? '';

    final ticketNumber =
        int.tryParse(
              ticket['ticket_number']?.toString() ?? '',
            ) ??
            0;

    if (barberId.isEmpty) {
      throw Exception('BARBER_ID_NOT_FOUND');
    }

    final rows = await _supabase
        .from('queue_tickets')
        .select(
          'id,ticket_number,status,queue_date,barber_id',
        )
        .eq('barber_id', barberId)
        .eq('queue_date', queueDate);

    int currentNumber = 0;
    int peopleBefore = 0;
    int waitingCount = 0;

    for (final row in rows) {
      final status = row['status']?.toString() ?? '';

      final number =
          int.tryParse(
                row['ticket_number']?.toString() ?? '',
              ) ??
              0;

      if (status == 'serving') {
        if (currentNumber == 0 ||
            number < currentNumber) {
          currentNumber = number;
        }
      }

      if (status == 'waiting') {
        waitingCount++;

        if (number < ticketNumber) {
          peopleBefore++;
        }
      }
    }

    return {
      'ticket': ticket,
      'current_number': currentNumber,
      'people_before': peopleBefore,
      'waiting_count': waitingCount,
    };
  }

  // =========================================================
  // CUSTOMER REALTIME
  // =========================================================

  Stream<Map<String, dynamic>?> watchCustomerTicket(
    String ticketId,
  ) {
    return _supabase
        .from('queue_tickets')
        .stream(
          primaryKey: ['id'],
        )
        .eq('id', ticketId)
        .map(
          (rows) {
            if (rows.isEmpty) {
              return null;
            }

            return Map<String, dynamic>.from(
              rows.first,
            );
          },
        );
  }

  // =========================================================
  // BARBER QUEUE
  // =========================================================

  Stream<List<Map<String, dynamic>>> watchQueue(
    String barberId,
  ) {
    return _supabase
        .from('queue_tickets')
        .stream(
          primaryKey: ['id'],
        )
        .eq('barber_id', barberId)
        .map(
          (rows) {
            final list = rows
                .map(
                  (row) => Map<String, dynamic>.from(row),
                )
                .toList();

            list.sort(
              (a, b) {
                final aDate =
                    a['queue_date']?.toString() ?? '';

                final bDate =
                    b['queue_date']?.toString() ?? '';

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

                return aNumber.compareTo(bNumber);
              },
            );

            return list;
          },
        );
  }

  // =========================================================
  // CURRENT SERVING
  // =========================================================

  Future<Map<String, dynamic>?> getCurrentServingTicket(
    String barberId,
  ) async {
    try {
      final today = _todayDate();

      final response = await _supabase
          .from('queue_tickets')
          .select()
          .eq('barber_id', barberId)
          .eq('queue_date', today)
          .eq('status', 'serving')
          .order('ticket_number')
          .limit(1);

      if (response.isEmpty) {
        return null;
      }

      return Map<String, dynamic>.from(
        response.first,
      );
    } catch (e) {
      debugPrint(
        'GET CURRENT SERVING ERROR: $e',
      );
      rethrow;
    }
  }

  Stream<Map<String, dynamic>?>
      watchCurrentServingTicket(
    String barberId,
  ) {
    return watchQueue(barberId).map(
      (rows) {
        final today = _todayDate();

        final serving = rows.where(
          (row) {
            return row['queue_date']?.toString() == today &&
                row['status']?.toString() == 'serving';
          },
        );

        if (serving.isEmpty) {
          return null;
        }

        return Map<String, dynamic>.from(
          serving.first,
        );
      },
    );
  }

  // =========================================================
  // NEXT CUSTOMER
  // =========================================================

  Future<Map<String, dynamic>> nextQueueTicket(
    String barberId,
  ) async {
    try {
      if (barberId.isEmpty) {
        throw Exception('BARBER_ID_NOT_FOUND');
      }

      final response = await _supabase.rpc(
        'next_queue_ticket',
        params: {
          'p_barber_id': barberId,
        },
      );

      debugPrint(
        'NEXT QUEUE RESPONSE: $response',
      );

      if (response is Map) {
        return Map<String, dynamic>.from(
          response,
        );
      }

      if (response is List &&
          response.isNotEmpty &&
          response.first is Map) {
        return Map<String, dynamic>.from(
          response.first,
        );
      }

      return {
        'message': 'NO_MORE_CUSTOMERS',
      };
    } catch (e) {
      debugPrint(
        'NEXT QUEUE ERROR: $e',
      );
      rethrow;
    }
  }

  // =========================================================
  // COMPLETE TICKET
  // =========================================================

  Future<void> completeTicket(
    String ticketId,
  ) async {
    try {
      await _supabase
          .from('queue_tickets')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now()
                .toUtc()
                .toIso8601String(),
          })
          .eq('id', ticketId);
    } catch (e) {
      debugPrint(
        'COMPLETE TICKET ERROR: $e',
      );
      rethrow;
    }
  }

  // =========================================================
  // DELETE TICKET
  // =========================================================

  Future<void> deleteTicket(
    String ticketId,
  ) async {
    try {
      await _supabase
          .from('queue_tickets')
          .delete()
          .eq('id', ticketId);
    } catch (e) {
      debugPrint(
        'DELETE TICKET ERROR: $e',
      );
      rethrow;
    }
  }

  // =========================================================
  // CANCEL
  // =========================================================

  Future<void> cancelTicket(
    String ticketId,
  ) async {
    try {
      await _supabase
          .from('queue_tickets')
          .update({
            'status': 'cancelled',
          })
          .eq('id', ticketId);
    } catch (e) {
      debugPrint(
        'CANCEL TICKET ERROR: $e',
      );
      rethrow;
    }
  }

  // =========================================================
  // LAST SERVED
  // =========================================================

  Future<int?> getLastServedNumber(
    String barberId,
  ) async {
    try {
      final response = await _supabase
          .from('queue_tickets')
          .select('ticket_number')
          .eq('barber_id', barberId)
          .eq('status', 'completed')
          .order(
            'ticket_number',
            ascending: false,
          )
          .limit(1);

      if (response.isEmpty) {
        return null;
      }

      return int.tryParse(
        response.first['ticket_number']?.toString() ?? '',
      );
    } catch (e) {
      debugPrint(
        'GET LAST SERVED ERROR: $e',
      );
      return null;
    }
  }

  // =========================================================
  // NOTIFICATION
  // =========================================================

  Future<void> sendQueueNotification({
    required String ticketId,
    required String type,
  }) async {
    try {
      await _supabase.functions.invoke(
        'send-queue-notification',
        body: {
          'ticket_id': ticketId,
          'type': type,
        },
      );
    } catch (e) {
      debugPrint(
        'SEND NOTIFICATION ERROR: $e',
      );
    }
  }

  // =========================================================
  // DATE
  // =========================================================

  String _todayDate() {
    final now = DateTime.now();

    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}