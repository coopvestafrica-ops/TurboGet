import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/download_item.dart';
import '../services/cloud_backup_service.dart';
import '../services/database_service.dart';
import '../services/download_service.dart';
import '../services/settings_manager.dart';
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
  final _cloudBackup = CloudBackupService.instance;
  final _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
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
            subtitle:
                const Text('Downloads will pause when not on Wi-Fi'),
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
            subtitle: Text(
                '${_settings.maxConcurrentDownloads} downloads at a time'),
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
            subtitle: Text(
                _settings.customDownloadPath ?? 'Default location'),
            trailing: _settings.customDownloadPath == null
                ? const Icon(Icons.chevron_right)
                : IconButton(
                    icon: const Icon(Icons.restore),
                    tooltip: 'Reset to default',
                    onPressed: () {
                      setState(() {
                        _settings.customDownloadPath = null;
                      });
                    },
                  ),
            onTap: _pickDownloadLocation,
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
              subtitle: Text(_formatTime(_settings.schedulerStartHour,
                  _settings.schedulerStartMinute)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickTime(context, true),
            ),
            ListTile(
              leading: const Icon(Icons.access_time_filled),
              title: const Text('End Time'),
              subtitle: Text(_formatTime(_settings.schedulerEndHour,
                  _settings.schedulerEndMinute)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickTime(context, false),
            ),
          ],
          const Divider(),
          const _SectionHeader(title: 'Storage'),
          ListTile(
            leading: const Icon(Icons.cloud_upload),
            title: const Text('Cloud Backup'),
            subtitle: const Text('Back up download history'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _runCloudBackup,
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
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values.map((mode) {
            final selected = _themeService.themeMode == mode;
            return ListTile(
              title: Text(_getThemeLabel(mode)),
              leading: Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              onTap: () {
                _themeService.setThemeMode(mode);
                Navigator.pop(ctx);
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
        hour: isStartTime
            ? _settings.schedulerStartHour
            : _settings.schedulerEndHour,
        minute: isStartTime
            ? _settings.schedulerStartMinute
            : _settings.schedulerEndMinute,
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

  Future<void> _pickDownloadLocation() async {
    try {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose download folder',
      );
      if (path == null) return;
      setState(() {
        _settings.customDownloadPath = path;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download location set to: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick folder: $e')),
      );
    }
  }

  Future<void> _runCloudBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Backing up history…')),
    );
    try {
      final history = await _db.getDownloadHistory();
      final items =
          history.map((m) => DownloadItem.fromMap(m)).toList(growable: false);
      final ok = await _cloudBackup.backupHistory(items);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Backed up ${items.length} items'
              : 'Backup failed'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Backup failed: $e')),
      );
    }
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
            'This deletes partial/temporary download files. Completed downloads are not affected. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              final freed = await _clearCache();
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(content: Text('Cache cleared (${_formatSize(freed)})')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  /// Deletes known temporary download artifacts and returns bytes freed.
  Future<int> _clearCache() async {
    int freed = 0;
    final dirs = <Directory>[];
    try {
      dirs.add(await getTemporaryDirectory());
    } catch (_) {}
    try {
      final cache = await getApplicationCacheDirectory();
      dirs.add(cache);
    } catch (_) {}
    for (final dir in dirs) {
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        try {
          if (entity is File) {
            final stat = await entity.stat();
            freed += stat.size;
            await entity.delete();
          }
        } catch (_) {
          // best-effort: skip files we can't delete
        }
      }
    }
    return freed;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
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
