import 'package:flutter/material.dart' hide Border, BorderStyle;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/dependency_injection.dart';
import '../categories/category_editor_modal.dart';
import '../recurring/recurring_modal.dart';
import '../lists/user_lists_modal.dart';
import '../lists/lists_provider.dart';
import 'settings_provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constantes de la app
// ─────────────────────────────────────────────────────────────────────────────
const _appVersion = '1.7.0';
const _buildNumber = '121';

const _voiceLanguages = [
  {'code': 'es-CO', 'label': 'Español (Colombia)', 'flag': '🇨🇴'},
  {'code': 'es-MX', 'label': 'Español (México)',   'flag': '🇲🇽'},
  {'code': 'es-ES', 'label': 'Español (España)',   'flag': '🇪🇸'},
  {'code': 'en-US', 'label': 'English (US)',        'flag': '🇺🇸'},
  {'code': 'en-GB', 'label': 'English (UK)',        'flag': '🇬🇧'},
  {'code': 'pt-BR', 'label': 'Português (Brasil)', 'flag': '🇧🇷'},
  {'code': 'fr-FR', 'label': 'Français (France)',  'flag': '🇫🇷'},
  {'code': 'de-DE', 'label': 'Deutsch',            'flag': '🇩🇪'},
];

const _currencies = [
  {'code': 'COP', 'label': 'Peso colombiano',  'symbol': '\$', 'flag': '🇨🇴'},
  {'code': 'USD', 'label': 'Dólar americano',  'symbol': '\$', 'flag': '🇺🇸'},
  {'code': 'EUR', 'label': 'Euro',             'symbol': '€', 'flag': '🇪🇺'},
  {'code': 'MXN', 'label': 'Peso mexicano',   'symbol': '\$', 'flag': '🇲🇽'},
  {'code': 'GBP', 'label': 'Libra esterlina', 'symbol': '£', 'flag': '🇬🇧'},
  {'code': 'BRL', 'label': 'Real brasileño',  'symbol': 'R\$','flag': '🇧🇷'},
  {'code': 'ARS', 'label': 'Peso argentino',  'symbol': '\$', 'flag': '🇦🇷'},
  {'code': 'CLP', 'label': 'Peso chileno',    'symbol': '\$', 'flag': '🇨🇱'},
  {'code': 'PEN', 'label': 'Sol peruano',     'symbol': 'S/.','flag': '🇵🇪'},
  {'code': 'JPY', 'label': 'Yen japonés',     'symbol': '¥', 'flag': '🇯🇵'},
];

// ─────────────────────────────────────────────────────────────────────────────
// Modal principal
// ─────────────────────────────────────────────────────────────────────────────
class SettingsModal extends ConsumerWidget {
  const SettingsModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final topPad = MediaQuery.of(context).padding.top;

    // Bandera del idioma de voz seleccionado
    final voiceFlag = _voiceLanguages.firstWhere(
      (l) => l['code'] == settings.voiceLanguage,
      orElse: () => _voiceLanguages.first,
    )['flag']!;


    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      snap: true,
      snapSizes: const [0.92],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // ── Drag handle ────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header ────────────────────────────────────
              _buildHeader(context),

              // ── Scrollable content ─────────────────────────
              Expanded(
                child: ListView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  children: [
                    // ══════════════════ SECCIÓN: Contenido ══════════════════
                    _sectionLabel('Contenido'),
                    const SizedBox(height: 12),

                    _buildSettingsItem(
                      emoji: '🥑',
                      title: 'Editar categorías',
                      subtitle: 'Agrega o elimina categorías',
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const CategoryEditorModal(),
                        );
                      },
                    ),
                    _buildSettingsItem(
                      icon: Icons.tag,
                      iconColor: Colors.blueGrey,
                      title: 'Editar etiquetas',
                      subtitle: 'En tu lista actual "${ref.watch(activeListProvider)?.name ?? 'Lista Privada'}"',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Edición de etiquetas próximamente')),
                        );
                      },
                    ),
                    _buildSettingsItem(
                      icon: Icons.repeat,
                      iconColor: Colors.blueGrey,
                      title: 'Lista de transacciones recurrentes',
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const RecurringTransactionsModal(),
                        );
                      },
                    ),
                    Builder(builder: (bCtx) {
                      final listsAsync = ref.watch(listsNotifierProvider);
                      final count = listsAsync.valueOrNull?.length ?? 0;
                      return _buildSettingsItem(
                        emoji: '📝',
                        title: 'Tus listas',
                        badge: count > 0 ? '$count' : null,
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const UserListsModal(),
                          );
                        },
                      );
                    }),
                    _buildSettingsItem(
                      icon: Icons.upload,
                      iconColor: Colors.blue,
                      title: 'Compartir lista',
                      subtitle: 'Lista privada',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Compartir listas próximamente')),
                        );
                      },
                    ),
                    _buildSettingsItem(
                      icon: Icons.bar_chart,
                      iconColor: Colors.green,
                      title: 'Exportar CSV',
                      onTap: () => _exportCsv(context, ref),
                    ),
                    _buildSettingsItem(
                      icon: Icons.grid_on,
                      iconColor: Colors.green[800],
                      title: 'Exportar Excel (Pro)',
                      subtitle: 'Con formato y diseño profesional',
                      onTap: () => _exportExcel(context, ref),
                    ),
                    _buildSettingsItem(
                      icon: Icons.download,
                      iconColor: Colors.blue,
                      title: 'Importar CSV',
                      subtitle: 'Pega un CSV exportado anteriormente',
                      onTap: () => _importCsv(context, ref),
                    ),
                    _buildSettingsToggle(
                      icon: Icons.add,
                      title: 'Mostrar ingresos',
                      value: settings.showIncome,
                      onChanged: (val) => settingsNotifier.toggleShowIncome(val),
                    ),
                    _buildSettingsToggle(
                      icon: Icons.turn_left,
                      title: 'Acumulado',
                      subtitle: 'Mostrar el total de todos los meses en lugar del mes actual solamente',
                      value: settings.accumulated,
                      onChanged: (val) => settingsNotifier.toggleAccumulated(val),
                    ),
                    _buildSettingsItem(
                      icon: Icons.build,
                      iconColor: Colors.grey,
                      title: 'Funciones solicitadas',
                      subtitle: 'Vota y sugiere: sé parte de la evolución de la app',
                      onTap: () => _showFeedbackModal(context),
                    ),
                    _buildSettingsItem(
                      icon: Icons.auto_awesome,
                      iconColor: Colors.deepPurple,
                      title: 'Mejoras de IA',
                      subtitle: 'En tu lista actual "${ref.watch(activeListProvider)?.name ?? 'Lista Privada'}"',
                      onTap: () => _showAIImprovementsModal(context, ref),
                    ),

                    const SizedBox(height: 24),
                    _buildDivider(),
                    const SizedBox(height: 8),

                    // ══════════════════ SECCIÓN: Idioma y región ══════════════════
                    _sectionLabel('Idioma y región'),
                    const SizedBox(height: 12),

                    _buildSettingsItem(
                      emoji: voiceFlag,
                      title: 'Idioma de entrada de voz',
                      onTap: () => _showVoiceLanguagePicker(context, ref, settings),
                    ),
                    _buildSettingsItem(
                      icon: Icons.attach_money,
                      iconColor: Colors.blueGrey,
                      title: 'Moneda',
                      subtitle: settings.currency,
                      onTap: () => _showCurrencyPicker(context, ref, settings),
                    ),
                    _buildSettingsItem(
                      emoji: '💱',
                      title: 'Convertidor de moneda',
                      subtitle: 'Convirtiendo de ${settings.convertFrom} a ${settings.convertTo} ahora',
                      onTap: () => _showCurrencyConverterModal(context, ref, settings),
                    ),

                    const SizedBox(height: 24),
                    _buildDivider(),
                    const SizedBox(height: 8),

                    // ══════════════════ SECCIÓN: Más ══════════════════
                    _sectionLabel('Más'),
                    const SizedBox(height: 12),

                    _buildSettingsItem(
                      icon: Icons.diamond_outlined,
                      iconColor: const Color(0xFF6C63FF),
                      title: 'Premium',
                      subtitle: 'Activa',
                      onTap: () => _showPremiumModal(context),
                    ),
                    _buildSettingsItem(
                      icon: Icons.brightness_4_outlined,
                      iconColor: Colors.black87,
                      title: 'Apariencia',
                      subtitle: _themeModeLabel(settings.themeMode),
                      onTap: () => _showAppearancePicker(context, ref, settings),
                    ),
                    _buildSettingsItem(
                      icon: Icons.new_releases_outlined,
                      iconColor: Colors.redAccent,
                      title: 'Novedades',
                      subtitle: '$_appVersion ($_buildNumber)',
                      onTap: () => _showChangelogModal(context),
                    ),

                    SizedBox(height: topPad + 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Helpers de UI
  // ─────────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.black54,
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: Colors.grey[200],
    );
  }

  String _themeModeLabel(String mode) {
    switch (mode) {
      case 'light': return 'Claro';
      case 'dark':  return 'Oscuro';
      default:      return 'Define cómo se ve tu app';
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // Modales de las nuevas opciones
  // ─────────────────────────────────────────────────────────────────────

  /// Picker de idioma de entrada de voz
  void _showVoiceLanguagePicker(BuildContext context, WidgetRef ref, SettingsState settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(
        title: 'Idioma de entrada de voz',
        items: _voiceLanguages
            .map((l) => _PickerItem(
                  leading: Text(l['flag']!, style: const TextStyle(fontSize: 24)),
                  label: l['label']!,
                  value: l['code']!,
                  selected: l['code'] == settings.voiceLanguage,
                ))
            .toList(),
        onSelect: (code) => ref.read(settingsProvider.notifier).setVoiceLanguage(code),
      ),
    );
  }

  /// Picker de moneda
  void _showCurrencyPicker(BuildContext context, WidgetRef ref, SettingsState settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(
        title: 'Moneda principal',
        items: _currencies
            .map((c) => _PickerItem(
                  leading: Text(c['flag']!, style: const TextStyle(fontSize: 24)),
                  label: '${c['label']} (${c['code']})',
                  value: c['code']!,
                  selected: c['code'] == settings.currency,
                ))
            .toList(),
        onSelect: (code) => ref.read(settingsProvider.notifier).setCurrency(code),
      ),
    );
  }

  /// Modal convertidor de moneda
  void _showCurrencyConverterModal(BuildContext context, WidgetRef ref, SettingsState settings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CurrencyConverterModal(settings: settings, ref: ref),
    );
  }

  /// Modal de mejoras de IA
  void _showAIImprovementsModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'Mejoras de IA',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'La IA analiza tus patrones de gasto en tu lista para darte sugerencias personalizadas.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _AIFeatureTile(icon: Icons.trending_down, color: Colors.red, title: 'Detectar gastos inusuales', subtitle: 'Avisos cuando superas tu promedio'),
            _AIFeatureTile(icon: Icons.lightbulb_outline, color: Colors.amber, title: 'Sugerencias de ahorro', subtitle: 'Basadas en tus categorías frecuentes'),
            _AIFeatureTile(icon: Icons.category_outlined, color: Colors.blue, title: 'Categorización automática', subtitle: 'La IA asigna categorías por descripción'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Activar mejoras de IA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Modal Premium
  void _showPremiumModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          left: 28, right: 28, top: 28,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            const Icon(Icons.diamond, color: Color(0xFFFFD700), size: 48),
            const SizedBox(height: 16),
            const Text('iMony Premium', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            const Text('Plan activo — ¡Gracias por tu apoyo!', style: TextStyle(color: Colors.white60, fontSize: 14)),
            const SizedBox(height: 24),
            ...[
              '✅  Sin anuncios',
              '✅  Exportación Excel profesional',
              '✅  Mejoras de IA ilimitadas',
              '✅  Temas y apariencia avanzados',
              '✅  Soporte prioritario',
            ].map((t) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [Text(t, style: const TextStyle(color: Colors.white, fontSize: 15))]),
            )),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Picker de apariencia
  void _showAppearancePicker(BuildContext context, WidgetRef ref, SettingsState settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(
        title: 'Apariencia',
        items: [
          _PickerItem(
            leading: const Icon(Icons.phone_android, size: 24),
            label: 'Sistema (automático)',
            value: 'system',
            selected: settings.themeMode == 'system',
          ),
          _PickerItem(
            leading: const Icon(Icons.light_mode, color: Colors.orange, size: 24),
            label: 'Claro',
            value: 'light',
            selected: settings.themeMode == 'light',
          ),
          _PickerItem(
            leading: const Icon(Icons.dark_mode, color: Colors.indigo, size: 24),
            label: 'Oscuro',
            value: 'dark',
            selected: settings.themeMode == 'dark',
          ),
        ],
        onSelect: (mode) => ref.read(settingsProvider.notifier).setThemeMode(mode),
      ),
    );
  }

  /// Modal de novedades / changelog
  void _showChangelogModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, sc) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(width: 24),
                  const Expanded(
                    child: Text('Novedades', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'v$_appVersion',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  controller: sc,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  children: const [
                    _ChangelogEntry(
                      version: '1.7.0',
                      date: 'Marzo 2026',
                      changes: [
                        '🎙️ Nueva entrada de voz en línea con transcripción en tiempo real',
                        '🌍 Selección de idioma de entrada de voz',
                        '💱 Convertidor de moneda integrado',
                        '🎨 Selector de apariencia: claro, oscuro y sistema',
                        '🤖 Mejoras de IA para categorización automática',
                        '📊 Exportación Excel mejorada con estilos profesionales',
                      ],
                    ),
                    SizedBox(height: 16),
                    _ChangelogEntry(
                      version: '1.6.0',
                      date: 'Febrero 2026',
                      changes: [
                        '🗂️ Editor de categorías con emojis personalizados',
                        '🔄 Transacciones recurrentes',
                        '📝 Gestión de listas múltiples',
                        '💡 Sugerencias de funciones por votación',
                      ],
                    ),
                    SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Modal feedback (ya existía)
  // ─────────────────────────────────────────────────────────────────────
  void _showFeedbackModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final ctrl = TextEditingController();
        return Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Solicitar nueva función',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  '¿Qué te gustaría ver en la próxima actualización?',
                  style: TextStyle(color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: ctrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Ej. Sincronización en la nube, modo familiar...',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (ctrl.text.trim().isNotEmpty) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('¡Gracias por tus sugerencias! Las tomaremos en cuenta.')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Enviar sugerencia', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Exportar / importar (ya existían)
  // ─────────────────────────────────────────────────────────────────────
  void _exportCsv(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(transactionRepositoryProvider);
    final transactions = await repo.getAllTransactions();

    if (transactions.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay transacciones para exportar')));
      }
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('ID,Monto,Tipo,Fecha,Categoria,Descripcion');

    for (var t in transactions) {
      final tipoStr = t.type == 1 ? 'Ingreso' : 'Gasto';
      final isodate = t.date.toIso8601String();
      buffer.writeln('${t.id},${t.amount},$tipoStr,$isodate,${t.categoryName},"${t.description.replaceAll('"', '""')}"');
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV copiado al portapapeles')));
    }
  }

  void _exportExcel(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(transactionRepositoryProvider);
    final transactions = await repo.getAllTransactions();

    if (transactions.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay transacciones para exportar')));
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generando archivo Excel profesional...')));
    }

    var excel = Excel.createExcel();
    Sheet sheetObject = excel[excel.getDefaultSheet()!];

    CellStyle headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.blueGrey,
      leftBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black),
      rightBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black),
      topBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black),
      bottomBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black),
    );

    CellStyle dataStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
      leftBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black),
      rightBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black),
      topBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black),
      bottomBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black),
    );

    CellStyle incomeStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      fontColorHex: ExcelColor.green,
      bold: true,
      leftBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black),
      rightBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black),
      topBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black),
      bottomBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black),
    );

    CellStyle expenseStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      fontColorHex: ExcelColor.red,
      bold: true,
      leftBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black),
      rightBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black),
      topBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black),
      bottomBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black),
    );

    List<String> headers = ['ID', 'Fecha', 'Tipo', 'Categoría', 'Descripción', 'Monto'];
    sheetObject.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (int i = 0; i < headers.length; i++) {
      var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.cellStyle = headerStyle;
    }

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    for (int rowIndex = 0; rowIndex < transactions.length; rowIndex++) {
      var t = transactions[rowIndex];
      final isIncome = t.type == 1;
      final tipoStr = isIncome ? 'Ingreso' : 'Gasto';

      sheetObject.appendRow([
        IntCellValue(t.id),
        TextCellValue(dateFormat.format(t.date)),
        TextCellValue(tipoStr),
        TextCellValue(t.categoryName ?? ''),
        TextCellValue(t.description),
        DoubleCellValue(t.amount),
      ]);

      int actualRowIndex = rowIndex + 1;
      for (int c = 0; c < headers.length; c++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: actualRowIndex));
        if (c == 5) {
          cell.cellStyle = isIncome ? incomeStyle : expenseStyle;
        } else {
          cell.cellStyle = dataStyle;
        }
      }
    }

    sheetObject.setColumnWidth(0, 8);
    sheetObject.setColumnWidth(1, 18);
    sheetObject.setColumnWidth(2, 12);
    sheetObject.setColumnWidth(3, 18);
    sheetObject.setColumnWidth(4, 30);
    sheetObject.setColumnWidth(5, 12);

    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/iMony_Export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file = File(path);
    final bytes = excel.encode();

    if (bytes != null) {
      await file.writeAsBytes(bytes);
      if (context.mounted) {
        await Share.shareXFiles([XFile(path)], text: 'Tus transacciones de iMony');
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al generar el archivo Excel.')));
      }
    }
  }

  void _importCsv(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Pegar CSV'),
          content: TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'Pega aquí tus transacciones en formato CSV'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final text = controller.text;
                if (text.isEmpty) return;
                final repo = ref.read(transactionRepositoryProvider);
                final lines = text.split('\n');
                int count = 0;
                for (var line in lines) {
                  if (line.trim().isEmpty || line.startsWith('ID')) continue;
                  final parts = line.split(',');
                  if (parts.length >= 6) {
                    final amount = double.tryParse(parts[1]) ?? 0.0;
                    final isIncome = parts[2].trim().toLowerCase() == 'ingreso';
                    final date = DateTime.tryParse(parts[3]) ?? DateTime.now();
                    final cat = parts[4];
                    final desc = parts[5].replaceAll('"', '');
                    await repo.addTransaction(
                      amount: amount,
                      category: cat,
                      description: desc,
                      date: date,
                      isIncome: isIncome,
                    );
                    count++;
                  }
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Importadas $count transacciones')));
                }
              },
              child: const Text('Importar'),
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Widgets de items
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 4, bottom: 8, left: 24, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Configuración',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: -0.5),
          ),
          Container(
            decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.black, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    String? emoji,
    IconData? icon,
    Color? iconColor,
    required String title,
    String? subtitle,
    String? badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
              alignment: Alignment.center,
              child: emoji != null
                  ? Text(emoji, style: const TextStyle(fontSize: 24))
                  : Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                          child: Text(
                            badge,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsToggle({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.black54),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: Colors.white,
            activeTrackColor: Colors.green,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget auxiliar: AI Feature Tile
// ─────────────────────────────────────────────────────────────────────────────
class _AIFeatureTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _AIFeatureTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget auxiliar: Picker Sheet genérico
// ─────────────────────────────────────────────────────────────────────────────
class _PickerItem {
  final Widget leading;
  final String label;
  final String value;
  final bool selected;

  const _PickerItem({
    required this.leading,
    required this.label,
    required this.value,
    required this.selected,
  });
}

class _PickerSheet extends StatelessWidget {
  final String title;
  final List<_PickerItem> items;
  final void Function(String) onSelect;

  const _PickerSheet({required this.title, required this.items, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          ...items.map((item) => ListTile(
            leading: item.leading,
            title: Text(item.label, style: const TextStyle(fontSize: 15)),
            trailing: item.selected
                ? const Icon(Icons.check_circle, color: Colors.green)
                : null,
            onTap: () {
              onSelect(item.value);
              Navigator.pop(context);
            },
          )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget: Convertidor de moneda
// ─────────────────────────────────────────────────────────────────────────────
class _CurrencyConverterModal extends StatefulWidget {
  final SettingsState settings;
  final WidgetRef ref;

  const _CurrencyConverterModal({required this.settings, required this.ref});

  @override
  State<_CurrencyConverterModal> createState() => _CurrencyConverterModalState();
}

class _CurrencyConverterModalState extends State<_CurrencyConverterModal> {
  late String _from;
  late String _to;
  final _amountCtrl = TextEditingController(text: '1');
  double _result = 0;

  // Tasas fijas aproximadas respecto al USD (para demo offline)
  static const Map<String, double> _ratesUSD = {
    'USD': 1.0,
    'EUR': 0.92,
    'COP': 4050.0,
    'MXN': 17.5,
    'GBP': 0.79,
    'BRL': 5.1,
    'ARS': 890.0,
    'CLP': 920.0,
    'PEN': 3.75,
    'JPY': 150.0,
  };

  @override
  void initState() {
    super.initState();
    _from = widget.settings.convertFrom;
    _to = widget.settings.convertTo;
    _calculate();
  }

  void _calculate() {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final fromRate = _ratesUSD[_from] ?? 1;
    final toRate = _ratesUSD[_to] ?? 1;
    setState(() {
      _result = amount / fromRate * toRate;
    });
  }

  void _save() {
    widget.ref.read(settingsProvider.notifier).setConvertFrom(_from);
    widget.ref.read(settingsProvider.notifier).setConvertTo(_to);
  }

  String _flagFor(String code) {
    return _currencies.firstWhere((c) => c['code'] == code, orElse: () => _currencies.first)['flag']!;
  }

  @override
  Widget build(BuildContext context) {
    final resultFormatted = NumberFormat('#,##0.00').format(_result);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24, right: 24, top: 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          const Text('Convertidor de moneda', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          // Cantidad
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '0',
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            onChanged: (_) => _calculate(),
          ),
          const SizedBox(height: 20),

          // De / A
          Row(
            children: [
              Expanded(child: _CurrencyDropdown(
                label: 'De',
                value: _from,
                flag: _flagFor(_from),
                onChanged: (v) { setState(() { _from = v; _calculate(); }); },
              )),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      final tmp = _from;
                      _from = _to;
                      _to = tmp;
                      _calculate();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.swap_horiz, color: Colors.black54),
                  ),
                ),
              ),
              Expanded(child: _CurrencyDropdown(
                label: 'A',
                value: _to,
                flag: _flagFor(_to),
                onChanged: (v) { setState(() { _to = v; _calculate(); }); },
              )),
            ],
          ),
          const SizedBox(height: 24),

          // Resultado
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFE8F5E9), Color(0xFFF1F8E9)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  '$resultFormatted $_to',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tasa aproximada (referencia)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _save();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Guardar configuración', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  final String label;
  final String value;
  final String flag;
  final void Function(String) onChanged;

  const _CurrencyDropdown({
    required this.label,
    required this.value,
    required this.flag,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              items: _currencies.map((c) => DropdownMenuItem(
                value: c['code']!,
                child: Row(
                  children: [
                    Text(c['flag']!, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(c['code']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              )).toList(),
              onChanged: (v) { if (v != null) onChanged(v); },
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget: Changelog Entry
// ─────────────────────────────────────────────────────────────────────────────
class _ChangelogEntry extends StatelessWidget {
  final String version;
  final String date;
  final List<String> changes;

  const _ChangelogEntry({required this.version, required this.date, required this.changes});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('v$version', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(width: 10),
            Text(date, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ],
        ),
        const SizedBox(height: 12),
        ...changes.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(c, style: const TextStyle(fontSize: 14, height: 1.4)),
        )),
      ],
    );
  }
}
