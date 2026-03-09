import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import 'package:intl/intl.dart';
import '../../core/utils/category_utils.dart';
import '../features/transactions/manual_transaction_modal.dart';
import '../features/categories/category_provider.dart';

class TransactionItem extends ConsumerWidget {
  final Transaction transaction;
  final VoidCallback onDelete;

  const TransactionItem({Key? key, required this.transaction, required this.onDelete}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncome = transaction.type == 1;
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final dateFormat = DateFormat('dd/MM/yyyy', 'es_ES');
    
    final categories = ref.watch(categoryProvider);
    final emoji = categories.firstWhere(
      (c) => c.name == transaction.categoryName, 
      orElse: () => CategoryItem(name: '', emoji: CategoryUtils.getEmoji(transaction.categoryName))
    ).emoji;

    final desc = transaction.description;
    final tagMatch = RegExp(r'(.*)\s+#([^\s]+)$').firstMatch(desc);
    final mainDesc = tagMatch != null ? (tagMatch.group(1) ?? '') : desc;
    final tag = tagMatch != null ? '#${tagMatch.group(2)}' : '';
    
    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
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
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(20)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: Offset(0,4))
          ]
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[100], // Or light pastel color based on category
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
            ),
            SizedBox(width: 16),
            
            // Category, Title & Tag
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.categoryName ?? 'Comida',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.normal),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mainDesc, 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tag.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      tag,
                      style: TextStyle(color: Colors.blue[600], fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            ),
            
            // Amount
            Text(
              '${isIncome ? "" : "-"}${currencyFormat.format(transaction.amount)}',
              style: TextStyle(
                color: Colors.black, // Design uses black for amount, colored arrows/pills handling sentiment
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            
            SizedBox(width: 12),
            
            // Edit Action
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => ManualTransactionModal(transaction: transaction),
                );
              },
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle
                ),
                child: Icon(Icons.edit, size: 16, color: Colors.grey),
              ),
            )
          ],
        ),
      ),
    );
  }
}
