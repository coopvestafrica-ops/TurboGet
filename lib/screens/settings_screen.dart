import 'package:flutter/material.dart';
import '../services/settings_manager.dart';
import '../services/download_service.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsManager();
  final _downloadService = DownloadService();
  final _themeService = ThemeService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const _SectionHeader(title: 'Appearance'),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Theme'),
            subtitle: Text(_getThemeLabel(_themeService.themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemeDialog(context),
          ),
          const Divider(),
          const _SectionHeader(title: 'Downloads'),
          SwitchListTile(
            secondary: const Icon(Icons.wifi),
            title: const Text('Download on Wi-Fi only'),
            subtitle: const Text('Downloads will pause when not on Wi-Fi'),
            value: _settings.isWifiOnly,
            onChanged: (bool value) {
              setState(() {
                _settings.isWifiOnly = value;
                _downloadService.setWifiOnlyMode(value);
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Maximum concurrent downloads'),
            subtitle: Text('${_settings.maxConcurrentDownloads} downloads at a time'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _settings.maxConcurrentDownloads > 1
                      ? () {
                          setState(() {
                            _settings.maxConcurrentDownloads--;
                          });
                        }
                      : null,
                ),
                Text('${_settings.maxConcurrentDownloads}'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _settings.maxConcurrentDownloads < 5
                      ? () {
                          setState(() {
                            _settings.maxConcurrentDownloads++;
                          });
                        }
                      : null,
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Download Location'),
            subtitle: Text(_settings.customDownloadPath ?? 'Default location'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Add folder picker
            },
          ),
          const Divider(),
          const _SectionHeader(title: 'Scheduler'),
          SwitchListTile(
            secondary: const Icon(Icons.schedule),
            title: const Text('Scheduled Downloads'),
            subtitle: const Text('Download during specific hours'),
            value: _settings.schedulerEnabled,
            onChanged: (bool value) {
              setState(() {
                _settings.schedulerEnabled = value;
              });
            },
          ),
          if (_settings.schedulerEnabled) ...[
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Start Time'),
              subtitle: Text(_formatTime(_settings.schedulerStartHour, _settings.schedulerStartMinute)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickTime(context, true),
            ),
            ListTile(
              leading: const Icon(Icons.access_time_filled),
              title: const Text('End Time'),
              subtitle: Text(_formatTime(_settings.schedulerEndHour, _settings.schedulerEndMinute)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickTime(context, false),
            ),
          ],
          const Divider(),
          const _SectionHeader(title: 'Storage'),
          ListTile(
            leading: const Icon(Icons.cloud_upload),
            title: const Text('Cloud Backup'),
            subtitle: const Text('Backup download history'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Implement cloud backup
            },
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services),
            title: const Text('Clear Cache'),
            subtitle: const Text('Free up storage space'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showClearCacheDialog(context),
          ),
        ],
      ),
    );
  }

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System default';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values.map((mode) {
            return RadioListTile<ThemeMode>(
              title: Text(_getThemeLabel(mode)),
              value: mode,
              groupValue: _themeService.themeMode,
              onChanged: (value) {
                if (value != null) {
                  _themeService.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _pickTime(BuildContext context, bool isStartTime) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: isStartTime ? _settings.schedulerStartHour : _settings.schedulerEndHour,
        minute: isStartTime ? _settings.schedulerStartMinute : _settings.schedulerEndMinute,
      ),
    );
    if (time != null) {
      setState(() {
        if (isStartTime) {
          _settings.schedulerStartHour = time.hour;
          _settings.schedulerStartMinute = time.minute;
        } else {
          _settings.schedulerEndHour = time.hour;
          _settings.schedulerEndMinute = time.minute;
        }
      });
    }
  }

  String _formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('This will remove temporary files. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement cache clearing
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
