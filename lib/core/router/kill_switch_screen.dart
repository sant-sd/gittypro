import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:gitty/core/firebase/kill_switch_service.dart';

class KillSwitchScreen extends StatelessWidget {
  const KillSwitchScreen({super.key, required this.state});

  final KillSwitchTriggered state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.construction_rounded,
                  size: 40,
                  color: colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'App Temporarily Unavailable',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                state.message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.6,
                    ),
              ),
              if (state.updateUrl != null) ...[
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => _launchUrl(state.updateUrl!),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Update App'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
