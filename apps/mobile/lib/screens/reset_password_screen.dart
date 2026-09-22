import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/floating_sport_icons.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'O código tem 6 dígitos — confirma o email que recebeste.');
      return;
    }
    if (_passwordController.text.length < 8) {
      setState(() => _error = 'A nova password deve ter pelo menos 8 caracteres.');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'As passwords não coincidem.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AppState>().api.resetPassword(
            email: widget.email,
            code: code,
            newPassword: _passwordController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.mint,
          content: Text('Password atualizada! Já podes iniciar sessão.'),
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
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
            child: FloatingSportIcons(color: AppColors.primaryBlue, baseOpacity: 0.14),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Text(
                        'Definir nova password',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: AppShadows.soft,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.mark_email_read_outlined, color: AppColors.primaryBlue, size: 34),
                            const SizedBox(height: 14),
                            Text(
                              'Enviámos um código para',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                            Text(
                              widget.email,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Válido durante 15 minutos.',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _codeController,
                              decoration: const InputDecoration(
                                labelText: 'Código de 6 dígitos',
                                prefixIcon: Icon(Icons.pin_outlined),
                              ),
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 6),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _passwordController,
                              decoration: const InputDecoration(
                                labelText: 'Nova password (mín. 8 caracteres)',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                              obscureText: true,
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _confirmController,
                              decoration: const InputDecoration(
                                labelText: 'Confirmar nova password',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                              obscureText: true,
                              onSubmitted: (_) => _submit(),
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
                                    : const Text('Redefinir password'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
