import 'package:flutter/material.dart';
import '../models/snapshot.dart';

/// Executive-level Market Snapshot card shown at the top of every screen.
class MarketSnapshotCard extends StatelessWidget {
  final MarketSnapshot snapshot;
  final bool isLoading;

  const MarketSnapshotCard({
    super.key,
    required this.snapshot,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '📊  MARKET SNAPSHOT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const Spacer(),
                if (isLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Colors.white54,
                    ),
                  )
                else
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00e676),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatBadge(
                  emoji: '🚨',
                  label: 'Threats',
                  value: snapshot.threats,
                  color: const Color(0xFFff5252),
                ),
                _StatBadge(
                  emoji: '📈',
                  label: 'Opportunities',
                  value: snapshot.opportunities,
                  color: const Color(0xFF69f0ae),
                ),
                _StatBadge(
                  emoji: '🎯',
                  label: 'Buy Signals',
                  value: snapshot.buyingSignals,
                  color: const Color(0xFFffab40),
                ),
                _StatBadge(
                  emoji: '🏆',
                  label: 'Competitors',
                  value: snapshot.competitorsTracked,
                  color: const Color(0xFF82b1ff),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Divider
            Divider(color: Colors.white.withOpacity(0.15), height: 1),
            const SizedBox(height: 10),

            // Top recommendation
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⚡', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOP RECOMMENDATION',
                        style: TextStyle(
                          color: Color(0xFFffab40),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        snapshot.topRecommendation,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String emoji;
  final String label;
  final int value;
  final Color color;

  const _StatBadge({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
