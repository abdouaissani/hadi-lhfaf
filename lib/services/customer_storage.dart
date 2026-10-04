import 'package:shared_preferences/shared_preferences.dart';

class CustomerStorage {
  static const String _ticketIdsKey =
      'customer_ticket_ids';

  static const String _tokenKey =
      'customer_token';

  static const String _savedAtPrefix =
      'ticket_saved_at_';

  static const Duration _ticketLifetime =
      Duration(hours: 48);

  // ============================================================
  // SAVE TICKET
  // ============================================================

  static Future<void> saveTicketId(
    String ticketId, {
    DateTime? createdAt,
  }) async {
    final id = ticketId.trim();

    if (id.isEmpty) return;

    final prefs =
        await SharedPreferences.getInstance();

    final ids = List<String>.from(
      prefs.getStringList(
            _ticketIdsKey,
          ) ??
          <String>[],
    );

    // إزالة التكرار.
    ids.remove(id);

    // الحجز الجديد في البداية.
    ids.insert(0, id);

    await prefs.setStringList(
      _ticketIdsKey,
      ids,
    );

    /*
      نستخدم created_at من Supabase إذا كان
      متوفرًا.

      إذا لم يكن متوفرًا، نستعمل وقت الحفظ
      في الهاتف.
    */

    final date =
        createdAt ?? DateTime.now();

    await prefs.setInt(
      '$_savedAtPrefix$id',
      date.millisecondsSinceEpoch,
    );
  }

  // ============================================================
  // GET VALID TICKETS
  // ============================================================

  static Future<List<String>>
      getTicketIds() async {
    final prefs =
        await SharedPreferences.getInstance();

    final ids = List<String>.from(
      prefs.getStringList(
            _ticketIdsKey,
          ) ??
          <String>[],
    );

    if (ids.isEmpty) {
      return <String>[];
    }

    final now = DateTime.now();

    final validIds = <String>[];
    final expiredIds = <String>[];

    for (final id in ids) {
      final savedAtMillis =
          prefs.getInt(
        '$_savedAtPrefix$id',
      );

      /*
        إذا لم يوجد تاريخ محفوظ،
        لا نحذف الحجز تلقائيًا.
      */

      if (savedAtMillis == null) {
        validIds.add(id);
        continue;
      }

      final savedAt =
          DateTime.fromMillisecondsSinceEpoch(
        savedAtMillis,
      );

      final age =
          now.difference(savedAt);

      if (age < _ticketLifetime) {
        validIds.add(id);
      } else {
        expiredIds.add(id);
      }
    }

    // حذف تواريخ الحجوزات المنتهية.
    for (final id in expiredIds) {
      await prefs.remove(
        '$_savedAtPrefix$id',
      );
    }

    // تحديث القائمة.
    if (validIds.length != ids.length) {
      await prefs.setStringList(
        _ticketIdsKey,
        validIds,
      );
    }

    return validIds;
  }

  // ============================================================
  // GET ONE VALID TICKET
  // ============================================================

  static Future<String?>
      getTicketId() async {
    final ids =
        await getTicketIds();

    if (ids.isEmpty) {
      return null;
    }

    return ids.first;
  }

  // ============================================================
  // REMOVE ONE TICKET
  // ============================================================

  static Future<void>
      removeTicketId(
    String ticketId,
  ) async {
    final id = ticketId.trim();

    if (id.isEmpty) return;

    final prefs =
        await SharedPreferences.getInstance();

    final ids = List<String>.from(
      prefs.getStringList(
            _ticketIdsKey,
          ) ??
          <String>[],
    );

    ids.remove(id);

    await prefs.setStringList(
      _ticketIdsKey,
      ids,
    );

    await prefs.remove(
      '$_savedAtPrefix$id',
    );
  }

  // ============================================================
  // CLEAR ALL TICKETS
  // ============================================================

  static Future<void>
      clearTickets() async {
    final prefs =
        await SharedPreferences.getInstance();

    final ids = List<String>.from(
      prefs.getStringList(
            _ticketIdsKey,
          ) ??
          <String>[],
    );

    for (final id in ids) {
      await prefs.remove(
        '$_savedAtPrefix$id',
      );
    }

    await prefs.remove(
      _ticketIdsKey,
    );
  }

  // ============================================================
  // SAVE CUSTOMER TOKEN
  // ============================================================

  static Future<void> saveToken(
    String token,
  ) async {
    final value = token.trim();

    if (value.isEmpty) return;

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      _tokenKey,
      value,
    );
  }

  // ============================================================
  // GET CUSTOMER TOKEN
  // ============================================================

  static Future<String?>
      getToken() async {
    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getString(
      _tokenKey,
    );
  }

  // ============================================================
  // CLEAR CUSTOMER TOKEN
  // ============================================================

  static Future<void>
      clearToken() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove(
      _tokenKey,
    );
  }

  // ============================================================
  // CLEAR EVERYTHING
  // ============================================================

  static Future<void>
      clearAll() async {
    await clearTickets();
    await clearToken();
  }
}