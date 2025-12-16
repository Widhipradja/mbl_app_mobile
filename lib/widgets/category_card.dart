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
    final originalBalance = netAmount - reallocOut + reallocIn;
    final hasRealloc = reallocIn != 0 || reallocOut != 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.grey[50]!],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.08),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Category name and transaction count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  category,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue[200]!, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long, size: 12, color: Colors.blue[700]),
                    const SizedBox(width: 4),
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
            ],
          ),
          const SizedBox(height: 4),
          // Net amount - large and prominent
          Text(
            'Rp ${NumberFormat('#,##0', 'id_ID').format(netAmount.abs())}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.blue[600],
              letterSpacing: -0.5,
            ),
          ),

          if (hasRealloc) ...[
            const SizedBox(height: 10),
            // Divider
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey[300]!,
                    Colors.grey[200]!,
                    Colors.grey[300]!,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Original balance
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ORIGINAL BALANCE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[500],
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rp ${NumberFormat('#,##0', 'id_ID').format(originalBalance.abs())}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Lent or Borrowed
            if (reallocOut > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red[50]!, Colors.pink[50]!],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red[200]!, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: Colors.red[700],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Lent',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[700],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Rp ${NumberFormat('#,##0', 'id_ID').format(reallocOut)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[800],
                      ),
                    ),
                  ],
                ),
              ),
            if (reallocIn > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[50]!, Colors.lightBlue[50]!],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue[200]!, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.arrow_downward_rounded,
                        size: 16,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Borrowed',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Rp ${NumberFormat('#,##0', 'id_ID').format(reallocIn)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
