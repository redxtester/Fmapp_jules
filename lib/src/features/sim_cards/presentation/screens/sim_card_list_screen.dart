import 'package:fmapp/src/features/sim_cards/data/models/sim_card.dart';
import 'package:fmapp/src/features/sim_cards/presentation/screens/add_edit_sim_card_screen.dart';
import 'package:fmapp/src/features/sim_cards/presentation/state/sim_card_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fmapp/src/core/presentation/widgets/loading_indicator.dart';

class SimCardListScreen extends ConsumerWidget {
  const SimCardListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the stream provider for real-time updates from local DB
    final simCardsAsyncValue = ref.watch(simCardsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My SIM Cards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing SIM cards...')),
              );
              try {
                await ref.read(simCardControllerProvider.notifier).syncSimCards();
                 if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('SIM cards synced successfully!')),
                    );
                 }
              } catch (e) {
                if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error syncing SIM cards: $e')),
                    );
                }
              }
            },
            tooltip: 'Sync with Cloud',
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddEditSimCardScreen()),
              );
            },
            tooltip: 'Add New SIM Card',
          ),
        ],
      ),
      body: simCardsAsyncValue.when(
        data: (simCards) {
          if (simCards.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sim_card_alert_outlined, size: 60, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No SIM cards found.', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  const Text('Tap the "+" icon to add your first SIM card.', textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                   ElevatedButton.icon(
                     icon: const Icon(Icons.add),
                     label: const Text("Add SIM Card"),
                     onPressed: (){
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const AddEditSimCardScreen()),
                        );
                     }
                   )
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: simCards.length,
            itemBuilder: (context, index) {
              final sim = simCards[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: sim.colorCode != null ? _parseColor(sim.colorCode!) : Theme.of(context).primaryColor,
                    child: Text(
                      sim.simNickname.isNotEmpty ? sim.simNickname[0].toUpperCase() : 'S',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(sim.simNickname, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${sim.phoneNumber}\n${sim.telecomProvider ?? ''}'),
                  isThreeLine: sim.telecomProvider != null && sim.telecomProvider!.isNotEmpty,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => AddEditSimCardScreen(simCard: sim)),
                        );
                      } else if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Confirm Delete'),
                            content: Text('Are you sure you want to delete SIM card "${sim.simNickname}"? This action cannot be undone.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && sim.supabaseId != null) {
                          try {
                            await ref.read(simCardControllerProvider.notifier).deleteSimCard(sim.supabaseId!, sim.isarId);
                             if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('SIM card "${sim.simNickname}" deleted.')),
                                );
                             }
                          } catch (e) {
                            if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error deleting SIM card: $e')),
                                );
                            }
                          }
                        } else if (sim.supabaseId == null) {
                            // Should not happen if added correctly, but handle case
                             if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Error: Cannot delete. SIM card not synced.')),
                                );
                             }
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const LoadingIndicator(message: 'Loading SIM cards...'),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              const Text('Error loading SIM cards:', style: TextStyle(fontSize: 18, color: Colors.red)),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(error.toString(), textAlign: TextAlign.center),
              ),
               const SizedBox(height: 20),
               ElevatedButton(
                 onPressed: () => ref.invalidate(simCardsStreamProvider), // Invalidate to refetch
                 child: const Text("Retry")
               )
            ],
          ),
        ),
      ),
    );
  }

  // Helper to parse color, default to primary color if invalid
  Color _parseColor(String colorCode) {
    try {
      if (colorCode.startsWith('#') && colorCode.length >= 7) {
        return Color(int.parse(colorCode.substring(1, 7), radix: 16) + 0xFF000000);
      }
      // Add more named color parsing if needed
      switch (colorCode.toLowerCase()) {
        case 'red': return Colors.red;
        case 'green': return Colors.green;
        case 'blue': return Colors.blue;
        // ... add other common colors
      }
    } catch (e) {
      // Invalid color code
    }
    return Colors.grey; // Default color
  }
}
