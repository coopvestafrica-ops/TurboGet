import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_theme.dart';
import '../services/turbo_downloader_engine.dart';
import '../services/settings_manager.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TURBOGET SETTINGS - World Class Design
/// Designed by Olatunji Ayobami Ayanlowo +2347038193753
/// ═══════════════════════════════════════════════════════════════════════════

class TurboSettingsScreen extends ConsumerStatefulWidget {
  const TurboSettingsScreen({super.key});

  @override
  ConsumerState<TurboSettingsScreen> createState() => _TurboSettingsScreenState();
}

class _TurboSettingsScreenState extends ConsumerState<TurboSettingsScreen> {
  bool _wifiOnly = false;
  bool _autoRetry = true;
  bool _notifications = true;
  bool _cloudSync = false;
  int _maxRetries = 5;
  int _maxConcurrent = 3;
  double _bandwidthLimit = 0;
  String _downloadPath = '/storage/downloads';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final settings = SettingsManager();
    setState(() {
      _wifiOnly = settings.isWifiOnly;
      _autoRetry = true;
      _notifications = true;
      _cloudSync = false;
      _maxRetries = 5;
      _maxConcurrent = settings.maxConcurrentDownloads;
      _bandwidthLimit = 0;
      _downloadPath = settings.customDownloadPath ?? '/storage/downloads';
    });
  }

  void _saveSettings() {
    final settings = SettingsManager();
    settings.isWifiOnly = _wifiOnly;
    settings.maxConcurrentDownloads = _maxConcurrent;
    settings.customDownloadPath = _downloadPath;

    turboDownloader.setWifiOnlyMode(_wifiOnly);
    if (_bandwidthLimit > 0) {
      turboDownloader.setBandwidthLimit(_bandwidthLimit * 1024 * 1024); // MB to bytes
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved!'),
        backgroundColor: AppTheme.successGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              _buildAppBar(context),

              // Settings List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Download Settings
                    _buildSection(
                      title: '⚙️ Download Settings',
                      icon: Icons.download_rounded,
                      children: [
                        _buildSwitchTile(
                          title: 'WiFi Only',
                          subtitle: 'Only download when connected to WiFi',
                          icon: Icons.wifi,
                          value: _wifiOnly,
                          onChanged: (v) => setState(() => _wifiOnly = v),
                        ),
                        _buildSwitchTile(
                          title: 'Auto Retry',
                          subtitle: 'Automatically retry failed downloads',
                          icon: Icons.refresh,
                          value: _autoRetry,
                          onChanged: (v) => setState(() => _autoRetry = v),
                        ),
                        _buildSliderTile(
                          title: 'Max Retries',
                          subtitle: 'Number of retry attempts for failed downloads',
                          icon: Icons.repeat,
                          value: _maxRetries.toDouble(),
                          min: 1,
                          max: 10,
                          divisions: 9,
                          onChanged: (v) => setState(() => _maxRetries = v.round()),
                        ),
                        _buildSliderTile(
                          title: 'Concurrent Downloads',
                          subtitle: 'Maximum simultaneous downloads',
                          icon: Icons.speed,
                          value: _maxConcurrent.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          onChanged: (v) => setState(() => _maxConcurrent = v.round()),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Bandwidth Settings
                    _buildSection(
                      title: '📊 Bandwidth Control',
                      icon: Icons.data_usage,
                      children: [
                        _buildSliderTile(
                          title: 'Speed Limit',
                          subtitle: _bandwidthLimit == 0 
                              ? 'Unlimited' 
                              : '$_bandwidthLimit MB/s',
                          icon: Icons.speed,
                          value: _bandwidthLimit,
                          min: 0,
                          max: 100,
                          divisions: 100,
                          onChanged: (v) => setState(() => _bandwidthLimit = v),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Cloud & Sync
                    _buildSection(
                      title: '☁️ Cloud & Sync',
                      icon: Icons.cloud,
                      children: [
                        _buildSwitchTile(
                          title: 'Cloud Sync',
                          subtitle: 'Sync downloads across devices',
                          icon: Icons.cloud_sync,
                          value: _cloudSync,
                          onChanged: (v) => setState(() => _cloudSync = v),
                        ),
                        if (_cloudSync)
                          _buildTile(
                            title: 'Sync Now',
                            subtitle: 'Last sync: Never',
                            icon: Icons.sync,
                            onTap: () => cloudSync.syncNow(),
                          ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Notifications
                    _buildSection(
                      title: '🔔 Notifications',
                      icon: Icons.notifications,
                      children: [
                        _buildSwitchTile(
                          title: 'Push Notifications',
                          subtitle: 'Get notified when downloads complete',
                          icon: Icons.notifications_active,
                          value: _notifications,
                          onChanged: (v) => setState(() => _notifications = v),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Storage
                    _buildSection(
                      title: '💾 Storage',
                      icon: Icons.folder,
                      children: [
                        _buildTile(
                          title: 'Download Location',
                          subtitle: _downloadPath,
                          icon: Icons.folder_open,
                          onTap: () => _showPathPicker(),
                        ),
                        _buildTile(
                          title: 'Clear Cache',
                          subtitle: 'Free up storage space',
                          icon: Icons.cleaning_services,
                          onTap: () => _showClearCacheDialog(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // About
                    _buildSection(
                      title: 'ℹ️ About',
                      icon: Icons.info,
                      children: [
                        _buildTile(
                          title: 'Version',
                          subtitle: '1.0.0 (Build 2024)',
                          icon: Icons.new_releases,
                        ),
                        _buildTile(
                          title: 'Licenses',
                          subtitle: 'Open source licenses',
                          icon: Icons.description,
                          onTap: () => showLicensePage(context: context),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Designer Credit
                    _buildDesignerCredit(),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          ShaderMask(
            shaderCallback: (bounds) {
              return AppTheme.turboGradient.createShader(bounds);
            },
            child: const Text(
              'Settings',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.save, color: Colors.white),
              onPressed: _saveSettings,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryBlue, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryBlue,
            activeTrackColor: AppTheme.primaryBlue.withOpacity(0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primaryPurple, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value.round().toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppTheme.primaryBlue,
              inactiveTrackColor: Colors.white.withOpacity(0.1),
              thumbColor: AppTheme.accentCyan,
              overlayColor: AppTheme.accentCyan.withOpacity(0.2),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.successGreen, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withOpacity(0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesignerCredit() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue.withOpacity(0.3),
            AppTheme.primaryPurple.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppTheme.turboGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.design_services,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Designed by',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          ShaderMask(
            shaderCallback: (bounds) {
              return AppTheme.turboGradient.createShader(bounds);
            },
            child: const Text(
              'Olatunji Ayobami Ayanlowo',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.accentCyan.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone, color: AppTheme.accentCyan, size: 16),
                const SizedBox(width: 8),
                const Text(
                  '+2347038193753',
                  style: TextStyle(
                    color: AppTheme.accentCyan,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPathPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Select Download Location',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            _buildPathOption('/storage/downloads'),
            _buildPathOption('/storage/emulated/0/Download'),
            _buildPathOption('/storage/emulated/0/TurboGet'),
          ],
        ),
      ),
    );
  }

  Widget _buildPathOption(String path) {
    return ListTile(
      leading: const Icon(Icons.folder, color: AppTheme.primaryBlue),
      title: Text(path, style: const TextStyle(color: Colors.white)),
      onTap: () {
        setState(() => _downloadPath = path);
        Navigator.pop(context);
      },
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Clear Cache?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will remove temporary files and cached data. Downloads will not be affected.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared!'),
                  backgroundColor: AppTheme.successGreen,
                ),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
