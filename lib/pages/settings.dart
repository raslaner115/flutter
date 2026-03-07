import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:untitled1/language_provider.dart';
import 'package:untitled1/pages/sighn_in.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;

  Map<String, String> _getLocalizedStrings(BuildContext context) {
    final locale = Provider.of<LanguageProvider>(context).locale.languageCode;
    switch (locale) {
      case 'he':
        return {
          'title': 'הגדרות',
          'notifications': 'התראות',
          'language': 'שפה',
          'about': 'אודות',
          'account': 'חשבון',
          'privacy': 'פרטיות',
          'help': 'עזרה',
          'logout': 'התנתקות',
          'appearance': 'מראה',
        };
      case 'ar':
        return {
          'title': 'الإعدادات',
          'notifications': 'الإشعارات',
          'language': 'اللغة',
          'about': 'حول',
          'account': 'الحساب',
          'privacy': 'الخصوصية',
          'help': 'المساعدة',
          'logout': 'تسجيل الخروج',
          'appearance': 'المظهر',
        };
      default:
        return {
          'title': 'Settings',
          'notifications': 'Notifications',
          'language': 'Language',
          'about': 'About',
          'account': 'Account',
          'privacy': 'Privacy',
          'help': 'Help & Support',
          'logout': 'Logout',
          'appearance': 'Appearance',
        };
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const SignInPage()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = _getLocalizedStrings(context);
    final isRtl = Provider.of<LanguageProvider>(context).locale.languageCode == 'he' ||
        Provider.of<LanguageProvider>(context).locale.languageCode == 'ar';

    if (Platform.isIOS) {
      return _buildIosSettings(context, strings, isRtl);
    } else {
      return _buildAndroidSettings(context, strings, isRtl);
    }
  }

  // --- ANDROID (Galaxy / One UI) DESIGN ---
  Widget _buildAndroidSettings(BuildContext context, Map<String, String> strings, bool isRtl) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F2F7),
        body: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              expandedHeight: 180,
              backgroundColor: const Color(0xFFF2F2F7),
              elevation: 0,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(strings['title']!,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                centerTitle: false,
                titlePadding: const EdgeInsetsDirectional.only(start: 24, bottom: 16),
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate([
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildGalaxySection(strings['account']!, [
                        _buildGalaxyTile(Icons.person_outline_rounded, strings['account']!),
                        _buildGalaxyTile(Icons.lock_outline_rounded, strings['privacy']!),
                      ]),
                      const SizedBox(height: 16),
                      _buildGalaxySection(strings['notifications']!, [
                        _buildGalaxySwitchTile(Icons.notifications_none_rounded, strings['notifications']!, _notificationsEnabled, (v) => setState(() => _notificationsEnabled = v)),
                      ]),
                      const SizedBox(height: 16),
                      _buildGalaxySection(strings['language']!, [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Icon(Icons.language_rounded, color: theme.colorScheme.primary),
                          title: Text(strings['language']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                          trailing: const LanguageDropDown(),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _buildGalaxySection(strings['help']!, [
                        _buildGalaxyTile(Icons.help_outline_rounded, strings['help']!),
                        _buildGalaxyTile(Icons.info_outline_rounded, strings['about']!),
                      ]),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: _logout,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                            backgroundColor: Colors.white,
                          ),
                          child: Text(strings['logout']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGalaxySection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 12, bottom: 8),
          child: Text(title.toUpperCase(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8E8E93))),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildGalaxyTile(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1976D2)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: () {},
    );
  }

  Widget _buildGalaxySwitchTile(IconData icon, String title, bool value, Function(bool) onChanged) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1976D2)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: const Color(0xFF1976D2).withOpacity(0.5),
        activeColor: const Color(0xFF1976D2),
      ),
    );
  }

  // --- iOS (Cupertino) DESIGN ---
  Widget _buildIosSettings(BuildContext context, Map<String, String> strings, bool isRtl) {
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground,
        navigationBar: CupertinoNavigationBar(
          middle: Text(strings['title']!),
          border: null,
        ),
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: Text(strings['account']!),
              children: [
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.person, color: CupertinoColors.systemBlue),
                  title: Text(strings['account']!),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () {},
                ),
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.lock, color: CupertinoColors.systemBlue),
                  title: Text(strings['privacy']!),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () {},
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: Text(strings['notifications']!),
              children: [
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.bell, color: CupertinoColors.systemRed),
                  title: Text(strings['notifications']!),
                  trailing: CupertinoSwitch(
                    value: _notificationsEnabled,
                    onChanged: (v) => setState(() => _notificationsEnabled = v),
                  ),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: Text(strings['language']!),
              children: [
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.globe, color: CupertinoColors.systemGreen),
                  title: Text(strings['language']!),
                  trailing: const LanguageDropDown(),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: Text(strings['help']!),
              children: [
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.question_circle, color: CupertinoColors.systemOrange),
                  title: Text(strings['help']!),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () {},
                ),
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.info, color: CupertinoColors.systemGrey),
                  title: Text(strings['about']!),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () {},
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CupertinoButton(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(10),
                onPressed: _logout,
                child: Text(strings['logout']!,
                    style: const TextStyle(color: CupertinoColors.destructiveRed, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LanguageDropDown extends StatelessWidget {
  const LanguageDropDown({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LanguageProvider>(context).locale;
    String current = 'English';
    if (locale.languageCode == 'he') current = 'עברית';
    else if (locale.languageCode == 'ar') current = 'عربي';
    else if (locale.languageCode == 'ru') current = 'русский';

    if (Platform.isIOS) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        child: Text(current, style: const TextStyle(fontSize: 14)),
        onPressed: () => _showIosLocalePicker(context),
      );
    }

    return DropdownButton<String>(
      value: current,
      underline: const SizedBox(),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
      items: ['English', 'עברית', 'عربي', 'русский'].map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          Provider.of<LanguageProvider>(context, listen: false).setLocale(newValue);
        }
      },
    );
  }

  void _showIosLocalePicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: ['English', 'עברית', 'عربي', 'русский'].map((lang) => CupertinoActionSheetAction(
          onPressed: () {
            Provider.of<LanguageProvider>(context, listen: false).setLocale(lang);
            Navigator.pop(context);
          },
          child: Text(lang),
        )).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
