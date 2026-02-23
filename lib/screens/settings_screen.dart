import 'package:flutter/material.dart';
import '../services/settings_manager.dart';
import '../services/download_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsManager();
  final _downloadService = DownloadService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text('Download on Wi-Fi only'),
            subtitle: Text('Downloads will pause when not on Wi-Fi'),
            value: _settings.isWifiOnly,
            onChanged: (bool value) {
              setState(() {
                _settings.isWifiOnly = value;
                _downloadService.setWifiOnlyMode(value);
              });
            },
          ),
          ListTile(
            title: Text('Maximum concurrent downloads'),
            subtitle: Text('${_settings.maxConcurrentDownloads}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove),
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
                  icon: Icon(Icons.add),
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
            title: Text('Download Location'),
            subtitle: Text(_settings.customDownloadPath ?? 'Default location'),
            trailing: IconButton(
              icon: Icon(Icons.folder_open),
              onPressed: () async {
                // TODO: Add folder picker
              },
            ),
          ),
        ],
      ),
    );
  }
}
