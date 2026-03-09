import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/di/dependency_injection.dart';
import '../../core/utils/category_utils.dart';
import '../../data/database/app_database.dart';
import '../transactions/manual_transaction_modal.dart';
import '../../widgets/transaction_list.dart';
import '../settings/settings_modal.dart';
import '../settings/settings_provider.dart';
import '../categories/category_provider.dart';
import '../lists/lists_provider.dart';
import '../lists/user_lists_modal.dart';
import '../../nlp/intent_parser.dart';
import '../../nlp/smart_category_matcher.dart';
import '../../voice/voice_service.dart';
import 'month_picker_modal.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);
  String? _selectedCategoryFilter;
  int? _selectedTypeFilter; // 0 = Egresos, 1 = Ingresos
  DateTime? _selectedMonthFilter = DateTime.now(); // Default to current month

  bool _isSearching = false;
  bool _isSearchExpanded = false;
  bool _showCloseIcon = false;
  static const double _firstTransactionScrollOffset = 320.0;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  // â”€â”€ Settings modal animation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  late final _CurvedAnimController _settingsAnimController;

  // â”€â”€ Inline voice state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  bool _isVoiceActive = false;      // mic pressed â†’ pill is forming
  bool _isVoicePillOpen = false;    // pill fully open, transcript visible
  String _voiceTranscript = '';
  FinanceIntent? _voiceIntent;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      _scrollOffset.value = _scrollController.offset;
    });
    _settingsAnimController = _CurvedAnimController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
      reverseDuration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollOffset.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _settingsAnimController.dispose();
    super.dispose();
  }

  // â”€â”€ Inline voice â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _startVoiceInline() {
    final svc = ref.read(voiceServiceProvider);
    
    // Si estaba buscando, lo cerramos rÃ¡pido
    if (_isSearching) {
      _isSearching = false;
      _isSearchExpanded = false;
      _searchController.clear();
      _searchFocusNode.unfocus();
    }
    
    // FASE 1: mic se achica a cÃ­rculo (igual que la lupa al colapsar)
    setState(() {
      _isVoiceActive = true;
      _voiceTranscript = '';
      _voiceIntent = null;
      _isVoicePillOpen = false;
    });

    // FASE 2: despuÃ©s de 700ms (colapso terminado) â†’ expandir hacia izquierda
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted && _isVoiceActive) {
        setState(() => _isVoicePillOpen = true);
        // La burbuja de texto aparece una vez que terminÃ³ la expansiÃ³n (~900ms)
      }
    });

    svc.partialTextStream.listen((text) {
      if (!mounted || !_isVoiceActive) return;
      setState(() {
        _voiceTranscript = text;
        final intent = ref.read(intentParserProvider).parse(text);
        if (intent.action != IntentAction.unknown) _voiceIntent = intent;
      });
    });

    svc.statusStream.listen((status) {
      if (!mounted) return;
      if (status == VoiceStatus.idle && _voiceIntent == null) {
        _stopVoiceInline();
      }
    });
    svc.startListening();
  }

  void _stopVoiceInline() {
    ref.read(voiceServiceProvider).stopListening();
    setState(() => _isVoicePillOpen = false);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isVoiceActive = false;
          _voiceTranscript = '';
          _voiceIntent = null;
        });
      }
    });
  }

  Future<void> _confirmVoice() async {
    if (_voiceIntent == null) return;
    final repo   = ref.read(transactionRepositoryProvider);
    final intent = _voiceIntent!;
    _stopVoiceInline();

    // Resolver categorÃ­a real del usuario con SmartCategoryMatcher
    final matcher      = ref.read(smartCategoryMatcherProvider);
    final normalizedTx = (_voiceTranscript)
        .toLowerCase()
        .replaceAll('Ã¡','a').replaceAll('Ã©','e').replaceAll('Ã­','i')
        .replaceAll('Ã³','o').replaceAll('Ãº','u');
    final resolvedCat  = matcher.match(normalizedTx, intent.category);
    final catName      = resolvedCat?.name ?? intent.category ?? (intent.action == IntentAction.create_income ? 'Ingresos' : 'General');

    try {
      await repo.addTransaction(
        amount:      intent.amount ?? 0,
        category:    catName,
        description: intent.description ?? (intent.action == IntentAction.create_income ? 'Ingreso' : 'Gasto'),
        date:        intent.date ?? DateTime.now(),
        isIncome:    intent.action == IntentAction.create_income,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('âœ… ${resolvedCat?.emoji ?? ''} Guardado en $catName'),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionRepository = ref.watch(transactionRepositoryProvider);
    // Lista activa: null = Lista Privada, int = lista del usuario
    final activeList = ref.watch(activeListProvider);
    final activeListId = activeList?.id; // null -> Lista Privada

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F9),
      resizeToAvoidBottomInset: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: const Color(0xFFF6F6F9),
        ),
        // â”€â”€ Stream filtrado por lista activa â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        child: StreamBuilder<List<Transaction>>(
          // Cuando activeList cambia, el stream se reconstruye automÃ¡ticamente
          stream: transactionRepository.watchTransactionsByList(activeListId),
          builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          final settings = ref.watch(settingsProvider);
          
          Iterable<Transaction> filteredData = data;
          if (_selectedMonthFilter != null) {
            filteredData = data.where((t) => t.date.year == _selectedMonthFilter!.year && t.date.month == _selectedMonthFilter!.month);
          }

          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            filteredData = filteredData.where((t) => 
              t.description.toLowerCase().contains(q) || 
              (t.categoryName ?? '').toLowerCase().contains(q)
            );
          }

          final displayData = filteredData.toList();
          
          Iterable<Transaction> tempFiltered = displayData;
          if (_selectedCategoryFilter != null) {
            tempFiltered = tempFiltered.where((t) => (t.categoryName ?? 'Otros').trim() == _selectedCategoryFilter);
          }
          if (_selectedTypeFilter != null) {
            tempFiltered = tempFiltered.where((t) => t.type == _selectedTypeFilter);
          }
          final listData = tempFiltered.toList();

          // ── Balance del header ─────────────────────────────────
          // • Acumulado ON  → suma todos los meses (data completo)
          // • Acumulado OFF → solo el mes seleccionado (displayData)
          final headerSource = settings.accumulated ? data : displayData;

          final totalIncome = headerSource
              .where((t) => t.type == 1)
              .fold(0.0, (sum, t) => sum + t.amount);
          final totalExpense = headerSource
              .where((t) => t.type == 0)
              .fold(0.0, (sum, t) => sum + t.amount);

          final balance = totalIncome - totalExpense;

          return CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // â”€â”€ Header fijo (balance + configuraciÃ³n) â”€â”€
              SliverPersistentHeader(
                pinned: true,
                delegate: _BalanceHeaderDelegate(
                  balance: balance,
                  totalIncome: totalIncome,
                  totalExpense: totalExpense,
                  onSettingsPressed: () => _showSettings(context),
                  topPadding: MediaQuery.of(context).padding.top,
                  showIncome: settings.showIncome,
                  accumulated: settings.accumulated,
                  selectedTypeFilter: _selectedTypeFilter,
                  onTypeFilterChanged: (type) {
                    setState(() {
                      if (_selectedTypeFilter == type) {
                        _selectedTypeFilter = null;
                      } else {
                        _selectedTypeFilter = type;
                        _selectedCategoryFilter = null; // Quitar filtro de categoría al filtrar por tipo
                      }
                    });
                  },
                ),
              ),

              // â”€â”€ GrÃ¡fica de barras â”€â”€
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: SizedBox(
                    height: 260,
                    child: _buildBarChart(displayData, ref.watch(categoryProvider)),
                  ),
                ),
              ),

              // â”€â”€ Encabezado de lista â”€â”€
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category label slides from top and pushes pills down
                      AnimatedSize(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOutCubic,
                        alignment: Alignment.topCenter,
                        child: _selectedCategoryFilter != null
                            ? TweenAnimationBuilder<Offset>(
                                key: ValueKey(_selectedCategoryFilter),
                                tween: Tween(
                                  begin: const Offset(0, -1),
                                  end: Offset.zero,
                                ),
                                duration: const Duration(milliseconds: 700),
                                curve: Curves.easeInOutCubic,
                                builder: (context, offset, child) {
                                  return FractionalTranslation(
                                    translation: offset,
                                    child: child,
                                  );
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedCategoryFilter!,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      // Pills row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildInfoPill(
                              _monthFilterText,
                              Icons.calendar_today_outlined,
                              () => _showMonthPicker(data),
                            ),
                            const SizedBox(width: 8),
                            Builder(builder: (context) {
                              final activeList = ref.watch(activeListProvider);
                              final listName = activeList != null
                                  ? '${activeList.emoji} ${activeList.name}'
                                  : 'ðŸ”’ Lista Privada';
                              return _buildInfoPill(
                                listName,
                                Icons.keyboard_arrow_down,
                                () => showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => const UserListsModal(),
                                ),
                              );
                            }),
                            if (_selectedCategoryFilter != null) ...[ 
                              const SizedBox(width: 8),
                              _buildInfoPill('${listData.length} transax.', Icons.list),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // â”€â”€ Lista de transacciones â”€â”€
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: _isSearchExpanded
                      ? (MediaQuery.of(context).viewInsets.bottom + 120)
                      : 110,
                ),
                sliver: listData.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Column(
                            children: [
                              const Text('ðŸ¤‘',
                                  style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              Text(
                                'Sin transacciones aÃºn',
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final t = listData[index];
                            
                            bool showHeader = false;
                            if (index == 0) {
                              showHeader = true;
                            } else {
                              final prev = listData[index - 1];
                              if (t.date.year != prev.date.year || t.date.month != prev.date.month || t.date.day != prev.date.day) {
                                showHeader = true;
                              }
                            }

                            Widget transactionWidget = TransactionItem(
                              transaction: t,
                              onDelete: () => transactionRepository.deleteTransaction(t.id),
                            );

                            if (showHeader) {
                              final now = DateTime.now();
                              final isToday = t.date.year == now.year && t.date.month == now.month && t.date.day == now.day;
                              final dateStr = isToday ? 'Hoy' : DateFormat('dd MMM yyyy', 'es_ES').format(t.date);
                              
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 4),
                                    child: Text(
                                      dateStr.toUpperCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.grey[500],
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  transactionWidget,
                                ],
                              );
                            }
                            return transactionWidget;
                          },
                          childCount: listData.length,
                        ),
                      ),
              ),
            ],
          );
        },
      )),
      // â”€â”€ Bottom UI: voice transcript + bar â”€â”€
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Voice transcript + intent card â€” floats above the bar
          if (_isVoiceActive) _buildVoiceBubble(context),
          _buildCustomBottomBar(context),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // â”€â”€ GrÃ¡fica de barras â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildBarChart(List<Transaction> data, List<CategoryItem> savedCategories) {
    final expenses = data.where((t) => t.type == 0).toList();

    // â”€â”€ 1. Todas las categorÃ­as del usuario, inicializadas en 0
    final Map<String, double> categorySums = {};
    for (final cat in savedCategories) {
      categorySums[cat.name] = 0.0;
    }

    // â”€â”€ 2. Acumular gastos reales
    for (var t in expenses) {
      final key = (t.categoryName ?? 'Otros').trim();
      categorySums[key] = (categorySums[key] ?? 0.0) + t.amount;
    }

    // â”€â”€ 3. Ordenar: con monto (desc) + sin monto (alfabÃ©tico)
    final withAmount = categorySums.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final withoutAmount = categorySums.entries.where((e) => e.value == 0).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final sortedKeys = [
      ...withAmount.map((e) => e.key),
      ...withoutAmount.map((e) => e.key),
    ];

    final maxAmount = withAmount.isNotEmpty ? withAmount.first.value : 0.0;

    final palette = [
      const Color(0xFFB4AEE8), const Color(0xFF90CAF9),
      const Color(0xFFFFCC80), const Color(0xFFB3E5FC),
      const Color(0xFFFFCDD2), const Color(0xFF81C784),
      const Color(0xFFF48FB1), const Color(0xFFCE93D8),
      const Color(0xFFA5D6A7), const Color(0xFFFFE082),
      const Color(0xFF80DEEA), const Color(0xFFEF9A9A),
    ];

    return ValueListenableBuilder<double>(
      valueListenable: _scrollOffset,
      builder: (context, offset, child) {
        final actualMaxBarHeight = maxAmount > 0 ? 200.0 : 60.0;
        
        // El choque ocurre exactamente cuando la punta de la barra mÃ¡s alta alcanza
        // el borde inferior del header (donde estÃ¡n posicionadas las pastillitas).
        // 24 (padding top) + 220 (altura del SizedBox) - actualMaxBarHeight = Distancia al borde
        final touchOffset = 24.0 + (220.0 - actualMaxBarHeight);
        final overlap = offset > touchOffset ? (offset - touchOffset) : 0.0;
        
        double scale = (actualMaxBarHeight - overlap) / actualMaxBarHeight;
        if (scale < 0) scale = 0.0;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: sortedKeys.length < 5 ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: sortedKeys.asMap().entries.map((entry) {
              final i = entry.key;
              final cat = entry.value;
              final amt = categorySums[cat]!;
              final isEmpty = amt == 0;

              final emoji = savedCategories.firstWhere(
                (c) => c.name == cat,
                orElse: () => CategoryItem(name: '', emoji: CategoryUtils.getEmoji(cat)),
              ).emoji;

              final heightRatio = maxAmount > 0 ? amt / maxAmount : 0.0;
              final baseBarHeight = isEmpty ? 36.0 : 60.0 + (140.0 * heightRatio);
              final scaledHeight = baseBarHeight * scale;

              String textAmt;
              if (isEmpty) {
                textAmt = '0';
              } else if (amt >= 1000) {
                textAmt = '${(amt / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
              } else {
                textAmt = amt.toInt().toString();
              }

              final isSelected = _selectedCategoryFilter == cat;
              final opacity = _selectedCategoryFilter == null
                  ? (isEmpty ? 0.38 : 1.0)
                  : (isSelected ? 1.0 : 0.3);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (_selectedCategoryFilter == cat) {
                      _selectedCategoryFilter = null;
                    } else {
                      _selectedCategoryFilter = cat;
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Monto sobre la barra
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          textAmt,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isEmpty ? FontWeight.w400 : FontWeight.bold,
                            color: isEmpty ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),
                      // Barra
                      Opacity(
                        opacity: opacity,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          width: 54,
                          height: scaledHeight.clamp(36.0, 200.0),
                          decoration: BoxDecoration(
                            color: palette[i % palette.length],
                            borderRadius: BorderRadius.circular(27),
                            border: isSelected
                                ? Border.all(color: Colors.black87, width: 2)
                                : isEmpty
                                    ? Border.all(color: Colors.grey[300]!, width: 1.5)
                                    : null,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                emoji,
                                style: TextStyle(fontSize: isEmpty ? 14 : 16),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Nombre debajo
                      const SizedBox(height: 5),
                      SizedBox(
                        width: 60,
                        child: Text(
                          cat,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.black87 : Colors.grey[500],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }
    );
  }

  // â”€â”€ Barra inferior â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Estado extra para la animaciÃ³n del mic (equivalente a _isSearching)
  bool get _isMicCollapsing => _isVoiceActive && !_isVoicePillOpen;

  Widget _buildCustomBottomBar(BuildContext context) {
    final totalWidth = MediaQuery.of(context).size.width;
    // Ancho de la pastilla del mic:
    //   Reposo            â†’ 70
    //   Fase 1 (colapso)  â†’ 60  (se achica como un cÃ­rculo, dur 700ms)
    //   Fase 2 (expansiÃ³n)â†’ toda la barra menos mÃ¡rgenes (dur 900ms)
    final micWidth = _isVoicePillOpen
        ? totalWidth - 48.0            // expandido
        : (_isVoiceActive ? 60.0 : 70.0); // colapsando â†’ cÃ­rculo

    // Ancho de la pastilla izquierda:
    //   Se aplasta a 0 durante la FASE 2 (expansiÃ³n del mic)
    final leftWidth = _isVoicePillOpen
        ? 0.0
        : (!_isSearching
            ? 120.0
            : (!_isSearchExpanded
                ? 60.0
                : totalWidth * 0.65));

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AnimatedContainer(
            height: 60,
            width: leftWidth,
            duration: Duration(milliseconds: _isVoicePillOpen ? 900 : (_isSearching && !_isSearchExpanded ? 700 : 900)),
            curve: Curves.easeInOutQuart,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                )
              ],
            ),
            // Stack: layered so the icon glides over the top of the other content
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // â”€â”€ ADD BUTTON â€” visible y clickeable solo cuando no se busca
                IgnorePointer(
                  ignoring: _isSearching,
                  child: AnimatedOpacity(
                    opacity: _isSearching ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.add, color: Colors.black),
                        onPressed: () => _showManualInput(context),
                      ),
                    ),
                  ),
                ),

                // â”€â”€ SEARCH TEXT FIELD â€” solo activo cuando expandido
                IgnorePointer(
                  ignoring: !_isSearchExpanded,
                  child: AnimatedOpacity(
                    opacity: _isSearchExpanded ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 400),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 52),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: const InputDecoration(
                            hintText: 'Buscar...',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                 // â”€â”€ SEARCH / CLOSE ICON â€” slides across the pill â”€â”€
                AnimatedAlign(
                  alignment: (!_isSearching || _isSearchExpanded)
                      ? Alignment.centerRight
                      : Alignment.center,
                  duration: Duration(milliseconds: _isSearching && !_isSearchExpanded ? 700 : 300),
                  curve: Curves.easeInOutQuart,
                  child: GestureDetector(
                    onTap: () {
                      if (_isSearching) {
                        // Close: hide X immediately, collapse bar
                        _searchFocusNode.unfocus();
                        setState(() {
                          _showCloseIcon = false;   // X fades out instantly
                          _isSearchExpanded = false;
                        });
                        Future.delayed(const Duration(milliseconds: 700), () {
                          if (mounted) {
                            setState(() {
                              _isSearching = false;
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          }
                        });
                      } else {
                        // Open step 1: collapse pill â†’ circle, lupa slides left
                        setState(() { _isSearching = true; });
                        // Open step 2: expand circle â†’ full bar
                        Future.delayed(const Duration(milliseconds: 700), () {
                          if (mounted && _isSearching) {
                            setState(() { _isSearchExpanded = true; });
                            // Step 2b: wait for lupa to fully fade (280ms) then show X
                            Future.delayed(const Duration(milliseconds: 280), () {
                              if (mounted && _isSearchExpanded) {
                                setState(() { _showCloseIcon = true; });
                              }
                            });
                            // Open step 3: keyboard after bar finishes expanding
                            Future.delayed(const Duration(milliseconds: 900), () {
                              if (mounted && _isSearchExpanded) {
                                _searchFocusNode.requestFocus();
                                // Scroll smoothly so first transaction is visible
                                Future.delayed(const Duration(milliseconds: 400), () {
                                  if (mounted && _scrollController.hasClients) {
                                    _scrollController.animateTo(
                                      _firstTransactionScrollOffset,
                                      duration: const Duration(milliseconds: 1400),
                                      curve: Curves.easeInOutCubic,
                                    );
                                  }
                                });
                              }
                            });
                          }
                        });
                      }
                    },
                    // Two icons stacked; they fade sequentially â€” never both visible
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Lupa: fades out as soon as bar is expanded
                          AnimatedOpacity(
                            opacity: _isSearchExpanded ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 250),
                            child: const Icon(Icons.search, color: Colors.black),
                          ),
                          // X: only appears AFTER lupa has fully disappeared
                          AnimatedOpacity(
                            opacity: _showCloseIcon ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeIn,
                            child: const Icon(Icons.close, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // â”€â”€ MIC / VOICE PILL â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          GestureDetector(
            onTap: _isVoiceActive ? null : _startVoiceInline,
            onLongPress: _isVoiceActive ? null : _startVoiceInline,
            child: AnimatedContainer(
              height: 60,
              width: micWidth,
              duration: Duration(
                  milliseconds: _isVoicePillOpen
                      ? 900  // Fase 2: expansiÃ³n lenta hacia la izquierda
                      : (_isVoiceActive ? 700 : 500)), // Fase 1: colapso / vuelta
              curve: Curves.easeInOutQuart,
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5252)
                        .withValues(alpha: _isVoiceActive ? 0.55 : 0.4),
                    blurRadius: _isVoiceActive ? 22 : 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // â”€â”€ MIC ICON â€” desliza de centerRight â†’ centerLeft
                  //    igual que la lupa desliza de right â†’ center
                  AnimatedAlign(
                    alignment: _isVoicePillOpen
                        ? Alignment.centerLeft   // expandido: va a la izquierda
                        : Alignment.center,       // reposo / colapso: centro
                    duration: Duration(
                        milliseconds: _isVoicePillOpen ? 900 : 300),
                    curve: Curves.easeInOutQuart,
                    child: Padding(
                      padding: EdgeInsets.only(
                          left: _isVoicePillOpen ? 18 : 0),
                      child: const Icon(Icons.mic,
                          color: Colors.white, size: 30),
                    ),
                  ),
                  // â”€â”€ CLOSE BUTTON â€” solo activo cuando la pill estÃ¡ expandida
                  IgnorePointer(
                    ignoring: !_isVoicePillOpen,
                    child: AnimatedOpacity(
                      opacity: _isVoicePillOpen ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeIn,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: GestureDetector(
                            onTap: _stopVoiceInline,
                            child: const Icon(Icons.close,
                                color: Colors.white70, size: 22),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  void _showManualInput(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ManualTransactionModal(),
    );
  }



  void _showSettings(BuildContext context) {
    // Reset y arranca con curva ultra-smooth
    _settingsAnimController.reset();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: false,
      enableDrag: true,
      barrierColor: Colors.black.withOpacity(0.4),
      // transitionAnimationController: Flutter usa este controller para el slide
      // Al pasarle el nuestro (700ms, easeOutCubic vÃ­a forma de la curva)
      // conseguimos el efecto ultra-smooth.
      transitionAnimationController: _settingsAnimController,
      builder: (context) => const SettingsModal(),
    );
  }

  String _getMonthName(int month) {
    const months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return months[month - 1];
  }

  String get _monthFilterText {
    if (_selectedMonthFilter == null) return 'Todo el tiempo';
    final now = DateTime.now();
    if (_selectedMonthFilter!.year == now.year && _selectedMonthFilter!.month == now.month) return 'Este mes';
    return '${_getMonthName(_selectedMonthFilter!.month)} ${_selectedMonthFilter!.year}';
  }

  void _showMonthPicker(List<Transaction> allTransactions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MonthPickerModal(
        initialSelectedMonth: _selectedMonthFilter,
        allTransactions: allTransactions,
        onApply: (selectedMonth) {
          setState(() { _selectedMonthFilter = selectedMonth; });
          Navigator.pop(context);
        },
      ),
    );
  }

  // Voice bubble floats above the bottom bar showing real-time transcript
  Widget _buildVoiceBubble(BuildContext context) {
    final hasIntent = _voiceIntent != null && _voiceIntent!.amount != null;
    final isExpense = _voiceIntent?.action != IntentAction.create_income;
    final color = hasIntent
        ? (isExpense ? const Color(0xFFFF5252) : const Color(0xFF4CAF50))
        : const Color(0xFF7C4DFF);
    final amountStr = hasIntent
        ? '${isExpense ? "-" : "+"}\$${_voiceIntent!.amount?.toStringAsFixed(0)}'
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        alignment: Alignment.bottomCenter,
        child: _isVoicePillOpen
            ? TweenAnimationBuilder<Offset>(
                tween: Tween(begin: const Offset(0, 0.3), end: Offset.zero),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (ctx, offset, child) =>
                    FractionalTranslation(translation: offset, child: child),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Real-time transcript text
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: Text(
                          _voiceTranscript.isEmpty
                              ? 'Di algo...'
                              : '"$_voiceTranscript"',
                          key: ValueKey(_voiceTranscript),
                          style: TextStyle(
                            fontSize: 15,
                            fontStyle: _voiceTranscript.isEmpty
                                ? FontStyle.normal
                                : FontStyle.italic,
                            color: _voiceTranscript.isEmpty
                                ? Colors.grey[400]
                                : Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ),
                      // Detected intent slides in below transcript
                      AnimatedSize(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOutCubic,
                        child: hasIntent
                            ? Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _voiceIntent!.description ?? '',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14),
                                          ),
                                          Text(
                                            _voiceIntent!.category ?? '',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[500]),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      amountStr,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: _confirmVoice,
                                      child: Container(
                                        padding: const EdgeInsets.all(9),
                                        decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle),
                                        child: const Icon(Icons.check,
                                            color: Colors.white, size: 18),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildInfoPill(String text, IconData icon, [VoidCallback? onTap]) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey[500]),
        ],
      ),
    ),
   );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// BotÃ³n de micrÃ³fono con tap + long press + feedback visual
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _MicButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _MicButton({required this.onPressed});

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> {
  bool _pressed = false;

  void _handlePress() {
    setState(() => _pressed = true);
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _pressed = false);
    });
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handlePress,
      onLongPress: _handlePress,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          height: 70,
          width: 70,
          decoration: BoxDecoration(
            color: const Color(0xFFFF5252),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF5252).withValues(alpha: _pressed ? 0.2 : 0.4),
                blurRadius: _pressed ? 6 : 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.mic, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// SliverPersistentHeaderDelegate â€” Header fijo con balance
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _BalanceHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double balance;
  final double totalIncome;
  final double totalExpense;
  final VoidCallback onSettingsPressed;
  final double topPadding;
  final bool showIncome;
  final bool accumulated;
  final int? selectedTypeFilter;
  final ValueChanged<int> onTypeFilterChanged;

  const _BalanceHeaderDelegate({
    required this.balance,
    required this.totalIncome,
    required this.totalExpense,
    required this.onSettingsPressed,
    required this.topPadding,
    required this.showIncome,
    required this.accumulated,
    required this.selectedTypeFilter,
    required this.onTypeFilterChanged,
  });

  @override
  double get maxExtent => 260.0 + topPadding; // Push content further down

  @override
  double get minExtent => 260.0 + topPadding;

  @override
  bool shouldRebuild(_BalanceHeaderDelegate old) =>
      old.balance != balance ||
      old.totalIncome != totalIncome ||
      old.totalExpense != totalExpense ||
      old.topPadding != topPadding ||
      old.showIncome != showIncome ||
      old.accumulated != accumulated ||
      old.selectedTypeFilter != selectedTypeFilter;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF6F6F9),
            const Color(0xFFF6F6F9),
            const Color(0xFFF6F6F9).withValues(alpha: 0.0),
            const Color(0xFFF6F6F9).withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.78, 0.92, 1.0], // Fade starts right as elements touch the pills
        ),
      ),
      child: Stack(
        children: [
          // Settings button top right
          Positioned(
            top: topPadding + 64, // Pushed lower but resting above the main amount
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                ]
              ),
              child: IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.black),
                onPressed: onSettingsPressed,
              ),
            ),
          ),
          
          // Center Content
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 25.0), // Allows pills to sit right before the transparent gradient
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // TOTAL label
                  Text(
                    accumulated ? 'TOTAL ACUMULADO' : 'TOTAL',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.4,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  
                  // Amount row with subtle gradient glow
                  Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        child: Container(
                          width: 140,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.9),
                                blurRadius: 40,
                                spreadRadius: 30,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0, right: 4.0),
                            child: Text(
                              '\$',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: const TextStyle(
                              fontSize: 58, // large numbers
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: -1.0,
                              height: 1.1,
                            ),
                            child: Text(
                              NumberFormat('#,##0.00', 'en_US').format(balance),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Pills
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildPill(totalExpense, false, selectedTypeFilter == 0, () => onTypeFilterChanged(0)),
                      if (showIncome) ...[
                        const SizedBox(width: 12),
                        _buildPill(totalIncome, true, selectedTypeFilter == 1, () => onTypeFilterChanged(1)),
                      ]
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(double amount, bool isIncome, bool isSelected, VoidCallback onTap) {
    final color = isIncome ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
    final amtString = NumberFormat('#,##0.00', 'en_US').format(amount);
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color, width: isSelected ? 0 : 1.5),
          boxShadow: isSelected 
              ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isIncome ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: isSelected ? Colors.white : color),
            const SizedBox(width: 5),
            Text(
              '\$$amtString',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? Colors.white : color),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// AnimationController que aplica una curva easeOutCubic al valor
// devuelto, consiguiendo un slide ultra-smooth en showModalBottomSheet
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _CurvedAnimController extends AnimationController {
  final Curve curve;
  final Curve reverseCurve;

  _CurvedAnimController({
    required super.vsync,
    required super.duration,
    super.reverseDuration,
    this.curve = Curves.easeOutCubic,
    this.reverseCurve = Curves.easeInCubic,
  });

  @override
  double get value {
    final raw = super.value;
    // Al avanzar (forward) usamos curve; al retroceder usamos reverseCurve
    if (status == AnimationStatus.reverse || status == AnimationStatus.dismissed) {
      return reverseCurve.transform(raw);
    }
    return curve.transform(raw);
  }
}

