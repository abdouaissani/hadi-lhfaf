import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';

import 'screens/booking_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/my_bookings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // =========================================================
  // ADMOB
  // =========================================================

  await MobileAds.instance.initialize();

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

  runApp(const MyApp());
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
      title: 'LHadi Coiffure',

      theme: ThemeData(
        useMaterial3: true,

        colorSchemeSeed: const Color(0xFF0D1726),

        scaffoldBackgroundColor:
            const Color(0xFFF8F9FB),

        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),

        inputDecorationTheme:
            InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFFE2E5EA),
            ),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFF0D1726),
              width: 1.5,
            ),
          ),
        ),
      ),

      home: HomeScreen(),
    );
  }
}

// ===========================================================
// ADMOB BANNER
// ===========================================================

class AdMobBanner extends StatefulWidget {
  const AdMobBanner({super.key});

  @override
  State<AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<AdMobBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  static const String _bannerAdUnitId =
      'ca-app-pub-8672503633336720/4472508689';

  @override
  void initState() {
    super.initState();

    _loadBanner();
  }

  void _loadBanner() {
    final BannerAd banner = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),

      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }

          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
          });
        },

        onAdFailedToLoad: (
          Ad ad,
          LoadAdError error,
        ) {
          ad.dispose();

          debugPrint(
            'AdMob Banner failed to load: $error',
          );
        },

        onAdOpened: (Ad ad) {
          debugPrint(
            'AdMob Banner opened',
          );
        },

        onAdClosed: (Ad ad) {
          debugPrint(
            'AdMob Banner closed',
          );
        },

        onAdImpression: (Ad ad) {
          debugPrint(
            'AdMob Banner impression',
          );
        },
      ),
    );

    banner.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Center(
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(
          ad: _bannerAd!,
        ),
      ),
    );
  }
}

// ===========================================================
// HOME
// ===========================================================

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});

  static const Color navy =
      Color(0xFF0D1726);

  static const Color gold =
      Color(0xFFD7A84B);

  final SupabaseService _service =
      SupabaseService();

  // =========================================================
  // LOAD ANNOUNCEMENTS
  // =========================================================

  Future<List<Map<String, dynamic>>>
      _loadAnnouncements() async {
    final barberId =
        await _service.getSingleBarber();

    if (barberId == null ||
        barberId.trim().isEmpty) {
      return [];
    }

    return await _service
        .getActiveAnnouncements(barberId);
  }

  // =========================================================
  // LOAD BARBER LOCATION
  // =========================================================

  Future<LatLng?> _loadBarberLocation() async {
    try {
      final barberId =
          await _service.getSingleBarber();

      if (barberId == null ||
          barberId.trim().isEmpty) {
        return null;
      }

      final location =
          await _service.getBarberLocation(
        barberId,
      );

      if (location == null) {
        return null;
      }

      final latitude =
          _toDouble(location['latitude']);

      final longitude =
          _toDouble(location['longitude']);

      if (latitude == null ||
          longitude == null) {
        return null;
      }

      return LatLng(
        latitude,
        longitude,
      );
    } catch (e) {
      debugPrint(
        'BARBER LOCATION ERROR: $e',
      );

      return null;
    }
  }

  double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  // =========================================================
  // LOCATION
  // =========================================================

  void _showLocation(
    BuildContext context,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (context) {
        return Directionality(
          textDirection:
              TextDirection.rtl,
          child: SafeArea(
            child: Container(
              height:
                  MediaQuery.of(context)
                          .size
                          .height *
                      0.82,
              decoration:
                  const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child:
                  FutureBuilder<LatLng?>(
                future:
                    _loadBarberLocation(),
                builder: (
                  context,
                  snapshot,
                ) {
                  if (snapshot
                          .connectionState ==
                      ConnectionState.waiting) {
                    return _locationLoading();
                  }

                  if (snapshot.hasError ||
                      snapshot.data == null) {
                    return _locationNotAvailable(
                      context,
                    );
                  }

                  return _locationContent(
                    context,
                    snapshot.data!,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // LOCATION LOADING
  // =========================================================

  Widget _locationLoading() {
    return Column(
      children: [
        const SizedBox(height: 12),
        _sheetHandle(),
        const SizedBox(height: 25),
        const Icon(
          Icons.location_on_outlined,
          size: 55,
          color: navy,
        ),
        const SizedBox(height: 15),
        const Text(
          'موقع المحل',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: navy,
          ),
        ),
        const SizedBox(height: 30),
        const CircularProgressIndicator(
          color: navy,
        ),
        const SizedBox(height: 18),
        const Text(
          'جاري تحميل موقع المحل...',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // LOCATION NOT AVAILABLE
  // =========================================================

  Widget _locationNotAvailable(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        30,
      ),
      child: Column(
        children: [
          _sheetHandle(),
          const SizedBox(height: 25),
          Container(
            width: 75,
            height: 75,
            decoration:
                BoxDecoration(
              color:
                  const Color(0xFFF3F5F8),
              borderRadius:
                  BorderRadius.circular(
                22,
              ),
            ),
            child: const Icon(
              Icons.location_off_outlined,
              size: 40,
              color: navy,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'موقع المحل',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: navy,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'موقع المحل غير محدد حاليًا.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 15,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style:
                  FilledButton.styleFrom(
                backgroundColor: navy,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
              ),
              child: const Text(
                'إغلاق',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // LOCATION CONTENT
  // =========================================================

  Widget _locationContent(
    BuildContext context,
    LatLng location,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        20,
      ),
      child: Column(
        children: [
          _sheetHandle(),
          const SizedBox(height: 15),
          const Row(
            children: [
              Icon(
                Icons.location_on,
                color: navy,
                size: 30,
              ),
              SizedBox(width: 10),
              Text(
                'موقع المحل',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight:
                      FontWeight.w900,
                  color: navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(
                24,
              ),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter:
                      location,
                  initialZoom: 16,
                  interactionOptions:
                      const InteractionOptions(
                    flags:
                        InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName:
                        'hadi_lhafaf',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: location,
                        width: 70,
                        height: 70,
                        child: const Icon(
                          Icons.location_on,
                          size: 55,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(14),
            decoration:
                BoxDecoration(
              color:
                  const Color(0xFFF8F9FB),
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  color: navy,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${location.latitude.toStringAsFixed(6)}, '
                    '${location.longitude.toStringAsFixed(6)}',
                    textDirection:
                        TextDirection.ltr,
                    style:
                        const TextStyle(
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w700,
                      color: navy,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        BarberMapScreen(
                      location: location,
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.map_outlined,
              ),
              label: const Text(
                'عرض الخريطة كاملة',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              style:
                  FilledButton.styleFrom(
                backgroundColor: navy,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SHEET HANDLE
  // =========================================================

  Widget _sheetHandle() {
    return Center(
      child: Container(
        width: 45,
        height: 5,
        decoration:
            BoxDecoration(
          color:
              Colors.grey.shade300,
          borderRadius:
              BorderRadius.circular(
            10,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // ANNOUNCEMENTS
  // =========================================================

  void _showAnnouncements(
    BuildContext context,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (context) {
        return Directionality(
          textDirection:
              TextDirection.rtl,
          child: SafeArea(
            child: Container(
              constraints:
                  BoxConstraints(
                maxHeight:
                    MediaQuery.of(context)
                            .size
                            .height *
                        0.85,
              ),
              decoration:
                  const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: FutureBuilder<
                  List<Map<String, dynamic>>>(
                future:
                    _loadAnnouncements(),
                builder: (
                  context,
                  snapshot,
                ) {
                  if (snapshot
                          .connectionState ==
                      ConnectionState.waiting) {
                    return _announcementLoading();
                  }

                  if (snapshot.hasError) {
                    return _announcementError(
                      context,
                    );
                  }

                  final announcements =
                      snapshot.data ?? [];

                  return _announcementContent(
                    context,
                    announcements,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // ANNOUNCEMENT LOADING
  // =========================================================

  Widget _announcementLoading() {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        15,
        20,
        30,
      ),
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          _sheetHandle(),
          const SizedBox(height: 20),
          const Row(
            children: [
              Icon(
                Icons.campaign_outlined,
                color: gold,
                size: 30,
              ),
              SizedBox(width: 10),
              Text(
                'الإعلانات',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight:
                      FontWeight.w900,
                  color: navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 35),
          const CircularProgressIndicator(
            color: navy,
          ),
          const SizedBox(height: 20),
          const Text(
            'جاري تحميل الإعلانات...',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // =========================================================
  // ANNOUNCEMENT ERROR
  // =========================================================

  Widget _announcementError(
    BuildContext context,
  ) {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        15,
        20,
        30,
      ),
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          _sheetHandle(),
          const SizedBox(height: 25),
          const Icon(
            Icons.error_outline,
            size: 55,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 15),
          const Text(
            'تعذر تحميل الإعلانات',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.w900,
              color: navy,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'حاول مرة أخرى من فضلك.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);

                _showAnnouncements(
                  context,
                );
              },
              style:
                  FilledButton.styleFrom(
                backgroundColor: navy,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
              ),
              child: const Text(
                'إعادة المحاولة',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ANNOUNCEMENT CONTENT
  // =========================================================

  Widget _announcementContent(
    BuildContext context,
    List<Map<String, dynamic>>
        announcements,
  ) {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        15,
        20,
        30,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          _sheetHandle(),
          const SizedBox(height: 20),
          const Row(
            children: [
              Icon(
                Icons.campaign_outlined,
                color: gold,
                size: 30,
              ),
              SizedBox(width: 10),
              Text(
                'الإعلانات',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight:
                      FontWeight.w900,
                  color: navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (announcements.isEmpty)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(20),
              decoration:
                  BoxDecoration(
                color:
                    const Color(0xFFF8F9FB),
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
                border: Border.all(
                  color:
                      Colors.grey.shade200,
                ),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons
                        .notifications_none_outlined,
                    size: 50,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'لا توجد إعلانات جديدة حالياً.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w700,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

          if (announcements.isNotEmpty)
            ...announcements.map(
              (announcement) {
                final title =
                    announcement['title']
                            ?.toString()
                            .trim() ??
                        '';

                final content =
                    announcement['content']
                            ?.toString()
                            .trim() ??
                        '';

                return Container(
                  width: double.infinity,
                  margin:
                      const EdgeInsets.only(
                    bottom: 12,
                  ),
                  padding:
                      const EdgeInsets.all(18),
                  decoration:
                      BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                    border: Border.all(
                      color:
                          Colors.grey.shade200,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(
                          alpha: 0.04,
                        ),
                        blurRadius: 12,
                        offset:
                            const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Container(
                            width: 45,
                            height: 45,
                            decoration:
                                BoxDecoration(
                              color:
                                  const Color(
                                0xFFF3F5F8,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                14,
                              ),
                            ),
                            child:
                                const Icon(
                              Icons
                                  .campaign_outlined,
                              color: navy,
                            ),
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Expanded(
                            child: Text(
                              title.isEmpty
                                  ? 'إعلان الحلاق'
                                  : title,
                              style:
                                  const TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.w900,
                                color: navy,
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (content.isNotEmpty)
                        const SizedBox(
                          height: 14,
                        ),

                      if (content.isNotEmpty)
                        Text(
                          content,
                          style:
                              const TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color:
                                Colors.black87,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 5),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style:
                  FilledButton.styleFrom(
                backgroundColor: navy,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
              ),
              child: const Text(
                'إغلاق',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // CONTACT
  // =========================================================

  void _showContact(
    BuildContext context,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (context) {
        return Directionality(
          textDirection:
              TextDirection.rtl,
          child: SafeArea(
            child: Container(
              constraints:
                  BoxConstraints(
                maxHeight:
                    MediaQuery.of(context)
                            .size
                            .height *
                        0.80,
              ),
              decoration:
                  const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child:
                  SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  15,
                  20,
                  30,
                ),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    _sheetHandle(),
                    const SizedBox(height: 20),
                    const Icon(
                      Icons
                          .phone_in_talk_outlined,
                      size: 55,
                      color: navy,
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'تواصل معنا',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight:
                            FontWeight.w900,
                        color: navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'للاستفسار أو التواصل مع الحلاق',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width:
                          double.infinity,
                      padding:
                          const EdgeInsets.all(
                        18,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFFF8F9FB,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          18,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .center,
                        children: [
                          Icon(
                            Icons.phone,
                            color: navy,
                          ),
                          SizedBox(width: 12),
                          Text(
                            '0667030731',
                            textDirection:
                                TextDirection.ltr,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight:
                                  FontWeight.w900,
                              color: navy,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width:
                          double.infinity,
                      height: 52,
                      child:
                          FilledButton(
                        onPressed: () {
                          Navigator.pop(
                            context,
                          );
                        },
                        style:
                            FilledButton
                                .styleFrom(
                          backgroundColor:
                              navy,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              16,
                            ),
                          ),
                        ),
                        child:
                            const Text(
                          'إغلاق',
                          style: TextStyle(
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    Widget featureCard({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      bool primary = false,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius:
              BorderRadius.circular(24),
          child: Ink(
            padding:
                const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: primary
                  ? gold
                  : const Color(0xFF111D2D),
              borderRadius:
                  BorderRadius.circular(24),
              border: Border.all(
                color: primary
                    ? gold.withValues(
                        alpha: 0.65,
                      )
                    : Colors.white.withValues(
                        alpha: 0.07,
                      ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(
                    alpha: 0.22,
                  ),
                  blurRadius: 20,
                  offset:
                      const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration:
                      BoxDecoration(
                    color: primary
                        ? Colors.black
                            .withValues(
                            alpha: 0.12,
                          )
                        : Colors.white
                            .withValues(
                            alpha: 0.06,
                          ),
                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: primary
                        ? navy
                        : gold,
                    size: 29,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: primary
                              ? navy
                              : Colors.white,
                          fontSize: 18,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: primary
                              ? navy.withValues(
                                  alpha: 0.70,
                                )
                              : Colors.white60,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons
                      .arrow_back_ios_new_rounded,
                  size: 17,
                  color: primary
                      ? navy
                      : Colors.white54,
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget miniAction({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: Material(
          color:
              const Color(0xFF111D2D),
          borderRadius:
              BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius:
                BorderRadius.circular(20),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                vertical: 15,
              ),
              child: Column(
                children: [
                  Icon(
                    icon,
                    color: gold,
                    size: 25,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    label,
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection:
          TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            const Color(0xFF07111E),

        appBar: AppBar(
          backgroundColor:
              const Color(0xFF07111E),
          surfaceTintColor:
              Colors.transparent,
          elevation: 0,
          titleSpacing: 20,

          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(0xFF111D2D),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                  border: Border.all(
                    color:
                        gold.withValues(
                      alpha: 0.35,
                    ),
                  ),
                ),
                child: const Icon(
                  Icons
                      .content_cut_rounded,
                  color: gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              const Text(
                'LHadi Coiffure',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ],
          ),

          actions: [
            IconButton(
              tooltip:
                  'لوحة إدارة الحلاق',
              icon: const Icon(
                Icons
                    .admin_panel_settings_outlined,
                color: Colors.white,
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
            const SizedBox(width: 7),
          ],
        ),

        body: SafeArea(
          child:
              SingleChildScrollView(
            physics:
                const BouncingScrollPhysics(),
            padding:
                const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              28,
            ),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,

              children: [
                // =====================================================
                // HEADER
                // =====================================================

                Container(
                  padding:
                      const EdgeInsets.fromLTRB(
                    22,
                    24,
                    22,
                    22,
                  ),
                  decoration:
                      BoxDecoration(
                    gradient:
                        const LinearGradient(
                      begin:
                          Alignment.topRight,
                      end:
                          Alignment.bottomLeft,
                      colors: [
                        Color(0xFF16263B),
                        Color(0xFF0D1828),
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      30,
                    ),
                    border: Border.all(
                      color:
                          Colors.white.withValues(
                        alpha: 0.08,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(
                          alpha: 0.25,
                        ),
                        blurRadius: 28,
                        offset:
                            const Offset(
                          0,
                          14,
                        ),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration:
                                BoxDecoration(
                              color: gold,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                22,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: gold
                                      .withValues(
                                    alpha: 0.20,
                                  ),
                                  blurRadius:
                                      20,
                                  offset:
                                      const Offset(
                                    0,
                                    8,
                                  ),
                                ),
                              ],
                            ),
                            child:
                                const Icon(
                              Icons
                                  .content_cut_rounded,
                              color: navy,
                              size: 34,
                            ),
                          ),
                          const SizedBox(
                            width: 16,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                const Text(
                                  'LHadi Coiffure',
                                  style:
                                      TextStyle(
                                    color:
                                        Colors.white,
                                    fontSize: 26,
                                    fontWeight:
                                        FontWeight
                                            .w900,
                                  ),
                                ),
                                const SizedBox(
                                  height: 5,
                                ),
                                Text(
                                  'حلاقك، دورك، وقتك ✂️',
                                  style:
                                      TextStyle(
                                    color: Colors
                                        .white
                                        .withValues(
                                      alpha:
                                          0.65,
                                    ),
                                    fontSize: 13,
                                    fontWeight:
                                        FontWeight
                                            .w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 22,
                      ),

                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 15,
                          vertical: 13,
                        ),
                        decoration:
                            BoxDecoration(
                          color: gold.withValues(
                            alpha: 0.09,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            17,
                          ),
                          border: Border.all(
                            color:
                                gold.withValues(
                              alpha: 0.16,
                            ),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons
                                  .auto_awesome_rounded,
                              color: gold,
                              size: 20,
                            ),
                            SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child: Text(
                                'مرحبا بيك 👋 احجز دورك وخلي الباقي علينا.',
                                style:
                                    TextStyle(
                                  color:
                                      Colors.white,
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                // =====================================================
                // QUICK ACTIONS
                // =====================================================

                Row(
                  children: [
                    miniAction(
                      icon: Icons
                          .confirmation_number_outlined,
                      label: 'حجز سريع',
                      onTap: () {
                        Navigator.of(
                          context,
                        ).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const BookingScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(
                      width: 11,
                    ),
                    miniAction(
                      icon: Icons
                          .receipt_long_outlined,
                      label: 'حجوزاتي',
                      onTap: () {
                        Navigator.of(
                          context,
                        ).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const MyBookingsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(
                      width: 11,
                    ),
                    miniAction(
                      icon: Icons
                          .location_on_outlined,
                      label: 'الموقع',
                      onTap: () =>
                          _showLocation(
                        context,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 24,
                ),

                // =====================================================
                // SERVICES TITLE
                // =====================================================

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'الخدمات الرئيسية',
                        style:
                            TextStyle(
                          color:
                              Colors.white,
                          fontSize: 21,
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),
                    ),
                    Text(
                      'HADI',
                      style:
                          TextStyle(
                        color:
                            gold.withValues(
                          alpha: 0.8,
                        ),
                        fontSize: 12,
                        fontWeight:
                            FontWeight
                                .w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 13,
                ),

                // =====================================================
                // SERVICE CARDS
                // =====================================================

                featureCard(
                  icon: Icons
                      .confirmation_number_outlined,
                  title: 'دخول للحجز',
                  subtitle:
                      'احجز دورك عند الحلاق بسهولة وبدون انتظار طويل',
                  primary: true,
                  onTap: () {
                    Navigator.of(
                      context,
                    ).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const BookingScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(
                  height: 12,
                ),

                featureCard(
                  icon: Icons
                      .receipt_long_outlined,
                  title: 'حجوزاتي',
                  subtitle:
                      'تابع رقم دورك وحجوزاتك السابقة في أي وقت',
                  onTap: () {
                    Navigator.of(
                      context,
                    ).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const MyBookingsScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(
                  height: 12,
                ),

                featureCard(
                  icon: Icons
                      .location_on_outlined,
                  title: 'موقع المحل',
                  subtitle:
                      'شوف المكان مباشرة على الخريطة',
                  onTap: () =>
                      _showLocation(
                    context,
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                featureCard(
                  icon: Icons
                      .campaign_outlined,
                  title: 'الإعلانات',
                  subtitle:
                      'آخر الأخبار، العروض والتنبيهات من الحلاق',
                  onTap: () =>
                      _showAnnouncements(
                    context,
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                featureCard(
                  icon: Icons
                      .phone_in_talk_outlined,
                  title: 'تواصل معنا',
                  subtitle:
                      'عندك سؤال؟ تواصل مباشرة مع الحلاق',
                  onTap: () =>
                      _showContact(
                    context,
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                // =====================================================
                // INFO CARD
                // =====================================================

                Container(
                  padding:
                      const EdgeInsets.all(
                    18,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFF0D1828,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      22,
                    ),
                    border: Border.all(
                      color: Colors.white
                          .withValues(
                        alpha: 0.06,
                      ),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons
                            .schedule_rounded,
                        color: gold,
                        size: 24,
                      ),
                      SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              'خدمة الحجز متاحة بسهولة',
                              style:
                                  TextStyle(
                                color:
                                    Colors.white,
                                fontSize: 14,
                                fontWeight:
                                    FontWeight
                                        .w900,
                              ),
                            ),
                            SizedBox(
                              height: 5,
                            ),
                            Text(
                              'ادخل للحجز، خذ رقمك وتابع دورك من الهاتف.',
                              style:
                                  TextStyle(
                                color:
                                    Colors.white60,
                                fontSize: 12.5,
                                height:
                                    1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // =====================================================
                // ADMOB BANNER
                // =====================================================

                const SizedBox(
                  height: 18,
                ),

                const AdMobBanner(),

                const SizedBox(
                  height: 18,
                ),

                // =====================================================
                // FOOTER
                // =====================================================

                const Text(
                  'LHadi Coiffure • حلاقك في وقتك',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color:
                        Colors.white38,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================
// FULL MAP SCREEN
// ===========================================================

class BarberMapScreen extends StatelessWidget {
  final LatLng location;

  const BarberMapScreen({
    super.key,
    required this.location,
  });

  static const Color navy =
      Color(0xFF0D1726);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection:
          TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor:
              Colors.white,
          title: const Text(
            'موقع المحل',
            style: TextStyle(
              fontWeight:
                  FontWeight.w900,
              color: navy,
            ),
          ),
        ),
        body: FlutterMap(
          options: MapOptions(
            initialCenter:
                location,
            initialZoom: 16,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName:
                  'hadi_lhafaf',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: location,
                  width: 80,
                  height: 80,
                  child: const Icon(
                    Icons.location_on,
                    size: 65,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}