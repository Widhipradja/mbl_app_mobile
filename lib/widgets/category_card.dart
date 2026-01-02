import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CategoryCard extends StatelessWidget {
  final String category;
  final double netAmount;
  final int count;
  final double reallocIn;
  final double reallocOut;

  const CategoryCard({
    super.key,
    required this.category,
    required this.netAmount,
    required this.count,
    required this.reallocIn,
    required this.reallocOut,
  });

  @override
  Widget build(BuildContext context) {
    // Original = nilai sekarang + Lent (yang dipinjamkan keluar) - Borrowed (yang dipinjam masuk)
    final originalBalance = netAmount + reallocOut - reallocIn;
    final hasRealloc = reallocIn != 0 || reallocOut != 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main row - Category name, count, and net amount
          Row(
            children: [
              // Category name
              Expanded(
                flex: 3,
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),

              // Transaction count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long, size: 11, color: Colors.blue[700]),
                    const SizedBox(width: 3),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Net amount
              Text(
                'Rp ${NumberFormat('#,##0', 'id_ID').format(netAmount.abs())}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: netAmount >= 0 ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ],
          ),

          // Show reallocation details if present
          if (hasRealloc) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: Colors.grey[200]),
            const SizedBox(height: 8),

            // Reallocation details in table format
            Row(
              children: [
                // Original Balance
                Expanded(
                  child: _buildInfoCell(
                    'Original',
                    '${originalBalance < 0 ? '-' : ''}Rp ${NumberFormat('#,##0', 'id_ID').format(originalBalance.abs())}',
                    originalBalance < 0 ? Colors.red[600]! : Colors.grey[600]!,
                    isNegative: originalBalance < 0,
                  ),
                ),

                // Lent amount
                if (reallocOut > 0)
                  Expanded(
                    child: _buildInfoCell(
                      'Lent',
                      'Rp ${NumberFormat('#,##0', 'id_ID').format(reallocOut)}',
                      Colors.red[600]!,
                    ),
                  ),

                // Borrowed amount
                if (reallocIn > 0)
                  Expanded(
                    child: _buildInfoCell(
                      'Borrowed',
                      'Rp ${NumberFormat('#,##0', 'id_ID').format(reallocIn)}',
                      Colors.blue[600]!,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCell(
    String label,
    String value,
    Color color, {
    bool isNegative = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isNegative) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.warning_amber_rounded,
                size: 12,
                color: Colors.orange[600],
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
