import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/database/app_database.dart';
import '../../core/di/dependency_injection.dart';
import '../../data/repositories/transaction_repository.dart';
import '../categories/category_provider.dart';
import '../categories/category_picker_modal.dart';
import '../lists/lists_provider.dart';

class ManualTransactionModal extends ConsumerStatefulWidget {
  final Transaction? transaction;
  const ManualTransactionModal({Key? key, this.transaction}) : super(key: key);

  @override
  _ManualTransactionModalState createState() => _ManualTransactionModalState();
}

class _ManualTransactionModalState extends ConsumerState<ManualTransactionModal> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _tagController = TextEditingController();
  
  String _selectedCategory = 'Comida'; // Default
  DateTime _selectedDate = DateTime.now();
  bool _isIncome = false;
  
  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      final desc = widget.transaction!.description;
      final tagMatch = RegExp(r'(.*)\s+#([^\s]+)$').firstMatch(desc);
      if (tagMatch != null) {
        _descriptionController.text = tagMatch.group(1) ?? '';
        _tagController.text = tagMatch.group(2) ?? '';
      } else {
        _descriptionController.text = desc;
      }

      _amountController.text = widget.transaction!.amount.toString();
      _selectedCategory = widget.transaction?.categoryName ?? 'Comida';
      _selectedDate = widget.transaction!.date;
      _isIncome = widget.transaction!.type == 1;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _saveTransaction() async {
    final rawDescription = _descriptionController.text.trim();
    final rawTag = _tagController.text.trim().replaceAll('#', '');
    final description = rawTag.isNotEmpty ? '$rawDescription #$rawTag' : rawDescription;
    final amountText = _amountController.text.trim();
    
    if (description.isEmpty || amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ingresa descripción y monto')));
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Monto inválido')));
      return;
    }

    // Lista activa (null = Lista Privada)
    final activeList = ref.read(activeListProvider);
    final listId = activeList?.id;

    final repo = ref.read(transactionRepositoryProvider);
    try {
      if (widget.transaction != null) {
        await repo.updateTransaction(
          id: widget.transaction!.id,
          amount: amount,
          category: _selectedCategory,
          description: description,
          date: _selectedDate,
          isIncome: _isIncome,
          listId: listId,
        );
      } else {
        await repo.addTransaction(
          amount: amount,
          category: _selectedCategory,
          description: description,
          date: _selectedDate,
          isIncome: _isIncome,
          listId: listId,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final _categories = ref.watch(categoryProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9, // Almost full screen
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Actions
          Padding(
            padding: const EdgeInsets.only(top: 16, right: 16, left: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Date & Frequency Pills
                Row(
                  children: [
                    _buildPillDropdown(
                      label: _isToday(_selectedDate) ? 'hoy' : DateFormat('dd MMM').format(_selectedDate),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context, 
                          initialDate: _selectedDate, 
                          firstDate: DateTime(2020), 
                          lastDate: DateTime(2100)
                        );
                        if (date != null) setState(() => _selectedDate = date);
                      }
                    ),
                    SizedBox(width: 8),
                    _buildPillDropdown(label: 'Una vez', onTap: () {}), // Frequency placeholder
                  ],
                ),
                // Close button
                IconButton(
                  icon: Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(backgroundColor: Colors.grey[100]),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Inputs
                  TextField(
                    controller: _descriptionController,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Descripción',
                      hintStyle: TextStyle(color: Colors.grey[300]),
                      border: InputBorder.none,
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Row for Toggle and Amount
                  Row(
                    children: [
                      // Toggle
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _isIncome = false),
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 200),
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: !_isIncome ? Colors.red : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text('-', style: TextStyle(color: !_isIncome ? Colors.white : Colors.grey, fontSize: 24, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _isIncome = true),
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 200),
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: _isIncome ? Colors.green : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text('+', style: TextStyle(color: _isIncome ? Colors.white : Colors.grey, fontSize: 22, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(width: 16),
                      
                      // Amount
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _isIncome ? Colors.green : Colors.red),
                          decoration: InputDecoration(
                            hintText: 'Monto',
                            hintStyle: TextStyle(color: Colors.grey[300]),
                            border: InputBorder.none,
                            prefixText: '\$ ',
                            prefixStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _isIncome ? Colors.green : Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 30),
                  
                  // Category Scroll
                  SizedBox(
                    height: 50,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length + 1, // +1 for Add button
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          // Add Category Button
                          return GestureDetector(
                            onTap: () async {
                              final selected = await showModalBottomSheet<String>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => CategoryPickerModal(initialCategory: _selectedCategory),
                              );
                              if (selected != null) {
                                setState(() => _selectedCategory = selected);
                              }
                            },
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: const Icon(Icons.add, color: Colors.black54),
                            ),
                          );
                        }
                        
                        final cat = _categories[index - 1];
                        final isSelected = cat.name == _selectedCategory;
                        
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory = cat.name),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.grey[200] : Colors.white, // Selected turns greyish/active
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: isSelected ? Colors.transparent : Colors.grey[100]!),
                              boxShadow: isSelected ? [] : [
                                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))
                              ],
                            ),
                            child: Row(
                              children: [
                                Text(cat.emoji, style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Text(
                                  cat.name, 
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600, 
                                    color: Colors.black87
                                  )
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  SizedBox(height: 40),
                  
                  // Bottom Row: Tag + Save Button
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 60,
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey[200], // Light grey background
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerLeft,
                          child: TextField(
                            controller: _tagController,
                            decoration: InputDecoration(
                              hintText: '#Etiqueta',
                              hintStyle: TextStyle(color: Colors.black38, fontWeight: FontWeight.normal),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      
                      if (widget.transaction != null) ...[
                        SizedBox(width: 12),
                        GestureDetector(
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text("Confirmar"),
                                  content: const Text("¿Estás seguro de que deseas eliminar esta transacción?"),
                                  actions: <Widget>[
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text("Cancelar"),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text("Eliminar", style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirm == true) {
                              final repo = ref.read(transactionRepositoryProvider);
                              try {
                                await repo.deleteTransaction(widget.transaction!.id);
                                if (mounted) {
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
                                }
                              }
                            }
                          },
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: Icon(Icons.delete_outline, color: Colors.black, size: 30),
                          ),
                        ),
                      ],
                      SizedBox(width: 12),
                      
                      // Save Button (Black Square)
                      GestureDetector(
                        onTap: _saveTransaction,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.check, color: Colors.white, size: 30),
                        ),
                      ),
                    ],
                  ),
                  
                  // Spacer for keyboard
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillDropdown({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
            SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.black87),
          ],
        ),
      ),
    );
  }
  
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

}
