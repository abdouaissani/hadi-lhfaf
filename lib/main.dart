import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'screens/booking_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/my_bookings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // =========================================================
  // FIREBASE
  // =========================================================

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  // =========================================================
  // SUPABASE
  // =========================================================

  await Supabase.initialize(
    url: 'https://oisuvezynaiquylddoni.supabase.co',
    publishableKey:
        'sb_publishable_L8p9C6nP4f6Nplsac7WcpA_5pFSb9jC',
  );

  // =========================================================
  // NOTIFICATIONS
  // =========================================================

  await NotificationService.instance.initialize();

  // =========================================================
  // APP
  // =========================================================

  runApp(
    const MyApp(),
  );
}

// ===========================================================
// APP
// ===========================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hadi Lhafaf',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0D1726),
        scaffoldBackgroundColor: const Color(0xFFF8F9FB),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(16),
            ),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(16),
            ),
            borderSide: BorderSide(
              color: Color(0xFFE2E5EA),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(16),
            ),
            borderSide: BorderSide(
              color: Color(0xFF0D1726),
              width: 1.5,
            ),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ===========================================================
// HOME
// ===========================================================

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color navy = Color(0xFF0D1726);
    const Color gold = Color(0xFFD7A84B);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text(
            'Hadi Lhafaf',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: navy,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'لوحة إدارة الحلاق',
              icon: const Icon(
                Icons.admin_panel_settings_outlined,
                color: navy,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const AdminLoginScreen(),
                  ),
                );
              },
            ),
          ],
        ),

        // =====================================================
        // BODY
        // =====================================================

        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 30),

                // =================================================
                // LOGO
                // =================================================

                Center(
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: navy,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.12,
                          ),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.content_cut,
                      color: gold,
                      size: 58,
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                const Text(
                  'Hadi Lhafaf',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: navy,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'احجز دورك عند الحلاق بسهولة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 35),

                // =================================================
                // BOOK
                // =================================================

                SizedBox(
                  height: 62,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const BookingScreen(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.confirmation_number_outlined,
                      size: 27,
                    ),
                    label: const Text(
                      'دخول للحجز',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: navy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // =================================================
                // MY BOOKINGS
                // =================================================

                SizedBox(
                  height: 62,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const MyBookingsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.receipt_long_outlined,
                      size: 27,
                    ),
                    label: const Text(
                      'حجوزاتي',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: navy,
                      side: const BorderSide(
                        color: navy,
                        width: 1.3,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 35),

                // =================================================
                // INFO
                // =================================================

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.grey.shade200,
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: navy,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'يمكنك الرجوع إلى "حجوزاتي" في أي وقت لمتابعة دورك.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                const Text(
                  '✂️ احجز دورك وانتظر دورك بكل راحة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
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
}