import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sistema de design do SportConnect v3 — visual "dashboard desportivo"
/// escuro e vibrante (inspirado em apps como Strava/Nike Training Club/Whoop),
/// com um verde-lima elétrico como cor de assinatura que brilha sobre fundos
/// quase-pretos, números grandes e ousados, e cartões elevados em vez de
/// sombras suaves.
class AppColors {
  AppColors._();

  // Cor de assinatura — verde-lima elétrico, brilha sobre o fundo escuro.
  static const Color deepBlue = Color(0xFF7ACC00); // volt escuro (usado em gradientes/glow)
  static const Color primaryBlue = Color(0xFFC6FF3D); // volt — cor de marca principal
  static const Color skyBlue = Color(0xFFE3FF9E); // volt claro (realces/hover)
  static const Color cyan = Color(0xFF4CC9F0); // acento frio (chat, informação)

  // Acentos de contraste
  static const Color amber = Color(0xFFFFC93C); // medalhas / pontos
  static const Color coral = Color(0xFFFF4D6D); // jogos / urgência
  static const Color mint = Color(0xFF2DD4BF); // sucesso / presença confirmada (distinto do volt)

  // Base escura — em vez de branco/cinza-claro como antes.
  static const Color background = Color(0xFF0A0C10); // fundo geral, quase-preto
  static const Color surface = Color(0xFF15181F); // cartões elevados
  static const Color surfaceHigh = Color(0xFF1D212B); // elevação extra (chips, tiles de stats)
  static const Color textDark = Color(0xFFF3F5F8); // texto principal — quase-branco sobre cartões escuros
  static const Color textMuted = Color(0xFF8891A0);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A0C10), Color(0xFF171B22)],
  );

  static const LinearGradient cardAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [deepBlue, primaryBlue],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD166), amber],
  );
}

/// Estilos de texto para números grandes e ousados (estatísticas, pontos,
/// contagens) — o elemento tipográfico assinatura do novo visual.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle bigStat({Color color = AppColors.primaryBlue, double size = 44}) {
    return GoogleFonts.manrope(fontSize: size, fontWeight: FontWeight.w800, color: color, height: 1, letterSpacing: -1.2);
  }
}

class AppShadows {
  AppShadows._();

  // Em fundos quase-pretos, uma sombra clara não se vê — a profundidade
  // vem sobretudo da diferença de tom entre o cartão e o fundo, mais uma
  // sombra escura subtil para dar alguma separação.
  static List<BoxShadow> soft = [
    const BoxShadow(
      color: Colors.black54,
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  static List<BoxShadow> glow(Color color) => [
        BoxShadow(
          color: color.withOpacity(0.45),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];

  // Contorno subtil usado nos cartões escuros, no lugar de uma sombra
  // que dificilmente se notaria sobre um fundo tão escuro.
  static Border cardBorder = Border.all(color: Colors.white.withOpacity(0.06));
}

class AppTheme {
  AppTheme._();

  /// Tema único e escuro — depois da mudança de identidade visual, deixou
  /// de fazer sentido ter uma variante "clara" separada, já que os
  /// próprios tokens de cor (`AppColors.background`/`surface`) passaram a
  /// ser escuros. `light` e `dark` devolvem agora o mesmo tema, para o
  /// resto da app (que só referencia `AppTheme.light`/`.dark`) continuar
  /// a funcionar sem mais alterações.
  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryBlue,
        brightness: Brightness.dark,
        primary: AppColors.primaryBlue,
        secondary: AppColors.cyan,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: GoogleFonts.interTextTheme(ThemeData(brightness: Brightness.dark).textTheme),
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineSmall: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.textDark, letterSpacing: -0.5),
        titleLarge: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppColors.textDark),
        titleMedium: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: AppColors.textDark),
        bodyMedium: GoogleFonts.inter(color: AppColors.textDark, height: 1.4),
        bodySmall: GoogleFonts.inter(color: AppColors.textMuted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        height: 68,
        indicatorColor: AppColors.primaryBlue.withOpacity(0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.primaryBlue : AppColors.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? AppColors.primaryBlue : AppColors.textMuted);
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: AppColors.background,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          side: BorderSide(color: AppColors.primaryBlue.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primaryBlue),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        labelStyle: TextStyle(color: AppColors.textMuted),
        hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.7)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.6),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceHigh,
        titleTextStyle: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textDark),
        contentTextStyle: GoogleFonts.inter(color: AppColors.textDark, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  static ThemeData get light => dark;
}

/// Cor de "cartão" que se adapta ao tema claro/escuro — usar em vez de
/// `Colors.white` fixo nos widgets partilhados, para o modo escuro ficar
/// consistente em toda a app.
extension ThemeAwareColors on BuildContext {
  Color get cardBackground => Theme.of(this).brightness == Brightness.dark ? const Color(0xFF17202E) : Colors.white;
  Color get primaryTextColor => Theme.of(this).brightness == Brightness.dark ? Colors.white : AppColors.textDark;
}

/// Cabeçalho com gradiente + curva na base, usado como "hero" no topo dos
/// ecrãs principais — é o elemento assinatura do novo design. Suporta um
/// ícone decorativo em marca de água e uma barra de destaque sob o título,
/// para mais detalhe visual.
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.height = 150,
    this.watermarkIcon,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final double height;
  final IconData? watermarkIcon;

  @override
  Widget build(BuildContext context) {
    return PhysicalShape(
      clipper: _HeaderClipper(),
      color: Colors.transparent,
      elevation: 10,
      shadowColor: AppColors.primaryBlue.withOpacity(0.45),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: Stack(
          children: [
            if (watermarkIcon != null)
              Positioned(
                right: -18,
                top: -14,
                child: Transform.rotate(
                  angle: -0.25,
                  child: Icon(watermarkIcon, size: 118, color: Colors.white.withOpacity(0.05)),
                ),
              ),
            Positioned(
              right: -30,
              bottom: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primaryBlue.withOpacity(0.08)),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Aparece sozinho sempre que este ecrã foi aberto por
                    // cima de outro (Navigator.push) — resolve de forma
                    // central a falta de seta de recuar em vários ecrãs
                    // (Sondagens, Mensagens, etc.), sem ser preciso mexer
                    // em cada um.
                    if (Navigator.canPop(context))
                      Padding(
                        padding: const EdgeInsets.only(right: 4, top: 1),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 20,
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 30,
                            height: 3,
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: AppShadows.glow(AppColors.primaryBlue),
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(color: Colors.white.withOpacity(0.85), fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                    ...actions,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 28);
    path.quadraticBezierTo(size.width / 2, size.height, size.width, size.height - 28);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
