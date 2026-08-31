
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'دخول الحلاق',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 450,
              ),
              child: Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      // ICON
                      const CircleAvatar(
                        radius: 42,
                        child: Icon(
                          Icons.content_cut,
                          size: 40,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // TITLE
                      const Text(
                        'تسجيل دخول الحلاق',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'قم بتسجيل الدخول لإدارة قائمة الانتظار',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // EMAIL
                      TextField(
                        controller: _emailController,
                        keyboardType:
                            TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        enabled: !_loading,
                        decoration: InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          hintText: 'example@email.com',
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // PASSWORD
                      TextField(
                        controller:
                            _passwordController,
                        obscureText: _obscurePassword,
                        textDirection:
                            TextDirection.ltr,
                        enabled: !_loading,
                        onSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                          ),
                          suffixIcon: IconButton(
                            onPressed: _loading
                                ? null
                                : () {
                                    setState(() {
                                      _obscurePassword =
                                          !_obscurePassword;
                                    });
                                  },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons
                                      .visibility_outlined
                                  : Icons
                                      .visibility_off_outlined,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // LOGIN BUTTON
                      SizedBox(
                        height: 55,
                        child: FilledButton.icon(
                          onPressed:
                              _loading ? null : _login,
                          icon: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.login,
                                ),
                          label: Text(
                            _loading
                                ? 'جاري تسجيل الدخول...'
                                : 'تسجيل الدخول',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
