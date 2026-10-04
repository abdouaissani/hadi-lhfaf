
import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import 'admin_dashboard.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final SupabaseService _service = SupabaseService();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // =========================================================
  // LOGIN
  // =========================================================

  Future<void> _login() async {
    if (_loading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      _showMessage('يرجى إدخال البريد الإلكتروني');
      return;
    }

    if (password.isEmpty) {
      _showMessage('يرجى إدخال كلمة المرور');
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await _service.barberLogin(
        email: email,
        password: password,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const AdminDashboard(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'البريد الإلكتروني أو كلمة المرور غير صحيحة',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // =========================================================
  // MESSAGE
  // =========================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.right,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0D1726);
    const gold = Color(0xFFD7A84B);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6F8),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 470),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [Color(0xFF182A45), navy],
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Column(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: Color(0x22D7A84B),
                            child: Icon(Icons.content_cut_rounded, color: gold, size: 34),
                          ),
                          SizedBox(height: 16),
                          Text('LHadi Coiffure', style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
                          SizedBox(height: 5),
                          Text('Espace professionnel', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: const Color(0xFFE7E9EE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('تسجيل دخول الحلاق', style: TextStyle(color: navy, fontSize: 21, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          const Text('أدخل بياناتك للوصول إلى لوحة التحكم', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textDirection: TextDirection.ltr,
                            enabled: !_loading,
                            decoration: InputDecoration(
                              labelText: 'البريد الإلكتروني',
                              hintText: 'example@email.com',
                              prefixIcon: const Icon(Icons.email_outlined, color: navy),
                              filled: true,
                              fillColor: const Color(0xFFF7F8FA),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 13),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textDirection: TextDirection.ltr,
                            enabled: !_loading,
                            onSubmitted: (_) => _login(),
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              prefixIcon: const Icon(Icons.lock_outline_rounded, color: navy),
                              suffixIcon: IconButton(
                                onPressed: _loading ? null : () => setState(() => _obscurePassword = !_obscurePassword),
                                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF7F8FA),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 56,
                            child: FilledButton.icon(
                              onPressed: _loading ? null : _login,
                              icon: _loading ? const SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login_rounded),
                              label: Text(_loading ? 'جاري تسجيل الدخول...' : 'دخول لوحة التحكم', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                              style: FilledButton.styleFrom(backgroundColor: navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('LHadi Coiffure • Gestion de file d’attente', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
