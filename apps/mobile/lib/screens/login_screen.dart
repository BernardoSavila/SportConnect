import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/floating_sport_icons.dart';
import 'forgot_password_screen.dart';
import 'home_shell.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController(text: 'atleta1@sportconnect.pt');
  final _passwordController = TextEditingController(text: 'Password123');
  bool _loading = false;
  String? _error;

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AppState>().login(_emailController.text.trim(), _passwordController.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, anim, __) => FadeTransition(opacity: anim, child: const HomeShell()),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(decoration: const BoxDecoration(gradient: AppColors.heroGradient)),
          ),
          const Positioned.fill(
            child: FloatingSportIcons(color: AppColors.primaryBlue, baseOpacity: 0.16),
          ),
          // Logótipo e cartão no MESMO fluxo vertical, com espaçamentos
          // fixos entre eles — antes estavam em dois blocos separados,
          // cada um centrado de forma independente, o que fazia o
          // espaçamento variar consoante o cartão crescia (ex: ao
          // aparecer a mensagem de erro), aproximando-os um do outro.
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 90),
                        Image.asset(
                          'assets/images/logo.png',
                          width: 140,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'A tua equipa, sempre ligada.',
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 15),
                        ),
                        const SizedBox(height: 36),
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: AppShadows.soft,
                          ),
                          child: Column(
                            children: [
                              TextField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.alternate_email),
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _passwordController,
                                decoration: const InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                                obscureText: true,
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                                  ),
                                  child: const Text('Esqueceste-te da password?', style: TextStyle(fontSize: 12.5)),
                                ),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: AppColors.coral, size: 18),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.coral))),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _loading ? null : _submit,
                                  child: _loading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text('Entrar'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                ),
                                child: const Text('Criar conta'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
