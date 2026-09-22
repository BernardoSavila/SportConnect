import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Efeito "shimmer" (brilho a percorrer) para estados de carregamento —
/// substitui o spinner genérico por um esqueleto do conteúdo, dando uma
/// sensação mais profissional e polida durante o carregamento.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({super.key, this.width, this.height = 14, this.borderRadius = 8});

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 + _controller.value * 3, 0),
              end: Alignment(_controller.value * 3, 0),
              colors: [
                AppColors.background,
                Colors.white,
                AppColors.background,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Esqueleto para um cartão de evento/post enquanto o pedido à API decorre.
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key, this.showAvatar = true});

  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: AppShadows.soft),
      child: Row(
        children: [
          if (showAvatar) ...[
            const ShimmerBox(width: 52, height: 52, borderRadius: 16),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: MediaQuery.of(context).size.width * 0.4),
                const SizedBox(height: 8),
                ShimmerBox(width: MediaQuery.of(context).size.width * 0.55, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lista de esqueletos — usar enquanto um FutureBuilder está a carregar.
///
/// Usa Column (não ListView) de propósito: assim funciona tanto sozinho
/// dentro de um Expanded como quando é só mais um item dentro de outra
/// lista/ListView já existente — um ListView aninhado sem altura definida
/// nesse segundo caso causava um crash ("unbounded height").
class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.count = 4, this.showAvatar = true});

  final int count;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: List.generate(count, (i) => ShimmerCard(showAvatar: showAvatar)),
      ),
    );
  }
}
