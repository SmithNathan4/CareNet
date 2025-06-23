import 'package:flutter/material.dart';

class Notifications extends StatefulWidget {
  const Notifications({super.key});

  @override
  _NotificationsState createState() => _NotificationsState();
}

class _NotificationsState extends State<Notifications> {
  // Couleurs principales harmonisées
  final Color _primaryColor = const Color(0xFF1976D2);
  final Color _accentColor = const Color(0xFF42A5F5);
  bool _showNotifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _specialOffers = true;
  bool _paymentAlerts = true;
  bool _promoAndDiscount = true;
  bool _appointmentReminders = true;

  void _goBackToSettings() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: _buildAppBar(isDark),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section principale de notifications
            _buildNotificationSection(
              title: 'Paramètres généraux',
              children: [
                _buildNotificationSwitch(
                  title: 'Activer les notifications',
                  value: _showNotifications,
                  onChanged: (value) => setState(() => _showNotifications = value),
                  icon: Icons.notifications_active,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _resetToDefaults,
                      icon: Icon(Icons.settings_backup_restore, size: 20, color: Colors.blue),
                      label: Text(
                        'Réinitialiser',
                        style: TextStyle(color: Colors.blue, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Paramètres de notification
            _buildNotificationSection(
              title: 'Préférences de notification',
              children: [
                _buildNotificationSwitch(
                  title: 'Son',
                  value: _soundEnabled,
                  onChanged: _showNotifications ? (value) => setState(() => _soundEnabled = value) : null,
                  icon: Icons.volume_up,
                  enabled: _showNotifications,
                ),
                _buildNotificationSwitch(
                  title: 'Vibration',
                  value: _vibrationEnabled,
                  onChanged: _showNotifications ? (value) => setState(() => _vibrationEnabled = value) : null,
                  icon: Icons.vibration,
                  enabled: _showNotifications,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Types de notification
            _buildNotificationSection(
              title: 'Types de notifications',
              subtitle: 'Choisissez les notifications que vous souhaitez recevoir',
              children: [
                _buildNotificationSwitch(
                  title: 'Offres spéciales',
                  value: _specialOffers,
                  onChanged: _showNotifications ? (value) => setState(() => _specialOffers = value) : null,
                  icon: Icons.local_offer,
                  enabled: _showNotifications,
                ),
                _buildNotificationSwitch(
                  title: 'Alertes de paiement',
                  value: _paymentAlerts,
                  onChanged: _showNotifications ? (value) => setState(() => _paymentAlerts = value) : null,
                  icon: Icons.payment,
                  enabled: _showNotifications,
                ),
                _buildNotificationSwitch(
                  title: 'Promotions et réductions',
                  value: _promoAndDiscount,
                  onChanged: _showNotifications ? (value) => setState(() => _promoAndDiscount = value) : null,
                  icon: Icons.discount,
                  enabled: _showNotifications,
                ),
                _buildNotificationSwitch(
                  title: 'Rappels de rendez-vous',
                  value: _appointmentReminders,
                  onChanged: _showNotifications ? (value) => setState(() => _appointmentReminders = value) : null,
                  icon: Icons.calendar_today,
                  enabled: _showNotifications,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      title: const Text('Notifications'),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : _primaryColor,
      elevation: 0,
      shape: null,
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  Widget _buildNotificationSection({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF333333),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSwitch({
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
    required IconData icon,
    bool enabled = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: enabled ? _accentColor : Colors.grey[400],
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: enabled ? (isDark ? Colors.white : const Color(0xFF333333)) : Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _accentColor,
            inactiveThumbColor: Colors.grey[300],
            inactiveTrackColor: Colors.grey[200],
          ),
        ],
      ),
    );
  }

  void _resetToDefaults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'Réinitialiser les paramètres',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333)),
        ),
        content: const Text('Voulez-vous rétablir les paramètres par défaut ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Annuler',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _showNotifications = true;
                _soundEnabled = true;
                _vibrationEnabled = true;
                _specialOffers = true;
                _paymentAlerts = true;
                _promoAndDiscount = true;
                _appointmentReminders = true;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Paramètres réinitialisés'),
                  backgroundColor: Colors.blue[600],
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Text(
              'Confirmer',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
}