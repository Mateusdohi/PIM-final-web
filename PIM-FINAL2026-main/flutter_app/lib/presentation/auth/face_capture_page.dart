import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Abre a câmera FRONTAL, captura uma selfie e devolve o caminho do arquivo via Navigator.pop.
/// Usada no cadastro facial e na confirmação de compra.
class FaceCapturePage extends StatefulWidget {
  const FaceCapturePage({
    super.key,
    this.title = 'SUA SELFIE',
    this.hint = 'Centralize seu rosto no oval, com boa iluminação',
    this.hints,
  });
  final String title;
  final String hint;

  /// Vários passos na mesma tela (ex.: prova de vida: de frente e com a cabeça virada).
  /// A câmera continua aberta entre os passos; a tela devolve um caminho por passo.
  final List<String>? hints;

  @override
  State<FaceCapturePage> createState() => _FaceCapturePageState();
}

class _FaceCapturePageState extends State<FaceCapturePage> with WidgetsBindingObserver {
  CameraController? _controller;
  String? _error;
  XFile? _shot;
  bool _taking = false;
  int _step = 0;
  final List<String> _paths = [];

  List<String> get _hints => widget.hints ?? [widget.hint];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    setState(() => _error = null);
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() => _error = 'Nenhuma câmera encontrada neste aparelho.');
        return;
      }
      final front = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cams.first);
      final c = CameraController(front, ResolutionPreset.medium, enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _controller = c);
    } on CameraException catch (e) {
      if (!mounted) return;
      final denied = e.code.contains('AccessDenied') || e.code.contains('Denied');
      setState(() => _error = denied
          ? 'Permita o acesso à câmera nas configurações do aparelho para continuar.'
          : 'Não foi possível abrir a câmera.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível abrir a câmera.');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed && _shot == null) {
      _init();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _taking) return;
    setState(() => _taking = true);
    try {
      final file = await c.takePicture();
      if (mounted) setState(() => _shot = file);
    } on CameraException {
      if (mounted) setState(() => _error = 'Falha ao capturar a foto. Tente novamente.');
    } finally {
      if (mounted) setState(() => _taking = false);
    }
  }

  void _useShot() {
    final shot = _shot;
    if (shot == null) return;
    _paths.add(shot.path);
    if (_step + 1 < _hints.length) {
      setState(() {
        _step++;
        _shot = null; // volta para a câmera (que continua aberta) para o próximo passo
      });
    } else {
      Navigator.of(context).pop(List<String>.of(_paths));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_hints.length > 1 ? '${widget.title} (${_step + 1}/${_hints.length})' : widget.title)),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.no_photography_outlined, size: 56, color: AppColors.muted),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(onPressed: _init, child: const Text('TENTAR NOVAMENTE')),
          ]),
        ),
      );
    }

    if (_shot != null) {
      return Column(children: [
        Expanded(child: Padding(padding: const EdgeInsets.all(16), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(File(_shot!.path), fit: BoxFit.cover, width: double.infinity)))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => setState(() => _shot = null), child: const Text('REFAZER'))),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(onPressed: _useShot, child: Text(_step + 1 < _hints.length ? 'USAR E CONTINUAR' : 'USAR FOTO'))),
          ]),
        ),
      ]);
    }

    final c = _controller;
    if (c == null || !c.value.isInitialized) return const Center(child: CircularProgressIndicator());

    return Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Text(_hints[_step], textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted))),
      Expanded(
        child: Stack(alignment: Alignment.center, children: [
          ClipRect(child: Center(child: CameraPreview(c))),
          IgnorePointer(child: CustomPaint(size: Size.infinite, painter: _OvalGuidePainter(Theme.of(context).colorScheme.primary))),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Semantics(
          button: true,
          label: 'Tirar foto',
          child: GestureDetector(
            onTap: _capture,
            child: Container(
              width: 76, height: 76,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.brand, width: 4)),
              padding: const EdgeInsets.all(5),
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, color: _taking ? AppColors.muted : AppColors.brand),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 30),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _OvalGuidePainter extends CustomPainter {
  _OvalGuidePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.68;
    final rect = Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: w, height: w * 1.3);
    final overlay = Path()
      ..addRect(Offset.zero & size)
      ..addOval(rect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(overlay, Paint()..color = const Color(0x99000000));
    canvas.drawOval(rect, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = color);
  }

  @override
  bool shouldRepaint(covariant _OvalGuidePainter old) => old.color != color;
}
