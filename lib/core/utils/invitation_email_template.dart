import 'app_formatters.dart';

class InvitationEmailTemplate {
  const InvitationEmailTemplate._();

  static const subject = 'Anda diundang bergabung ke KasWarga';

  static String body({
    required String communityName,
    required String role,
    required String invitationLink,
    required DateTime expiresAt,
  }) =>
      '''
Halo,

Anda diundang untuk bergabung ke komunitas $communityName di aplikasi KasWarga sebagai $role.

Klik link berikut untuk menerima undangan:
$invitationLink

Undangan ini berlaku sampai ${AppFormatters.date(expiresAt)}.

Jika Anda tidak mengenal komunitas ini, abaikan email ini.

Terima kasih,
KasWarga
''';
}
