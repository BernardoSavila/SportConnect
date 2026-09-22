import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/floating_sport_icons.dart';
import 'home_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _teamCodeController = TextEditingController();
  final _teamNameController = TextEditingController();
  bool _isCoach = false;
  String _creatorRole = 'coach'; // 'coach' ou 'admin' — só relevante ao criar equipa nova
  bool _creatingTeam = false;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.length < 8) {
      setState(() => _error = 'Preenche o nome, email e uma password com pelo menos 8 caracteres.');
      return;
    }
    if (!_creatingTeam && _teamCodeController.text.trim().isEmpty) {
      setState(() => _error = 'Precisas do código da tua equipa (pede-o ao treinador).');
      return;
    }
    if (_creatingTeam && _teamNameController.text.trim().isEmpty) {
      setState(() => _error = 'Dá um nome à tua equipa nova.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (inviteCode, isAssistantCoach) = await context.read<AppState>().register(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            role: _creatingTeam ? _creatorRole : (_isCoach ? 'coach' : 'athlete'),
            teamCode: _creatingTeam ? null : _teamCodeController.text.trim(),
            teamName: _creatingTeam ? _teamNameController.text.trim() : null,
          );
      if (!mounted) return;

      // Se acabou de criar uma equipa, mostra o código antes de avançar —
      // é a única oportunidade de o apanhar já, sem ter de ir ao Painel.
      if (inviteCode != null) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Equipa criada! 🎉'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Partilha este código com os teus atletas para se juntarem à equipa:'),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primaryBlue.withOpacity(0.4)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    inviteCode,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 3, color: AppColors.primaryBlue),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Também o vais encontrar sempre que quiseres no teu Painel.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copiar'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: inviteCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Código copiado!')),
                  );
                },
              ),
              FilledButton(
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Continuar'),
              ),
            ],
          ),
        );
        if (!mounted) return;
      } else if (isAssistantCoach) {
        // Entrou como treinador para uma equipa que já tinha um — fica
        // como adjunto, com exatamente as mesmas permissões e painel do
        // principal, só muda o rótulo.
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Treinador(a) Adjunto(a) 🤝'),
            content: const Text(
              'Esta equipa já tem um treinador principal — ficaste registado(a) como treinador(a) adjunto(a). '
              'Tens exatamente as mesmas permissões e acesso ao Painel do Treinador.',
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
        if (!mounted) return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (route) => false,
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
                        'Criar conta',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: AppShadows.soft,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Junta-te à equipa',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                          const SizedBox(height: 4),
                          Text('Cria a tua conta para aceder ao SportConnect.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          const SizedBox(height: 22),
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'Nome completo', prefixIcon: Icon(Icons.person_outline)),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _emailController,
                            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email)),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: 'Password (mín. 8 caracteres)',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 18),

                          // Alternador: entrar numa equipa existente vs criar uma nova.
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _teamModeSegment(
                                    label: 'Tenho um código',
                                    selected: !_creatingTeam,
                                    onTap: () => setState(() => _creatingTeam = false),
                                  ),
                                ),
                                Expanded(
                                  child: _teamModeSegment(
                                    label: 'Criar equipa nova',
                                    selected: _creatingTeam,
                                    onTap: () => setState(() => _creatingTeam = true),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          if (!_creatingTeam) ...[
                            TextField(
                              controller: _teamCodeController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Código da equipa',
                                hintText: 'ex: SPORT1',
                                prefixIcon: Icon(Icons.group_add_outlined),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pede este código ao teu treinador ou a quem criou a equipa.',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5),
                            ),
                            const SizedBox(height: 6),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Sou treinador(a)', style: TextStyle(color: AppColors.textDark)),
                              subtitle: Text('Desligado = atleta', style: TextStyle(color: Colors.grey.shade600)),
                              value: _isCoach,
                              activeColor: AppColors.primaryBlue,
                              onChanged: (v) => setState(() => _isCoach = v),
                            ),
                          ] else ...[
                            TextField(
                              controller: _teamNameController,
                              decoration: const InputDecoration(
                                labelText: 'Nome da equipa',
                                hintText: 'ex: Sporting Sub-16',
                                prefixIcon: Icon(Icons.shield_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'O teu papel nesta equipa nova',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _roleOption(
                                    icon: Icons.sports_outlined,
                                    label: 'Treinador(a)',
                                    subtitle: 'Gere o dia a dia',
                                    selected: _creatorRole == 'coach',
                                    color: AppColors.mint,
                                    onTap: () => setState(() => _creatorRole = 'coach'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _roleOption(
                                    icon: Icons.admin_panel_settings_rounded,
                                    label: 'Admin',
                                    subtitle: 'Supervisiona e regista',
                                    selected: _creatorRole == 'admin',
                                    color: AppColors.primaryBlue,
                                    onTap: () => setState(() => _creatorRole = 'admin'),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.coral, size: 18),
                                const SizedBox(width: 6),
                                Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.coral, fontSize: 13))),
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
                                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Criar conta'),
                            ),
                          ),
                        ],
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

  Widget _teamModeSegment({required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
            color: selected ? AppColors.background : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _roleOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : AppColors.surfaceHigh, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : AppColors.textMuted, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: selected ? color : AppColors.textDark),
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
