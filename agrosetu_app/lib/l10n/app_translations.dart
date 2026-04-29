import 'package:flutter/foundation.dart';
import '../services/user_preferences_service.dart';

/// Lightweight runtime localization. The whole app rebuilds when
/// [currentLocale] changes (a `ValueListenableBuilder` in `main.dart` listens).
/// To translate a string write `'profile.title'.tr`.
class AppTranslations {
  static final ValueNotifier<String> currentLocale = ValueNotifier('en');

  static const fallbackLocale = 'en';

  static Future<void> initFromPrefs() async {
    final prefs = await UserPreferencesService.load();
    currentLocale.value = prefs.language;
  }

  static Future<void> setLocale(String code) async {
    if (!_strings.containsKey(code)) return;
    currentLocale.value = code;
  }

  static String t(String key) {
    return _strings[currentLocale.value]?[key] ??
        _strings[fallbackLocale]?[key] ??
        key;
  }

  static const Map<String, Map<String, String>> _strings = {
    'en': _en,
    'ne': _ne,
  };
}

extension TrString on String {
  String get tr => AppTranslations.t(this);
}

const Map<String, String> _en = {
  // Splash + auth
  'app.name': 'AGROSETU',
  'app.tagline': 'HAMRO LAGI',
  'auth.login': 'Login',
  'auth.signup': 'Sign Up',
  'auth.logout': 'Logout',
  'auth.logout_confirm':
      'Are you sure you want to logout? You will be returned to the login screen.',
  'auth.cancel': 'Cancel',

  // Dashboard / nav tabs
  'nav.home': 'Home',
  'nav.community': 'Community',
  'nav.market': 'Market',
  'nav.assistant': 'Assistant',
  'nav.profile': 'Profile',
  'nav.dashboard': 'Dashboard',
  'nav.disease': 'Disease',

  // Profile
  'profile.title': 'Profile',
  'profile.edit': 'Edit Profile',
  'profile.location': 'Location',
  'profile.user_default': 'User',
  'profile.detections': 'Detections',
  'profile.discussions': 'Discussions',
  'profile.market_tips': 'Market Tips',
  'profile.farm_information': 'Farm Information',
  'profile.farm_size': 'Farm Size',
  'profile.main_crops': 'Main Crops',
  'profile.member_since': 'Member Since',
  'profile.preferences': 'Preferences',
  'profile.notifications': 'Notifications',
  'profile.notifications_enabled': 'Notifications enabled',
  'profile.notifications_muted': 'Notifications muted',
  'profile.picture_updated': 'Profile picture updated',
  'profile.menu.settings': 'Settings',
  'profile.menu.privacy': 'Privacy & Security',
  'profile.menu.terms': 'Terms & Conditions',
  'profile.menu.support': 'Contact Support',

  // Edit Profile
  'edit_profile.title': 'Edit Profile',
  'edit_profile.name': 'Name',
  'edit_profile.email': 'Email',
  'edit_profile.phone': 'Phone',
  'edit_profile.location': 'Location',
  'edit_profile.farm_size': 'Farm Size (hectares)',
  'edit_profile.crops': 'Main Crops (comma separated)',
  'edit_profile.save': 'Save Changes',
  'edit_profile.name_required': 'Name is required',
  'edit_profile.invalid_email': 'Enter a valid email',
  'edit_profile.updated': 'Profile updated successfully',
  'edit_profile.saved_local': 'Saved locally. Sync issue:',

  // Settings
  'settings.title': 'Settings',
  'settings.section_app': 'App Settings',
  'settings.section_account': 'Account Settings',
  'settings.language': 'Language',
  'settings.location_services': 'Location Services',
  'settings.location_help': 'Help us serve you better',
  'settings.data_privacy': 'Data & Privacy',
  'settings.manage_prefs': 'Manage your preferences',
  'settings.change_password': 'Change Password',
  'settings.update_password': 'Update your password',
  'settings.delete_account': 'Delete Account',
  'settings.delete_subtitle': 'Permanently delete your account',
  'settings.delete_warn':
      'This will permanently delete your account, posts, notifications and disease history. This action cannot be undone.',
  'settings.delete_button': 'Delete',
  'settings.not_signed_in': 'Not signed in',
  'settings.on': 'On',
  'settings.off': 'Off',

  // Privacy & Security
  'privacy.title': 'Privacy & Security',
  'privacy.section_settings': 'Privacy Settings',
  'privacy.profile_visibility': 'Profile Visibility',
  'privacy.profile_visibility_sub': 'Allow others to see your profile',
  'privacy.activity_logging': 'Activity Logging',
  'privacy.activity_logging_sub': 'Log your farm activities',
  'privacy.section_data': 'Data Management',
  'privacy.download_data': 'Download Your Data',
  'privacy.download_data_sub': 'Get a copy of your personal data',
  'privacy.clear_cache': 'Clear Cache',
  'privacy.clear_cache_sub': 'Remove cached data to free up space',
  'privacy.clear_warn':
      'This removes cached preferences, weather, notifications and disease history on this device. Your account stays signed in.',
  'privacy.clear_button': 'Clear',
  'privacy.cache_cleared': 'Cache cleared',
  'privacy.export_share_text': 'My AgroSetu data export',
  'privacy.signin_required': 'Sign in to download your data',

  // Contact Support
  'support.title': 'Contact Support',
  'support.get_in_touch': 'Get in Touch',
  'support.phone': 'Phone',
  'support.email': 'Email',
  'support.address': 'Address',
  'support.address_value': 'Kathmandu, Nepal',
  'support.send_us': 'Send us a Message',
  'support.subject': 'Subject',
  'support.subject_hint': 'Enter subject',
  'support.message': 'Message',
  'support.message_hint': 'Type your message here...',
  'support.send': 'Send Message',
  'support.fill_all': 'Please fill in all fields',
  'support.sent_ok': 'Message sent successfully!',

  // Change Password
  'pw.title': 'Change Password',
  'pw.subtitle': 'Update your account password',
  'pw.current': 'Current Password',
  'pw.new': 'New Password',
  'pw.confirm': 'Confirm New Password',
  'pw.hint':
      'Use 8+ characters with upper case, lower case, a number, and a symbol.',
  'pw.update': 'Update Password',
  'pw.required': 'All fields are required',
  'pw.mismatch': 'New passwords do not match',
  'pw.weak': 'Password needs 8+ chars, upper, lower, number, special',
  'pw.same': 'New password must differ from current password',
  'pw.changed': 'Password changed successfully',
  'pw.forgot': 'Forgot current password?',

  // Language
  'lang.title': 'Language',
  'lang.subtitle': 'Select your preferred language',
  'lang.saving': 'Saving...',
  'lang.set_to': 'Language set to',

  // Location Services
  'loc.title': 'Location Services',
  'loc.features': 'Location features',
  'loc.device': 'Device location',
  'loc.permission': 'App permission',
  'loc.enabled': 'Enabled',
  'loc.disabled': 'Disabled',
  'loc.last_position': 'Last known position',
  'loc.device_settings': 'Device settings',
  'loc.app_permissions': 'App permissions',
  'loc.help_text':
      'Used for weather forecasts, nearby market prices and accurate disease alerts.',
  'loc.enable_first':
      'Enable Location in your device settings, then try again.',
  'loc.denied_forever':
      'Permission permanently denied. Open settings to allow it.',
  'loc.denied': 'Permission denied',
  'loc.cant_get': 'Could not get location:',
  'loc.enabled_msg': 'Location services enabled',
  'loc.enabled_no_fix': 'Enabled, but couldn\'t fetch a fix yet',
  'loc.turned_off': 'Location features turned off',
  'loc.open_settings_hint':
      'Open System Settings → Privacy & Security to manage this.',

  // Admin panel
  'admin.tab': 'Admin',
  'admin.dashboard': 'Dashboard',
  'admin.users': 'Users',
  'admin.posts': 'Posts',
  'admin.detections': 'Detections',
  'admin.subtitle': 'System health and key metrics',
  'admin.users_subtitle': 'Manage all registered farmers',
  'admin.posts_subtitle': 'Moderate the farmer forum',
  'admin.detections_subtitle': 'Live AI predictions logged from the mobile app',
  'admin.total_users': 'Total Users',
  'admin.active_users': 'Active Users',
  'admin.suspended_users': 'Suspended',
  'admin.posts_count': 'Posts',
  'admin.detections_count': 'Detections',
  'admin.health_mongo': 'MongoDB',
  'admin.health_flask': 'Flask ML server',
  'admin.health_groq': 'Groq API',
  'admin.online': 'Online',
  'admin.offline': 'Offline',
  'admin.detections_30d': 'Disease Detections — last 30 days',
  'admin.detections_30d_sub': 'Daily count from MongoDB',
  'admin.search_users': 'Search name or email...',
  'admin.empty_users': 'No users found',
  'admin.empty_posts': 'No posts yet',
  'admin.empty_detections': 'No detections yet — open the mobile app and try the disease detection feature.',
  'admin.col_user': 'User',
  'admin.col_status': 'Status',
  'admin.col_posts': 'Posts',
  'admin.col_detections': 'Detections',
  'admin.col_joined': 'Joined',
  'admin.col_when': 'When',
  'admin.col_disease': 'Predicted Disease',
  'admin.col_confidence': 'Confidence',
  'admin.col_actions': 'Actions',
  'admin.status_active': 'Active',
  'admin.status_suspended': 'Suspended',
  'admin.status_verified': 'Verified',
  'admin.status_admin': 'ADMIN',
  'admin.action_suspend': 'Suspend',
  'admin.action_activate': 'Activate',
  'admin.action_delete': 'Delete',
  'admin.action_pin': 'Pin',
  'admin.action_unpin': 'Unpin',
  'admin.confirm_suspend_title': 'Suspend user',
  'admin.confirm_suspend_body':
      'They won\'t be able to log in until reactivated.',
  'admin.confirm_delete_user_title': 'Delete user',
  'admin.confirm_delete_user_body':
      'Permanently delete this user and ALL of their posts, notifications and disease history? This cannot be undone.',
  'admin.confirm_delete_post_title': 'Delete post',
  'admin.confirm_delete_post_body': 'Delete this post permanently?',
  'admin.confirm_delete_forever': 'Delete forever',
  'admin.user_suspended': 'User suspended',
  'admin.user_activated': 'User activated',
  'admin.user_deleted': 'User deleted',
  'admin.post_deleted': 'Post deleted',
  'admin.post_pinned': 'Pinned',
  'admin.post_unpinned': 'Unpinned',
  'admin.pinned_label': 'Pinned',
  'admin.solved_label': 'Solved',
  'admin.no_title': '(no title)',
  'admin.failed': 'Failed',
  'admin.session_expired': 'Session expired. Please sign in again.',
  'admin.access_denied':
      'Access denied. Your account is no longer an admin.',
  'admin.prev': 'Prev',
  'admin.next': 'Next',
  'admin.page_of': 'Page',
  'admin.showing': 'Showing',
  'admin.of': 'of',
};

const Map<String, String> _ne = {
  // Splash + auth
  'app.name': 'एग्रोसेतु',
  'app.tagline': 'हाम्रो लागि',
  'auth.login': 'लग इन',
  'auth.signup': 'दर्ता गर्नुहोस्',
  'auth.logout': 'लग आउट',
  'auth.logout_confirm':
      'के तपाईं लग आउट गर्न चाहनुहुन्छ? तपाईं लग इन स्क्रिनमा फर्किनुहुनेछ।',
  'auth.cancel': 'रद्द गर्नुहोस्',

  // Dashboard / nav tabs
  'nav.home': 'गृह',
  'nav.community': 'समुदाय',
  'nav.market': 'बजार',
  'nav.assistant': 'सहायक',
  'nav.profile': 'प्रोफाइल',
  'nav.dashboard': 'ड्यासबोर्ड',
  'nav.disease': 'रोग',

  // Profile
  'profile.title': 'प्रोफाइल',
  'profile.edit': 'प्रोफाइल सम्पादन',
  'profile.location': 'ठेगाना',
  'profile.user_default': 'प्रयोगकर्ता',
  'profile.detections': 'पहिचान',
  'profile.discussions': 'छलफल',
  'profile.market_tips': 'बजार सुझाव',
  'profile.farm_information': 'खेत जानकारी',
  'profile.farm_size': 'खेतको आकार',
  'profile.main_crops': 'मुख्य बाली',
  'profile.member_since': 'सदस्य भएको',
  'profile.preferences': 'प्राथमिकताहरू',
  'profile.notifications': 'सूचनाहरू',
  'profile.notifications_enabled': 'सूचनाहरू सक्षम गरियो',
  'profile.notifications_muted': 'सूचनाहरू मौन गरियो',
  'profile.picture_updated': 'प्रोफाइल तस्बिर अद्यावधिक गरियो',
  'profile.menu.settings': 'सेटिङ्ग',
  'profile.menu.privacy': 'गोपनीयता र सुरक्षा',
  'profile.menu.terms': 'नियम र सर्तहरू',
  'profile.menu.support': 'सहयोग सम्पर्क',

  // Edit Profile
  'edit_profile.title': 'प्रोफाइल सम्पादन',
  'edit_profile.name': 'नाम',
  'edit_profile.email': 'इमेल',
  'edit_profile.phone': 'फोन',
  'edit_profile.location': 'ठेगाना',
  'edit_profile.farm_size': 'खेतको आकार (हेक्टर)',
  'edit_profile.crops': 'मुख्य बाली (अल्पविरामले छुट्याउनुहोस्)',
  'edit_profile.save': 'परिवर्तन सुरक्षित गर्नुहोस्',
  'edit_profile.name_required': 'नाम आवश्यक छ',
  'edit_profile.invalid_email': 'मान्य इमेल राख्नुहोस्',
  'edit_profile.updated': 'प्रोफाइल सफलतापूर्वक अद्यावधिक गरियो',
  'edit_profile.saved_local': 'स्थानीय रूपमा सुरक्षित। सिङ्क समस्या:',

  // Settings
  'settings.title': 'सेटिङ्ग',
  'settings.section_app': 'एप सेटिङ्ग',
  'settings.section_account': 'खाता सेटिङ्ग',
  'settings.language': 'भाषा',
  'settings.location_services': 'स्थान सेवाहरू',
  'settings.location_help': 'हामीलाई राम्रो सेवा दिन सहयोग गर्नुहोस्',
  'settings.data_privacy': 'डाटा र गोपनीयता',
  'settings.manage_prefs': 'आफ्ना प्राथमिकता व्यवस्थापन गर्नुहोस्',
  'settings.change_password': 'पासवर्ड परिवर्तन',
  'settings.update_password': 'आफ्नो पासवर्ड अद्यावधिक गर्नुहोस्',
  'settings.delete_account': 'खाता मेटाउनुहोस्',
  'settings.delete_subtitle': 'आफ्नो खाता स्थायी रूपमा मेटाउनुहोस्',
  'settings.delete_warn':
      'यसले तपाईंको खाता, पोस्ट, सूचना र रोग इतिहास स्थायी रूपमा मेटाउनेछ। यो कार्य फिर्ता गर्न सकिँदैन।',
  'settings.delete_button': 'मेटाउनुहोस्',
  'settings.not_signed_in': 'लग इन भएको छैन',
  'settings.on': 'सक्षम',
  'settings.off': 'निष्क्रिय',

  // Privacy & Security
  'privacy.title': 'गोपनीयता र सुरक्षा',
  'privacy.section_settings': 'गोपनीयता सेटिङ्ग',
  'privacy.profile_visibility': 'प्रोफाइल देखिने',
  'privacy.profile_visibility_sub': 'अरूलाई आफ्नो प्रोफाइल देख्न दिनुहोस्',
  'privacy.activity_logging': 'गतिविधि लग',
  'privacy.activity_logging_sub': 'आफ्नो खेती गतिविधि लग गर्नुहोस्',
  'privacy.section_data': 'डाटा व्यवस्थापन',
  'privacy.download_data': 'आफ्नो डाटा डाउनलोड',
  'privacy.download_data_sub': 'आफ्नो व्यक्तिगत डाटाको प्रतिलिपि लिनुहोस्',
  'privacy.clear_cache': 'क्यास खाली गर्नुहोस्',
  'privacy.clear_cache_sub': 'ठाउँ खाली गर्न क्यास डाटा हटाउनुहोस्',
  'privacy.clear_warn':
      'यसले यो उपकरणमा क्यास गरिएका प्राथमिकता, मौसम, सूचना र रोग इतिहास हटाउँछ। तपाईंको खाता लग इन रहन्छ।',
  'privacy.clear_button': 'खाली गर्नुहोस्',
  'privacy.cache_cleared': 'क्यास खाली गरियो',
  'privacy.export_share_text': 'मेरो एग्रोसेतु डाटा निर्यात',
  'privacy.signin_required':
      'आफ्नो डाटा डाउनलोड गर्न लग इन गर्नुहोस्',

  // Contact Support
  'support.title': 'सहयोग सम्पर्क',
  'support.get_in_touch': 'सम्पर्कमा रहनुहोस्',
  'support.phone': 'फोन',
  'support.email': 'इमेल',
  'support.address': 'ठेगाना',
  'support.address_value': 'काठमाडौं, नेपाल',
  'support.send_us': 'हामीलाई सन्देश पठाउनुहोस्',
  'support.subject': 'विषय',
  'support.subject_hint': 'विषय राख्नुहोस्',
  'support.message': 'सन्देश',
  'support.message_hint': 'यहाँ सन्देश टाइप गर्नुहोस्...',
  'support.send': 'सन्देश पठाउनुहोस्',
  'support.fill_all': 'कृपया सबै फिल्ड भर्नुहोस्',
  'support.sent_ok': 'सन्देश सफलतापूर्वक पठाइयो!',

  // Change Password
  'pw.title': 'पासवर्ड परिवर्तन',
  'pw.subtitle': 'आफ्नो खाताको पासवर्ड अद्यावधिक गर्नुहोस्',
  'pw.current': 'वर्तमान पासवर्ड',
  'pw.new': 'नयाँ पासवर्ड',
  'pw.confirm': 'नयाँ पासवर्ड पुष्टि गर्नुहोस्',
  'pw.hint':
      '८ वा बढी अक्षर, ठूलो र सानो अक्षर, अंक र चिन्ह प्रयोग गर्नुहोस्।',
  'pw.update': 'पासवर्ड अद्यावधिक',
  'pw.required': 'सबै फिल्ड आवश्यक छन्',
  'pw.mismatch': 'नयाँ पासवर्डहरू मेल खाँदैनन्',
  'pw.weak':
      'पासवर्डमा ८+ अक्षर, ठूलो, सानो, अंक र चिन्ह चाहिन्छ',
  'pw.same': 'नयाँ पासवर्ड वर्तमान पासवर्डभन्दा फरक हुनुपर्छ',
  'pw.changed': 'पासवर्ड सफलतापूर्वक परिवर्तन गरियो',
  'pw.forgot': 'वर्तमान पासवर्ड बिर्सनुभयो?',

  // Language
  'lang.title': 'भाषा',
  'lang.subtitle': 'आफ्नो रुचाइएको भाषा छान्नुहोस्',
  'lang.saving': 'सुरक्षित गरिँदै...',
  'lang.set_to': 'भाषा सेट गरियो',

  // Location Services
  'loc.title': 'स्थान सेवाहरू',
  'loc.features': 'स्थान सुविधाहरू',
  'loc.device': 'उपकरण स्थान',
  'loc.permission': 'एप अनुमति',
  'loc.enabled': 'सक्षम',
  'loc.disabled': 'निष्क्रिय',
  'loc.last_position': 'अन्तिम ज्ञात स्थान',
  'loc.device_settings': 'उपकरण सेटिङ्ग',
  'loc.app_permissions': 'एप अनुमति',
  'loc.help_text':
      'मौसम पूर्वानुमान, नजिकैको बजार मूल्य र रोग सतर्कताका लागि प्रयोग हुन्छ।',
  'loc.enable_first':
      'आफ्नो उपकरण सेटिङमा स्थान सक्षम गर्नुहोस्, अनि फेरि प्रयास गर्नुहोस्।',
  'loc.denied_forever':
      'अनुमति स्थायी रूपमा अस्वीकृत। अनुमति दिन सेटिङ खोल्नुहोस्।',
  'loc.denied': 'अनुमति अस्वीकृत',
  'loc.cant_get': 'स्थान प्राप्त गर्न सकिएन:',
  'loc.enabled_msg': 'स्थान सेवाहरू सक्षम गरियो',
  'loc.enabled_no_fix':
      'सक्षम भयो, तर अहिले स्थान प्राप्त भएन',
  'loc.turned_off': 'स्थान सुविधा बन्द गरियो',
  'loc.open_settings_hint':
      'यो व्यवस्थापन गर्न सिस्टम सेटिङ → गोपनीयता र सुरक्षा खोल्नुहोस्।',

  // Admin panel
  'admin.tab': 'एडमिन',
  'admin.dashboard': 'ड्यासबोर्ड',
  'admin.users': 'प्रयोगकर्ताहरू',
  'admin.posts': 'पोस्टहरू',
  'admin.detections': 'पहिचान',
  'admin.subtitle': 'प्रणालीको स्वास्थ्य र मुख्य तथ्याङ्क',
  'admin.users_subtitle': 'सबै दर्ता भएका किसानहरूको व्यवस्थापन',
  'admin.posts_subtitle': 'किसान फोरम मध्यस्थता',
  'admin.detections_subtitle':
      'मोबाइल एपबाट लग गरिएको लाइभ AI पूर्वानुमान',
  'admin.total_users': 'कुल प्रयोगकर्ता',
  'admin.active_users': 'सक्रिय',
  'admin.suspended_users': 'निलम्बित',
  'admin.posts_count': 'पोस्ट',
  'admin.detections_count': 'पहिचान',
  'admin.health_mongo': 'मोङ्गोडिबी',
  'admin.health_flask': 'Flask ML सर्भर',
  'admin.health_groq': 'Groq API',
  'admin.online': 'अनलाइन',
  'admin.offline': 'अफलाइन',
  'admin.detections_30d': 'रोग पहिचान — पछिल्ला ३० दिन',
  'admin.detections_30d_sub': 'मोङ्गोडिबीबाट दैनिक गणना',
  'admin.search_users': 'नाम वा इमेल खोज्नुहोस्...',
  'admin.empty_users': 'प्रयोगकर्ता फेला परेन',
  'admin.empty_posts': 'अहिले कुनै पोस्ट छैन',
  'admin.empty_detections':
      'अहिले कुनै पहिचान छैन — मोबाइल एप खोलेर रोग पहिचान सुविधा प्रयोग गर्नुहोस्।',
  'admin.col_user': 'प्रयोगकर्ता',
  'admin.col_status': 'स्थिति',
  'admin.col_posts': 'पोस्ट',
  'admin.col_detections': 'पहिचान',
  'admin.col_joined': 'सामेल भएको',
  'admin.col_when': 'कहिले',
  'admin.col_disease': 'पूर्वानुमान गरिएको रोग',
  'admin.col_confidence': 'विश्वास',
  'admin.col_actions': 'कार्यहरू',
  'admin.status_active': 'सक्रिय',
  'admin.status_suspended': 'निलम्बित',
  'admin.status_verified': 'प्रमाणित',
  'admin.status_admin': 'एडमिन',
  'admin.action_suspend': 'निलम्बित गर्नुहोस्',
  'admin.action_activate': 'सक्रिय गर्नुहोस्',
  'admin.action_delete': 'मेटाउनुहोस्',
  'admin.action_pin': 'पिन गर्नुहोस्',
  'admin.action_unpin': 'पिन हटाउनुहोस्',
  'admin.confirm_suspend_title': 'प्रयोगकर्ता निलम्बित',
  'admin.confirm_suspend_body':
      'पुनः सक्रिय नभएसम्म यिनी लग इन गर्न सक्दैनन्।',
  'admin.confirm_delete_user_title': 'प्रयोगकर्ता मेटाउनुहोस्',
  'admin.confirm_delete_user_body':
      'यो प्रयोगकर्ता र उनका सबै पोस्ट, सूचना र रोग इतिहास स्थायी रूपमा मेटाउने? यो फिर्ता गर्न मिल्दैन।',
  'admin.confirm_delete_post_title': 'पोस्ट मेटाउनुहोस्',
  'admin.confirm_delete_post_body':
      'यो पोस्ट स्थायी रूपमा मेटाउने हो?',
  'admin.confirm_delete_forever': 'सधैंका लागि मेटाउनुहोस्',
  'admin.user_suspended': 'प्रयोगकर्ता निलम्बित गरियो',
  'admin.user_activated': 'प्रयोगकर्ता सक्रिय गरियो',
  'admin.user_deleted': 'प्रयोगकर्ता मेटाइयो',
  'admin.post_deleted': 'पोस्ट मेटाइयो',
  'admin.post_pinned': 'पिन गरियो',
  'admin.post_unpinned': 'पिन हटाइयो',
  'admin.pinned_label': 'पिन गरिएको',
  'admin.solved_label': 'समाधान',
  'admin.no_title': '(शीर्षक छैन)',
  'admin.failed': 'असफल',
  'admin.session_expired':
      'सत्र समाप्त भयो। कृपया फेरि लग इन गर्नुहोस्।',
  'admin.access_denied':
      'पहुँच अस्वीकृत। तपाईंको खाता अब एडमिन छैन।',
  'admin.prev': 'अघिल्लो',
  'admin.next': 'अर्को',
  'admin.page_of': 'पृष्ठ',
  'admin.showing': 'देखाइँदै',
  'admin.of': '/',
};
