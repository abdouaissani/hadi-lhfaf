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
  // BARBER / SHOP
  // =========================================================

  Future<String?> getSingleBarber() async {
    try {
      final response = await _supabase
          .from('barbers')
          .select()
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return response['id']?.toString();
    } catch (e) {
      debugPrint('GET SINGLE BARBER ERROR: $e');
      rethrow;
    }
  }

  // =========================================================
  // ANNOUNCEMENTS - CUSTOMER
  // =========================================================

  Future<List<Map<String, dynamic>>> getActiveAnnouncements(
    String barberId,
  ) async {
    try {
      final response = await _supabase
          .from('announcements')
          .select()
          .eq('barber_id', barberId)
          .eq('is_active', true)
          .order(
            'created_at',
            ascending: false,
          );

      return (response as List)
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    } catch (e) {
      debugPrint('GET ACTIVE ANNOUNCEMENTS ERROR: $e');
      rethrow;
    }
  }

  // =========================================================
  // ANNOUNCEMENTS - ADMIN
  // =========================================================

  Future<List<Map<String, dynamic>>> getAllAnnouncements(
    String barberId,
  ) async {
    try {
      final response = await _supabase
          .from('announcements')
          .select()
          .eq('barber_id', barberId)
          .order(
            'created_at',
            ascending: false,
          );

      return (response as List)
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    } catch (e) {
      debugPrint('GET ALL ANNOUNCEMENTS ERROR: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addAnnouncement({
    required String barberId,
    required String title,
    required String content,
  }) async {
    try {
      final response = await _supabase
          .from('announcements')
          .insert({
            'barber_id': barberId,
            'title': title.trim(),
            'content': content.trim(),
            'is_active': true,
          })
          .select()
          .single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('ADD ANNOUNCEMENT ERROR: $e');
      rethrow;
    }
  }

  Future<void> updateAnnouncement({
    required String announcementId,
    required String title,
    required String content,
  }) async {
    try {
      await _supabase
          .from('announcements')
          .update({
            'title': title.trim(),
            'content': content.trim(),
          })
          .eq(
            'id',
            announcementId,
          );
    } catch (e) {
      debugPrint('UPDATE ANNOUNCEMENT ERROR: $e');
      rethrow;
    }
  }

  Future<void> setAnnouncementActive({
    required String announcementId,
    required bool active,
  }) async {
    try {
      await _supabase
          .from('announcements')
          .update({
            'is_active': active,
          })
          .eq(
            'id',
            announcementId,
          );
    } catch (e) {
      debugPrint('SET ANNOUNCEMENT ACTIVE ERROR: $e');
      rethrow;
    }
  }

  Future<void> deleteAnnouncement(
    String announcementId,
  ) async {
    try {
      await _supabase
          .from('announcements')
          .delete()
          .eq(
            'id',
            announcementId,
          );
    } catch (e) {
      debugPrint('DELETE ANNOUNCEMENT ERROR: $e');
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

      return (response as List)
          .map(
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

  Future<List<Map<String, dynamic>>> getAllServices(
    String barberId,
  ) async {
    try {
      final response = await _supabase
          .from('services')
          .select()
          .eq('barber_id', barberId)
          .order('name');

      return (response as List)
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    } catch (e) {
      debugPrint('GET ALL SERVICES ERROR: $e');
      rethrow;
    }
  }

  Future<ServiceModel> addService({
    required String barberId,
    required String name,
    required double price,
  }) async {
    try {
      final response = await _supabase
          .from('services')
          .insert({
            'barber_id': barberId,
            'name': name.trim(),
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

  Future<void> updateService({
    required String serviceId,
    required String name,
    required double price,
  }) async {
    try {
      await _supabase
          .from('services')
          .update({
            'name': name.trim(),
            'price': price,
          })
          .eq(
            'id',
            serviceId,
          );
    } catch (e) {
      debugPrint('UPDATE SERVICE ERROR: $e');
      rethrow;
    }
  }

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
          .eq(
            'id',
            serviceId,
          );
    } catch (e) {
      debugPrint('SET SERVICE ACTIVE ERROR: $e');
      rethrow;
    }
  }

  Future<void> deleteService(
    String serviceId,
  ) async {
    try {
      await _supabase
          .from('services')
          .delete()
          .eq(
            'id',
            serviceId,
          );
    } catch (e) {
      debugPrint('DELETE SERVICE ERROR: $e');
      rethrow;
    }
  }

  // =========================================================
  // BARBER LOCATION
  // =========================================================

  Future<Map<String, dynamic>?> getBarberLocation(
    String barberId,
  ) async {
    try {
      final response = await _supabase
          .from('barbers')
          .select('latitude, longitude')
          .eq(
            'id',
            barberId,
          )
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('GET BARBER LOCATION ERROR: $e');
      rethrow;
    }
  }

  Future<void> updateBarberLocation({
    required String barberId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _supabase
          .from('barbers')
          .update({
            'latitude': latitude,
            'longitude': longitude,
          })
          .eq(
            'id',
            barberId,
          );
    } catch (e) {
      debugPrint('UPDATE BARBER LOCATION ERROR: $e');
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
      final response = await _supabase
          .from('barbers')
          .select('queue_enabled')
          .eq(
            'id',
            barberId,
          )
          .maybeSingle();

      if (response == null) {
        return true;
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
      await _supabase
          .from('barbers')
          .update({
            'queue_enabled': enabled,
          })
          .eq(
            'id',
            barberId,
          );
    } catch (e) {
      debugPrint('SET QUEUE STATUS ERROR: $e');
      rethrow;
    }
  }

  // =========================================================
  // CREATE BOOKING
  // =========================================================

  Future<Map<String, dynamic>> createBooking({
    required String? barberId,
    required String serviceId,
    required String name,
    required String phone,
  }) async {
    try {
      final actualBarberId = barberId;

      if (actualBarberId == null ||
          actualBarberId.isEmpty) {
        throw Exception('BARBER_ID_NOT_FOUND');
      }

      debugPrint('==============================');
      debugPrint('CREATE BOOKING');
      debugPrint('BARBER: $actualBarberId');
      debugPrint('SERVICE: $serviceId');
      debugPrint('NAME: ${name.trim()}');
      debugPrint('PHONE: ${phone.trim()}');
      debugPrint('==============================');

      final response = await _supabase.rpc(
        'create_queue_ticket',
        params: {
          'p_barber_id': actualBarberId,
          'p_service_id': serviceId,
          'p_customer_name': name.trim(),
          'p_phone': phone.trim(),
        },
      );

      debugPrint(
        'CREATE BOOKING RESPONSE: $response',
      );

      Map<String, dynamic>? result;

      if (response is Map) {
        result = Map<String, dynamic>.from(response);
      } else if (response is List &&
          response.isNotEmpty &&
          response.first is Map) {
        result = Map<String, dynamic>.from(
          response.first,
        );
      }

      if (result == null) {
        throw Exception('BOOKING_FAILED');
      }

      final ticketId = result['id']?.toString();

      if (ticketId == null ||
          ticketId.isEmpty ||
          ticketId == 'null') {
        throw Exception('TICKET_ID_NOT_FOUND');
      }

      try {
        final token =
            await NotificationService.instance.getToken();

        if (token != null && token.isNotEmpty) {
          await saveFcmToken(
            ticketId: ticketId,
            token: token,
          );

          result['fcm_token'] = token;
        }
      } catch (e) {
        debugPrint(
          'FCM TOKEN SAVE ERROR: $e',
        );
      }

      return result;
    } on PostgrestException catch (e) {
      debugPrint('POSTGREST BOOKING ERROR');
      debugPrint('MESSAGE: ${e.message}');
      debugPrint('CODE: ${e.code}');
      debugPrint('DETAILS: ${e.details}');
      debugPrint('HINT: ${e.hint}');

      if (e.message.contains('QUEUE_CLOSED')) {
        throw Exception('QUEUE_CLOSED');
      }

      if (e.message.contains('QUEUE_FULL')) {
        throw Exception('QUEUE_FULL');
      }

      if (e.message.contains('INVALID_SERVICE')) {
        throw Exception('INVALID_SERVICE');
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
  // SAVE FCM TOKEN
  // =========================================================

  Future<void> saveFcmToken({
    required String ticketId,
    required String token,
  }) async {
    try {
      await _supabase
          .from('queue_tickets')
          .update({
            'fcm_token': token,
          })
          .eq(
            'id',
            ticketId,
          );

      debugPrint(
        'FCM TOKEN SAVED FOR TICKET: $ticketId',
      );
    } catch (e) {
      debugPrint(
        'SAVE FCM TOKEN ERROR: $e',
      );
      rethrow;
    }
  }

  // =========================================================
  // CUSTOMER QUEUE INFO
  // =========================================================

  Future<Map<String, dynamic>?> getCustomerQueueInfo(
    String ticketId,
  ) async {
    try {
      final ticketResponse = await _supabase
          .from('queue_tickets')
          .select()
          .eq(
            'id',
            ticketId,
          )
          .maybeSingle();

      if (ticketResponse == null) {
        return null;
      }

      final ticket =
          Map<String, dynamic>.from(ticketResponse);

      final barberId =
          ticket['barber_id']?.toString();

      final ticketNumber =
          int.tryParse(
                ticket['ticket_number']?.toString() ?? '',
              ) ??
              0;

      final queueDate =
          ticket['queue_date']?.toString();

      int waitingAhead = 0;

      Map<String, dynamic>? currentServing;

      if (barberId != null &&
          barberId.isNotEmpty &&
          queueDate != null &&
          queueDate.isNotEmpty) {
        final ahead = await _supabase
            .from('queue_tickets')
            .select('id')
            .eq(
              'barber_id',
              barberId,
            )
            .eq(
              'queue_date',
              queueDate,
            )
            .eq(
              'status',
              'waiting',
            )
            .lt(
              'ticket_number',
              ticketNumber,
            );

        waitingAhead = (ahead as List).length;

        final serving = await _supabase
            .from('queue_tickets')
            .select()
            .eq(
              'barber_id',
              barberId,
            )
            .eq(
              'queue_date',
              queueDate,
            )
            .eq(
              'status',
              'serving',
            )
            .order(
              'ticket_number',
            )
            .limit(1)
            .maybeSingle();

        if (serving != null) {
          currentServing =
              Map<String, dynamic>.from(serving);
        }
      }

      return {
        ...ticket,
        'waiting_ahead': waitingAhead,
        'position': waitingAhead + 1,
        'current_serving': currentServing,
      };
    } catch (e) {
      debugPrint(
        'GET CUSTOMER QUEUE INFO ERROR: $e',
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
          .eq(
            'id',
            ticketId,
          )
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint(
        'GET TICKET ERROR: $e',
      );
      rethrow;
    }
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
        .eq(
          'id',
          ticketId,
        )
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
  // BARBER QUEUE REALTIME
  // =========================================================

  Stream<List<Map<String, dynamic>>> watchQueue(
    String barberId,
  ) {
    return _supabase
        .from('queue_tickets')
        .stream(
          primaryKey: ['id'],
        )
        .eq(
          'barber_id',
          barberId,
        )
        .order(
          'ticket_number',
        )
        .map(
          (rows) {
            return rows
                .map(
                  (row) =>
                      Map<String, dynamic>.from(row),
                )
                .toList();
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
        return Map<String, dynamic>.from(response);
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
  // SEND NOTIFICATION
  // =========================================================

  Future<void> sendQueueNotification({
    required String ticketId,
    required String type,
  }) async {
    try {
      final response =
          await _supabase.functions.invoke(
        'send-queue-notification',
        body: {
          'ticket_id': ticketId,
          'type': type,
        },
      );

      debugPrint(
        'NOTIFICATION RESPONSE: ${response.data}',
      );
    } catch (e) {
      debugPrint(
        'SEND NOTIFICATION ERROR: $e',
      );
      rethrow;
    }
  }

  // =========================================================
  // CANCEL TICKET
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
          .eq(
            'id',
            ticketId,
          );
    } catch (e) {
      debugPrint(
        'CANCEL TICKET ERROR: $e',
      );
      rethrow;
    }
  }

  // =========================================================
  // COMPLETE CURRENT TICKET
  // =========================================================
  //
  // هنا لا نحذف مباشرة.
  //
  // هذه الدالة تستعمل إذا أردت فقط تغيير الحالة.
  // زر "إكمال وحذف" في لوحة الحلاق سيستعمل
  // deleteTicket() الموجودة في الأسفل.
  // =========================================================

  Future<void> completeTicket(
    String ticketId,
  ) async {
    try {
      await _supabase
          .from('queue_tickets')
          .update({
            'status': 'completed',
            'completed_at':
                DateTime.now()
                    .toUtc()
                    .toIso8601String(),
          })
          .eq(
            'id',
            ticketId,
          );

      debugPrint(
        'TICKET COMPLETED: $ticketId',
      );
    } catch (e) {
      debugPrint(
        'COMPLETE TICKET ERROR: $e',
      );
      rethrow;
    }
  }

  // =========================================================
  // DELETE TICKET PERMANENTLY
  // =========================================================
  //
  // هذه هي الدالة المهمة للحجوزات القديمة.
  //
  // بعد الضغط على "إكمال وحذف":
  // DELETE FROM queue_tickets WHERE id = ...
  //
  // وبالتالي عندما نعيد فتح Dashboard لن يرجع الحجز.
  // =========================================================

  Future<void> deleteTicket(
    String ticketId,
  ) async {
    try {
      final response = await _supabase
          .from('queue_tickets')
          .delete()
          .eq(
            'id',
            ticketId,
          )
          .select('id');

      final deletedRows = response as List;

      if (deletedRows.isEmpty) {
        throw Exception(
          'TICKET_NOT_DELETED_OR_NOT_FOUND',
        );
      }

      debugPrint(
        '================================',
      );
      debugPrint(
        'TICKET DELETED PERMANENTLY',
      );
      debugPrint(
        'TICKET ID: $ticketId',
      );
      debugPrint(
        '================================',
      );
    } catch (e) {
      debugPrint(
        'DELETE TICKET ERROR: $e',
      );
      rethrow;
    }
  }
}