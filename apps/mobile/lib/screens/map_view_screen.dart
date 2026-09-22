import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';

/// Mostra a localização de um evento num cartão modal, por cima da própria
/// página (fundo escurecido), em vez de abrir um ecrã novo — toca fora do
/// cartão para fechar. O mapa em si usa tiles escuros do CARTO (gratuitos,
/// sem chave de API), para condizer com o resto da app em vez do branco
/// padrão dos mapas.
Future<void> showMapDialog(BuildContext context, {required String location, required String eventTitle}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.75),
    builder: (context) => _MapDialog(location: location, eventTitle: eventTitle),
  );
}

class _MapDialog extends StatefulWidget {
  const _MapDialog({required this.location, required this.eventTitle});

  final String location;
  final String eventTitle;

  @override
  State<_MapDialog> createState() => _MapDialogState();
}

class _MapDialogState extends State<_MapDialog> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background);
    _loadMap();
  }

  Future<void> _loadMap() async {
    try {
      // Nominatim é o serviço de geocodificação gratuito do OpenStreetMap —
      // converte o texto do local em coordenadas.
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeQueryComponent(widget.location)}&format=json&limit=1',
      );
      final res = await http
          .get(uri, headers: {'User-Agent': 'SportConnectApp/1.0'})
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) throw Exception('geocoding falhou');
      final List results = jsonDecode(res.body);
      if (results.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Não foi possível encontrar este local no mapa.';
        });
        return;
      }

      final lat = double.parse(results.first['lat']);
      final lon = double.parse(results.first['lon']);
      await _controller.loadHtmlString(_darkMapHtml(lat, lon));
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível carregar o mapa. Verifica a ligação.';
      });
    }
  }

  /// Página HTML auto-contida com Leaflet.js + tiles escuros do CARTO
  /// ("dark_all") e um marcador circular verde-lima com brilho, em vez do
  /// pin vermelho padrão — para condizer com o resto da app.
  String _darkMapHtml(double lat, double lon) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
  <style>
    html, body, #map { height: 100%; margin: 0; padding: 0; background: #0A0C10; }
    .leaflet-control-attribution { background: rgba(10,12,16,0.7) !important; color: #8891A0 !important; font-size: 9px !important; }
    .leaflet-control-attribution a { color: #C6FF3D !important; }
    .leaflet-control-zoom a { background-color: #15181F !important; color: #F3F5F8 !important; border-color: rgba(255,255,255,0.1) !important; }
  </style>
</head>
<body>
  <div id="map"></div>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <script>
    var map = L.map('map', { zoomControl: true }).setView([$lat, $lon], 15);
    L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
      attribution: '&copy; OpenStreetMap &copy; CARTO',
      subdomains: 'abcd',
      maxZoom: 19
    }).addTo(map);
    var icon = L.divIcon({
      className: '',
      html: '<div style="width:22px;height:22px;border-radius:50%;background:#C6FF3D;border:3px solid #0A0C10;box-shadow:0 0 14px #C6FF3D;"></div>',
      iconSize: [22, 22],
      iconAnchor: [11, 11]
    });
    L.marker([$lat, $lon], { icon: icon }).addTo(map);
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      child: GestureDetector(
        // Impede que um toque DENTRO do cartão feche o diálogo — só toques
        // fora dele (na área escurecida) é que fecham.
        onTap: () {},
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppShadows.soft,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.eventTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark)),
                          const SizedBox(height: 2),
                          Text(widget.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 340,
                width: double.maxFinite,
                child: _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_off_outlined, color: AppColors.textMuted, size: 36),
                              const SizedBox(height: 10),
                              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                            ],
                          ),
                        ),
                      )
                    : Stack(
                        children: [
                          WebViewWidget(controller: _controller),
                          if (_loading) const Center(child: CircularProgressIndicator()),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
