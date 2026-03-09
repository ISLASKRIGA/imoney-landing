import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dotted_border/dotted_border.dart';
import '../../core/di/dependency_injection.dart';
import 'category_provider.dart';

class CategoryEditorModal extends ConsumerStatefulWidget {
  const CategoryEditorModal({Key? key}) : super(key: key);

  @override
  _CategoryEditorModalState createState() => _CategoryEditorModalState();
}

class _CategoryEditorModalState extends ConsumerState<CategoryEditorModal> {
  final List<Color> _palette = [
    const Color(0xFFF8BBD0),
    const Color(0xFFFFCC80),
    const Color(0xFFDCEDC8),
    const Color(0xFFE8EAF6),
    const Color(0xFFB3E5FC),
    const Color(0xFFEFEBE9),
    const Color(0xFFCFD8DC),
    const Color(0xFFC5CAE9),
  ];

  // ── Bottom sheet de edición ──────────────────────────────
  void _showEditSheet(BuildContext context, CategoryItem cat, Color color) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CategoryEditSheet(
        category: cat,
        color: color,
        onSave: (newName, newEmoji) {
          ref.read(categoryProvider.notifier).updateCategory(cat.name, newName, newEmoji);
          Navigator.pop(ctx);
        },
        onDelete: () async {
          Navigator.pop(ctx); // cierra el sheet primero
          final repo = ref.read(transactionRepositoryProvider);
          final inUse = await repo.isCategoryInUse(cat.name);
          if (!context.mounted) return;

          if (inUse) {
            showDialog(
              context: context,
              builder: (dlgCtx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text('No se puede eliminar'),
                content: Text(
                  'La categoría "${cat.name}" tiene transacciones asociadas.\n\n'
                  'Recategoriza o elimina esas transacciones primero.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dlgCtx),
                    child: const Text('Entendido'),
                  ),
                ],
              ),
            );
            return;
          }

          showDialog(
            context: context,
            builder: (dlgCtx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Eliminar categoría'),
              content: Text('¿Eliminar "${cat.name}"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dlgCtx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    ref.read(categoryProvider.notifier).removeCategory(cat.name);
                    Navigator.pop(dlgCtx);
                  },
                  child: const Text('Eliminar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Diálogo de añadir ────────────────────────────────────
  void _showAddCategoryDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddCategorySheet(
        onAdd: (name, emoji) {
          ref.read(categoryProvider.notifier).addCategory(name, emoji);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFFDFDFD),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Editar categorías',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Hint
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Icon(Icons.touch_app_outlined, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 6),
                    Text(
                      'Toca una categoría para editarla',
                      style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8)
                      .copyWith(bottom: 120),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 24,
                  ),
                  itemCount: categories.length + 1,
                  itemBuilder: (context, index) {
                    if (index == categories.length) {
                      // Botón Añadir
                      return GestureDetector(
                        onTap: () => _showAddCategoryDialog(context),
                        child: Column(
                          children: [
                            Expanded(
                              child: DottedBorder(
                                color: Colors.grey[300]!,
                                strokeWidth: 2,
                                dashPattern: const [8, 4],
                                borderType: BorderType.RRect,
                                radius: const Radius.circular(20),
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.add, size: 32, color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Añadir',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    }

                    final cat = categories[index];
                    final color = _palette[index % _palette.length];

                    return GestureDetector(
                      // ── TAP → abrir sheet de edición ──
                      onTap: () => _showEditSheet(context, cat, color),
                      child: Column(
                        children: [
                          Expanded(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Tarjeta
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Center(
                                    child: Text(
                                      cat.emoji,
                                      style: const TextStyle(fontSize: 32),
                                    ),
                                  ),
                                ),
                                // Lápiz pequeño en la esquina
                                Positioned(
                                  top: -6,
                                  right: -6,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.12),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      size: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cat.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // Botón Terminar
          Positioned(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1E1E),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    elevation: 10,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check, size: 18),
                      SizedBox(width: 8),
                      Text('Terminar',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
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

// ─────────────────────────────────────────────────────────────
// Sheet de EDICIÓN — sube desde abajo ultra-smooth
// ─────────────────────────────────────────────────────────────
class _CategoryEditSheet extends StatefulWidget {
  final CategoryItem category;
  final Color color;
  final void Function(String name, String emoji) onSave;
  final VoidCallback onDelete;

  const _CategoryEditSheet({
    required this.category,
    required this.color,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends State<_CategoryEditSheet> {
  late final TextEditingController _nameCtrl;
  late String _emoji;

  // Emojis rápidos para elegir
  final List<String> _quickEmojis = [
    '🍔', '🚗', '🛍️', '🎮', '💊', '🥬', '✈️', '🏠',
    '📱', '💡', '🎵', '🐾', '🎓', '💼', '🏋️', '☕',
    '🍕', '🎉', '💰', '🔑', '🛒', '📚', '🌿', '✨',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.category.name);
    _emoji = widget.category.emoji;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Emoji grande + botón cambiar
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Fondo color de la categoría
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: widget.color,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Center(
                          child: Text(_emoji, style: const TextStyle(fontSize: 44)),
                        ),
                      ),
                      // Botón lápiz para desplegar picker
                      Positioned(
                        bottom: -6,
                        right: -6,
                        child: GestureDetector(
                          onTap: _showEmojiPicker,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.edit, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Campo de nombre
                TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Nombre',
                    hintStyle: TextStyle(color: Colors.grey[300], fontSize: 28),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  autofocus: false,
                ),

                const SizedBox(height: 28),

                // Botones: Eliminar | Guardar
                Row(
                  children: [
                    // Eliminar
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text(
                          'Eliminar',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF3B30),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Guardar
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final name = _nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          widget.onSave(name, _emoji);
                        },
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text(
                          'Guardar',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Emoji picker rápido ────────────────────────────────
  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300], borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Elige un emoji',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              // También campo manual
              TextField(
                maxLength: 2,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32),
                decoration: InputDecoration(
                  hintText: '✏️',
                  hintStyle: TextStyle(color: Colors.grey[300], fontSize: 32),
                  counterText: '',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (v) {
                  if (v.isNotEmpty) {
                    setState(() => _emoji = v);
                    Navigator.pop(ctx);
                  }
                },
              ),
              const SizedBox(height: 16),
              // Grid de emojis rápidos
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: _quickEmojis.length,
                itemBuilder: (_, i) {
                  final e = _quickEmojis[i];
                  final selected = e == _emoji;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _emoji = e);
                      Navigator.pop(ctx);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: selected ? Colors.black : Colors.grey[100],
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(e, style: const TextStyle(fontSize: 26)),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sheet de AÑADIR nueva categoría
// ─────────────────────────────────────────────────────────────
class _AddCategorySheet extends StatefulWidget {
  final void Function(String name, String emoji) onAdd;
  const _AddCategorySheet({required this.onAdd});

  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet> {
  final _nameCtrl = TextEditingController();
  String _emoji = '✨';

  final List<String> _quickEmojis = [
    '✨', '🍔', '🚗', '🛍️', '🎮', '💊', '🥬', '✈️',
    '🏠', '📱', '💡', '🎵', '🐾', '🎓', '💼', '🏋️',
    '☕', '🍕', '🎉', '💰', '🔑', '🛒', '📚', '🌿',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300], borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Nueva categoría',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                // Emoji selector horizontal
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _quickEmojis.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final e = _quickEmojis[i];
                      final selected = e == _emoji;
                      return GestureDetector(
                        onTap: () => setState(() => _emoji = e),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: selected ? Colors.black : Colors.grey[100],
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(e, style: const TextStyle(fontSize: 24)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Nombre
                TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: true,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Nombre de la categoría',
                    prefixText: '$_emoji  ',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 20),

                // Botones
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final name = _nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          widget.onAdd(name, _emoji);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 0,
                        ),
                        child: const Text('Agregar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
