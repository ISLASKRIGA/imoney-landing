import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dotted_border/dotted_border.dart';
import 'category_provider.dart';

class CategoryPickerModal extends ConsumerStatefulWidget {
  final String? initialCategory;
  
  const CategoryPickerModal({Key? key, this.initialCategory}) : super(key: key);

  @override
  _CategoryPickerModalState createState() => _CategoryPickerModalState();
}

class _CategoryPickerModalState extends ConsumerState<CategoryPickerModal> {
  String? _selectedCategory;

  final List<Color> _palette = [
    const Color(0xFFF8BBD0), // pastel pink
    const Color(0xFFFFCC80), // pastel orange
    const Color(0xFFDCEDC8), // pastel light green
    const Color(0xFFE8EAF6), // pastel purple-grey
    const Color(0xFFB3E5FC), // pastel blue
    const Color(0xFFEFEBE9), // pastel brown
    const Color(0xFFCFD8DC), // pastel grey
    const Color(0xFFC5CAE9), // pastel purple
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  void _showAddCategoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final nameCtrl = TextEditingController();
        final emojiCtrl = TextEditingController();
        return AlertDialog(
          title: const Text('Nueva Categoría'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre (ej. Suscripciones)',
                  hintText: 'Nombre de la categoría',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emojiCtrl,
                decoration: const InputDecoration(
                  labelText: 'Emoji (ej. 📺)',
                  hintText: 'Opcional',
                ),
                maxLength: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final emoji = emojiCtrl.text.trim().isNotEmpty ? emojiCtrl.text.trim() : '✨';
                if (name.isNotEmpty) {
                  ref.read(categoryProvider.notifier).addCategory(name, emoji);
                  setState(() => _selectedCategory = name);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('Agregar'),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFFDFDFD), // Very light grey/white
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
                      'Elige tus categorías',
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
                        onPressed: () => Navigator.pop(context, null), // Return null if closed
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8).copyWith(bottom: 120),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 24,
                  ),
                  itemCount: categories.length + 1, // +1 for the Add button
                  itemBuilder: (context, index) {
                    if (index == categories.length) {
                      // Add Button
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
                              'Añadir categoría',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    }

                    final cat = categories[index];
                    final isSelected = _selectedCategory == cat.name;
                    final color = _palette[index % _palette.length];

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = cat.name;
                        });
                      },
                      child: Column(
                        children: [
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(20),
                                border: isSelected ? Border.all(color: Colors.black, width: 3) : Border.all(color: Colors.transparent, width: 3),
                                boxShadow: isSelected ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ] : [],
                              ),
                              child: Center(
                                child: Text(cat.emoji, style: const TextStyle(fontSize: 32)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cat.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
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
          
          // Save Button fixed at the bottom
          Positioned(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Return selected category to caller
                    Navigator.pop(context, _selectedCategory);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1E1E), // Dark button
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    elevation: 10,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.arrow_forward, size: 18),
                      SizedBox(width: 8),
                      Text('Guardar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
