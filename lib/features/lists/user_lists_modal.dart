import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import 'lists_provider.dart';

class UserListsModal extends ConsumerStatefulWidget {
  const UserListsModal({Key? key}) : super(key: key);

  @override
  ConsumerState<UserListsModal> createState() => _UserListsModalState();
}

class _UserListsModalState extends ConsumerState<UserListsModal> {
  bool _showForm = false;
  final _nameCtrl = TextEditingController();
  String _selectedEmoji = '📋';

  final List<String> _emojiOptions = [
    '📋', '💰', '🏠', '✈️', '🎉', '🍕', '💼', '🎓',
    '🏋️', '🛒', '💊', '🎮', '🚗', '📱', '🐾', '🌿',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un nombre para la lista')),
      );
      return;
    }
    await ref.read(listsNotifierProvider.notifier).add(
      name: name,
      emoji: _selectedEmoji,
    );
    _nameCtrl.clear();
    setState(() {
      _showForm = false;
      _selectedEmoji = '📋';
    });
  }

  @override
  Widget build(BuildContext context) {
    final listsState = ref.watch(listsNotifierProvider);
    final activeList = ref.watch(activeListProvider);
    final topPad = MediaQuery.of(context).padding.top;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      snap: true,
      snapSizes: const [0.7],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tus listas',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                    Row(children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _showForm
                            ? const SizedBox.shrink()
                            : Container(
                                key: const ValueKey('add_list_btn'),
                                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
                                child: TextButton.icon(
                                  onPressed: () => setState(() => _showForm = true),
                                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                                  label: const Text('Nueva', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),

              // Body
              Expanded(
                child: ListView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  children: [
                    // ── Formulario ───────────────────────
                    AnimatedSize(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOutCubic,
                      child: _showForm ? _buildForm() : const SizedBox.shrink(),
                    ),

                    // ── Lista privada (default) ───────────
                    _buildListTile(
                      name: 'Lista Privada',
                      emoji: '🔒',
                      isDefault: true,
                      isActive: activeList == null,
                      onTap: () {
                        ref.read(activeListProvider.notifier).select(null);
                        Navigator.pop(context);
                      },
                    ),

                    const Divider(height: 20),

                    // ── Listas del usuario ────────────────
                    listsState.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Text('Error: $e'),
                      data: (lists) {
                        if (lists.isEmpty && !_showForm) {
                          return _buildEmptyHint();
                        }
                        return Column(
                          children: lists
                              .map((l) => _buildListTile(
                                    name: l.name,
                                    emoji: l.emoji,
                                    isActive: activeList?.id == l.id,
                                    onTap: () {
                                      ref.read(activeListProvider.notifier).select(l);
                                      Navigator.pop(context);
                                    },
                                    onDelete: () => _confirmDelete(l),
                                  ))
                              .toList(),
                        );
                      },
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

  Widget _buildEmptyHint() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text('📋', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          Text(
            'Crea tu primera lista personalizada',
            style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ── Tile de lista ────────────────────────────────────────
  Widget _buildListTile({
    required String name,
    required String emoji,
    bool isDefault = false,
    required bool isActive,
    required VoidCallback onTap,
    VoidCallback? onDelete,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.black : Colors.grey.withOpacity(0.15),
            width: isActive ? 0 : 1,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.white : Colors.black87,
                  ),
                ),
                if (isDefault)
                  Text(
                    'Por defecto',
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive ? Colors.white54 : Colors.grey[400],
                    ),
                  ),
              ],
            ),
          ),
          if (isActive)
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22)
          else if (onDelete != null)
            GestureDetector(
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.delete_outline, color: Colors.grey[400], size: 20),
              ),
            ),
        ]),
      ),
    );
  }

  // ── Formulario nueva lista ───────────────────────────────
  Widget _buildForm() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FB),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nueva lista', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),

          // Emoji picker
          const Text('Elige un emoji', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _emojiOptions.map((e) {
              final selected = e == _selectedEmoji;
              return GestureDetector(
                onTap: () => setState(() => _selectedEmoji = e),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: selected ? Colors.black : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? Colors.black : Colors.grey.withOpacity(0.2)),
                  ),
                  child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Nombre
          TextFormField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Nombre de la lista',
              filled: true,
              fillColor: Colors.white,
              prefixText: '$_selectedEmoji  ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.black, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),

          // Botones
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() { _showForm = false; _nameCtrl.clear(); }),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Crear lista', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  void _confirmDelete(UserList list) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Eliminar lista?'),
        content: Text('Se eliminará "${list.emoji} ${list.name}" permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(listsNotifierProvider.notifier).delete(list.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
