import 'package:shared_preferences/shared_preferences.dart';

class CustomerStorage {
  static const String _ticketIdsKey = 'customer_ticket_ids';

  // =========================================================
  // SAVE TICKET
  // =========================================================

  static Future<void> saveTicketId(
    String ticketId,
  ) async {
    if (ticketId.trim().isEmpty) {
      return;
    }

    final prefs =
        await SharedPreferences.getInstance();

    final List<String> currentIds =
        prefs.getStringList(
              _ticketIdsKey,
            ) ??
            [];

    final String cleanId =
        ticketId.trim();

    // لا نكرر نفس الحجز
    if (!currentIds.contains(cleanId)) {
      currentIds.insert(0, cleanId);

      await prefs.setStringList(
        _ticketIdsKey,
        currentIds,
      );
    }
  }

  // =========================================================
  // GET ALL TICKETS
  // =========================================================

  static Future<List<String>> getTicketIds() async {
    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getStringList(
          _ticketIdsKey,
        ) ??
        [];
  }

  // =========================================================
  // REMOVE ONE TICKET
  // =========================================================

  static Future<void> removeTicketId(
    String ticketId,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    final List<String> currentIds =
        prefs.getStringList(
              _ticketIdsKey,
            ) ??
            [];

    currentIds.remove(ticketId);

    await prefs.setStringList(
      _ticketIdsKey,
      currentIds,
    );
  }

  // =========================================================
  // CLEAR ALL
  // =========================================================

  static Future<void> clearTickets() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove(
      _ticketIdsKey,
    );
  }

  // =========================================================
  // OLD TOKEN SUPPORT
  // =========================================================

  static const String _tokenKey =
      'customer_token';

  static Future<void> saveToken(
    String token,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      _tokenKey,
      token,
    );
  }

  static Future<String?> getToken() async {
    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getString(
      _tokenKey,
    );
  }

  static Future<void> clearToken() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove(
      _tokenKey,
    );
  }
}