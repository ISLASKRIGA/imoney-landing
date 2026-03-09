import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/dependency_injection.dart';
import '../../features/categories/category_provider.dart';
import '../../nlp/intent_parser.dart';
import '../../nlp/smart_category_matcher.dart';
import '../../voice/voice_service.dart';

// ─────────────────────────────────────────────────────────────
// Voice Input Modal — Cinematic listening experience + Smart Category
// ─────────────────────────────────────────────────────────────
class VoiceInputModal extends ConsumerStatefulWidget {
  const VoiceInputModal({super.key});

  @override
  ConsumerState<VoiceInputModal> createState() => _VoiceInputModalState();
}

class _VoiceInputModalState extends ConsumerState<VoiceInputModal>
    with TickerProviderStateMixin {
  String _currentText = '';
  FinanceIntent? _intent;
  bool _isListening = true;

  /// Categoría del usuario resuelta por SmartCategoryMatcher.
  CategoryItem? _resolvedCategory;

  /// Modo de guardado para multi-ítem.
  bool _saveAsSingle = true;

  // ── Animaciones ────────────────────────────────────────────
  late final AnimationController _breathCtrl;
  late final Animation<double> _breathAnim;
  late final AnimationController _r1, _r2, _r3;
  late final AnimationController _gradCtrl;
  late final AnimationController _cardCtrl;
  late final Animation<double> _cardScale;
  late final Animation<double> _cardFade;
  late final AnimationController _textCtrl;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _textFade;
  // Animación especial del chip de categoría
  late final AnimationController _catCtrl;
  late final Animation<double> _catScale;

  static const _rippleDuration = Duration(milliseconds: 2400);
  static const _rippleStagger = Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();

    _breathCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _breathAnim = Tween<double>(begin: 0.92, end: 1.08)
        .animate(CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut));

    _r1 = AnimationController(vsync: this, duration: _rippleDuration)..repeat();
    _r2 = AnimationController(vsync: this, duration: _rippleDuration);
    _r3 = AnimationController(vsync: this, duration: _rippleDuration);
    Future.delayed(_rippleStagger, () { if (mounted) _r2.repeat(); });
    Future.delayed(_rippleStagger * 2, () { if (mounted) _r3.repeat(); });

    _gradCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();

    _cardCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _cardScale = CurvedAnimation(parent: _cardCtrl, curve: Curves.elasticOut);
    _cardFade  = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeIn);

    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));
    _textFade  = CurvedAnimation(parent: _textCtrl, curve: Curves.easeIn);

    _catCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _catScale = CurvedAnimation(parent: _catCtrl, curve: Curves.elasticOut);

    WidgetsBinding.instance.addPostFrameCallback((_) => _startListening());
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    _r1.dispose(); _r2.dispose(); _r3.dispose();
    _gradCtrl.dispose();
    _cardCtrl.dispose();
    _textCtrl.dispose();
    _catCtrl.dispose();
    ref.read(voiceServiceProvider).stopListening();
    super.dispose();
  }

  // ── Voice logic ────────────────────────────────────────────
  void _startListening() {
    final svc = ref.read(voiceServiceProvider);

    svc.partialTextStream.listen((text) {
      if (!mounted) return;
      setState(() { _currentText = text; _isListening = true; });
      if (text.isNotEmpty) _textCtrl.forward();
      _tryParse(text);
    });

    svc.statusStream.listen((status) {
      if (!mounted) return;
      if (status == VoiceStatus.idle || status == VoiceStatus.processing) {
        setState(() => _isListening = false);
      }
    });

    svc.startListening();
  }

  void _tryParse(String text) {
    if (text.isEmpty) return;
    final intent = ref.read(intentParserProvider).parse(text);
    if (intent.action != IntentAction.unknown && intent.amount != null) {
      // Resuelve la categoría del usuario con SmartCategoryMatcher
      final matcher = ref.read(smartCategoryMatcherProvider);
      final normalizedText = text
          .toLowerCase()
          .replaceAll('á','a').replaceAll('é','e').replaceAll('í','i')
          .replaceAll('ó','o').replaceAll('ú','u').replaceAll('ü','u')
          .replaceAll('ñ','n');
      final resolved = matcher.match(normalizedText, intent.category);

      if (intent != _intent || resolved?.name != _resolvedCategory?.name) {
        setState(() {
          _intent = intent;
          _resolvedCategory = resolved;
        });
        _cardCtrl.forward(from: 0);
        _catCtrl.forward(from: 0);
      }
    }
  }

  // ── Guardar ────────────────────────────────────────────────
  Future<void> _confirm() async {
    if (_intent == null) return;
    final repo   = ref.read(transactionRepositoryProvider);
    final isIncome = _intent!.action == IntentAction.create_income;
    // Usa el nombre de la categoría resuelta, fallback a la del NLP
    final catName = _resolvedCategory?.name ?? _intent!.category ?? 'General';

    try {
      if (_intent!.isMultiItem && !_saveAsSingle) {
        // Guardar ítem por ítem (cada uno con su propia categoría resuelta)
        final matcher = ref.read(smartCategoryMatcherProvider);
        for (final item in _intent!.lineItems) {
          final itemNorm = item.description.toLowerCase();
          final itemCat  = matcher.match(itemNorm, item.category);
          await repo.addTransaction(
            amount: item.amount,
            category: itemCat?.name ?? item.category,
            description: item.description,
            date: _intent!.date ?? DateTime.now(),
            isIncome: isIncome,
          );
        }
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ ${_intent!.lineItems.length} transacciones guardadas'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ));
        }
      } else {
        await repo.addTransaction(
          amount: _intent!.amount ?? 0,
          category: catName,
          description: _intent!.description ?? (isIncome ? 'Ingreso' : 'Gasto'),
          date: _intent!.date ?? DateTime.now(),
          isIncome: isIncome,
        );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ Guardado en $catName'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Color según tipo ───────────────────────────────────────
  Color get _primaryColor {
    if (_intent != null && _intent!.amount != null) {
      return _intent!.action == IntentAction.create_income
          ? const Color(0xFF00C853)
          : const Color(0xFFFF5252);
    }
    return const Color(0xFF7C4DFF);
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final hasIntent = _intent != null && _intent!.amount != null;
    final isExpense = _intent?.action != IntentAction.create_income;
    final color     = _primaryColor;
    final isMulti   = _intent?.isMultiItem ?? false;

    final catEmoji = _resolvedCategory?.emoji ?? '📦';
    final catName  = _resolvedCategory?.name  ?? _intent?.category ?? 'General';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          // ── Orb + Ripples ───────────────────────────────────
          SizedBox(
            height: 180, width: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _RippleRing(controller: _r1, color: color),
                _RippleRing(controller: _r2, color: color),
                _RippleRing(controller: _r3, color: color),
                AnimatedBuilder(
                  animation: Listenable.merge([_breathAnim, _gradCtrl]),
                  builder: (context, _) {
                    final angle = _gradCtrl.value * 2 * pi;
                    return Transform.scale(
                      scale: _isListening && !hasIntent ? _breathAnim.value : 1.0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeInOutCubic,
                        width: 110, height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            startAngle: angle,
                            endAngle: angle + 2 * pi,
                            colors: hasIntent
                                ? [color, color.withValues(alpha: 0.7), color]
                                : [
                                    const Color(0xFF7C4DFF),
                                    const Color(0xFF651FFF),
                                    const Color(0xFF9C27B0),
                                    const Color(0xFF7C4DFF),
                                  ],
                          ),
                          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 32, spreadRadius: 4)],
                        ),
                        child: Icon(
                          hasIntent ? Icons.check_rounded : Icons.mic_rounded,
                          color: Colors.white, size: 46,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Status label ────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              hasIntent
                  ? (isMulti ? '${_intent!.lineItems.length} ítems detectados' : '¡Detectado!')
                  : (_isListening ? 'Escuchando...' : 'Procesando...'),
              key: ValueKey(hasIntent ? 'done$isMulti' : _isListening.toString()),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: hasIntent ? color : Colors.grey[500],
                letterSpacing: 0.5,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Chip de categoría resuelta (nuevo) ─────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: hasIntent && _resolvedCategory != null
                ? ScaleTransition(
                    scale: _catScale,
                    child: _buildCategoryChip(catEmoji, catName, color),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 12),

          // ── Transcript ──────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            child: _currentText.isNotEmpty
                ? SlideTransition(
                    position: _textSlide,
                    child: FadeTransition(
                      opacity: _textFade,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F6F9),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          '"$_currentText"',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[800],
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 16),

          // ── Result card ─────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubic,
            child: hasIntent
                ? ScaleTransition(
                    scale: _cardScale,
                    child: FadeTransition(
                      opacity: _cardFade,
                      child: isMulti
                          ? _buildMultiItemCard(isExpense, color)
                          : _buildSingleCard(catEmoji, catName, isExpense, color),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 24),

          // ── Buttons ─────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: hasIntent
                ? Column(
                    key: const ValueKey('buttons'),
                    children: [
                      if (isMulti) ...[
                        _buildSaveToggle(color),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(color: Colors.grey[200]!),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                foregroundColor: Colors.grey[600],
                              ),
                              child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: _confirm,
                              icon: const Icon(Icons.check_rounded, size: 20),
                              label: const Text('Confirmar',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              style: FilledButton.styleFrom(
                                backgroundColor: color,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : TextButton.icon(
                    key: const ValueKey('close'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.keyboard_arrow_down),
                    label: const Text('Cerrar'),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey),
                  ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Chip de categoría resuelta
  // ─────────────────────────────────────────────────────────
  Widget _buildCategoryChip(String emoji, String name, Color color) {
    // Busca el índice de la categoría para obtener el color de paleta
    final categories = ref.read(categoryProvider);
    final palette = [
      const Color(0xFFF8BBD0), const Color(0xFFFFCC80), const Color(0xFFDCEDC8),
      const Color(0xFFE8EAF6), const Color(0xFFB3E5FC), const Color(0xFFEFEBE9),
      const Color(0xFFCFD8DC), const Color(0xFFC5CAE9),
    ];
    final idx = categories.indexWhere((c) => c.name == name);
    final chipBg = idx >= 0 ? palette[idx % palette.length] : color.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(
            name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Card: ítem único
  // ─────────────────────────────────────────────────────────
  Widget _buildSingleCard(String emoji, String catName, bool isExpense, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        catName,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(isExpense ? '· Gasto' : '· Ingreso',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _intent!.description ?? '',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(_formatDate(_intent!.date),
                    style: TextStyle(fontSize: 12, color: Colors.grey[400])),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isExpense ? "−" : "+"}\$${_intent!.amount?.toStringAsFixed(0) ?? "0"}',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color),
              ),
              Text(
                '${(_intent!.confidence * 100).toInt()}% conf.',
                style: TextStyle(fontSize: 10, color: Colors.grey[400]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Card: múltiples ítems con desglose
  // ─────────────────────────────────────────────────────────
  Widget _buildMultiItemCard(bool isExpense, Color color) {
    final total = _intent!.amount ?? 0;
    final matcher = ref.read(smartCategoryMatcherProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isExpense ? 'Gasto múltiple' : 'Ingreso múltiple',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                ),
              ),
              const Spacer(),
              Text(
                '${isExpense ? "−" : "+"}\$${total.toStringAsFixed(total % 1 == 0 ? 0 : 2)}',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(_formatDate(_intent!.date),
              style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          // Ítems con categoría resuelta
          ...List.generate(_intent!.lineItems.length, (i) {
            final item = _intent!.lineItems[i];
            final norm = item.description.toLowerCase();
            final resolved = matcher.match(norm, item.category);
            final itemEmoji = resolved?.emoji ?? '📦';
            final itemCat   = resolved?.name  ?? item.category;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Text(itemEmoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.description,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(itemCat,
                            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  Text(
                    '\$${item.amount.toStringAsFixed(item.amount % 1 == 0 ? 0 : 2)}',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total (${_intent!.lineItems.length} ítems)',
                style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  Text(
                    '\$${total.toStringAsFixed(total % 1 == 0 ? 0 : 2)}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      '${(_intent!.confidence * 100).toInt()}%',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Toggle modo de guardado
  // ─────────────────────────────────────────────────────────
  Widget _buildSaveToggle(Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          _ToggleChip(label: 'Una sola', icon: Icons.merge_type, selected: _saveAsSingle,
              color: color, onTap: () => setState(() => _saveAsSingle = true)),
          _ToggleChip(label: 'Separadas', icon: Icons.call_split, selected: !_saveAsSingle,
              color: color, onTap: () => setState(() => _saveAsSingle = false)),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Hoy';
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ─────────────────────────────────────────────────────────────
// Toggle chip
// ─────────────────────────────────────────────────────────────
class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label, required this.icon,
    required this.selected, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: selected ? Colors.white : Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Ripple Ring
// ─────────────────────────────────────────────────────────────
class _RippleRing extends StatelessWidget {
  final AnimationController controller;
  final Color color;

  const _RippleRing({required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        final scale = 0.5 + (t * 1.1);
        final opacity = t < 0.3 ? (t / 0.3) * 0.5 : (1.0 - t) * 0.5;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: opacity.clamp(0.0, 1.0)),
                width: 2.5,
              ),
            ),
          ),
        );
      },
    );
  }
}
