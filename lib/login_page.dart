import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'ui/app_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _authService = AuthService();
  bool _loading = false;
  String? _error;

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _authService.signInWithGoogleRestrictedDomain();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;

            final cardW = (w * 0.46).clamp(360.0, 560.0);
            final logoSize = (cardW * 0.22).clamp(72.0, 120.0);

            return Center(
              child: Container(
                width: cardW,
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                decoration: BoxDecoration(
                  color: AppTheme.cream,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.ink, width: 1.4),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, offset: Offset(4, 4), blurRadius: 0),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // LOGO
                    Container(
                      width: logoSize,
                      height: logoSize,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.barDark, // ✅ contrast for white logo
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.ink, width: 1.2),
                      ),
                      child: Image.asset(
                        "assets/logo.png",
                        fit: BoxFit.contain,
                        errorBuilder: (context, err, stack) => Center(
                          child: Text(
                            "Logo error",
                            style: TextStyle(color: AppTheme.cream.withValues(alpha: 0.9), fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      "Acesso restrito",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.ink,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      "Entre com seu e-mail @espartmoveis.com",
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.ink.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _handleGoogleLogin, // ✅ use your handler
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login),
                        label: Text(
                          _loading ? "Entrando..." : "Entrar com Google",
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cream,
                          foregroundColor: AppTheme.ink,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(color: AppTheme.ink.withValues(alpha: 0.35), width: 1.2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}