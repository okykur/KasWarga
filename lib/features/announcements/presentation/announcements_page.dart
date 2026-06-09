import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/providers/app_providers.dart';
import '../../auth/presentation/auth_controller.dart';

class AnnouncementsPage extends ConsumerWidget {
  const AnnouncementsPage({super.key, this.readOnly = false});
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).profile!;
    final communityId = profile.communityId ?? AppConstants.demoCommunityId;
    final announcements = ref.watch(announcementsProvider(communityId));
    return PageScaffold(
      title: 'Pengumuman',
      subtitle: readOnly
          ? 'Informasi terbaru dari pengurus komunitas.'
          : 'Bagikan kabar penting dan pin pengumuman prioritas.',
      action: readOnly
          ? null
          : AppButton(
              label: 'Buat Pengumuman',
              icon: Icons.add_rounded,
              onPressed: () => _showForm(
                context,
                ref,
                profile: profile,
              ),
            ),
      child: announcements.when(
        loading: () => const SizedBox(height: 360, child: LoadingView()),
        error: (error, _) => ErrorView(message: '$error'),
        data: (items) {
          if (items.isEmpty) {
            return const Card(
              child: SizedBox(
                height: 300,
                child: EmptyState(
                  title: 'Belum ada pengumuman',
                  message: 'Informasi komunitas akan tampil di sini.',
                  icon: Icons.campaign_outlined,
                ),
              ),
            );
          }
          return Column(
            children: [
              for (final item in items) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (item.isPinned) ...[
                              const Icon(
                                Icons.push_pin_rounded,
                                size: 18,
                                color: AppColors.amber,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                item.title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            if (!readOnly) ...[
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () => _showForm(
                                  context,
                                  ref,
                                  profile: profile,
                                  announcement: item,
                                ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Hapus',
                                onPressed: () async {
                                  final confirmed =
                                      await ConfirmationDialog.show(
                                    context,
                                    title: 'Hapus pengumuman?',
                                    message:
                                        'Pengumuman yang dihapus tidak dapat dikembalikan.',
                                    confirmLabel: 'Hapus',
                                    isDanger: true,
                                  );
                                  if (!confirmed) return;
                                  await ref
                                      .read(appRepositoryProvider)
                                      .deleteAnnouncement(item.id);
                                  ref.invalidate(announcementsProvider);
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.danger,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.content,
                          style: const TextStyle(height: 1.6),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          AppFormatters.date(item.createdAt),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _showForm(
    BuildContext context,
    WidgetRef ref, {
    required UserProfile profile,
    Announcement? announcement,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AnnouncementForm(
        profile: profile,
        announcement: announcement,
      ),
    );
    if (saved == true) ref.invalidate(announcementsProvider);
  }
}

class _AnnouncementForm extends ConsumerStatefulWidget {
  const _AnnouncementForm({required this.profile, this.announcement});
  final UserProfile profile;
  final Announcement? announcement;

  @override
  ConsumerState<_AnnouncementForm> createState() => _AnnouncementFormState();
}

class _AnnouncementFormState extends ConsumerState<_AnnouncementForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _content;
  late bool _pinned;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.announcement?.title);
    _content = TextEditingController(text: widget.announcement?.content);
    _pinned = widget.announcement?.isPinned ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
          widget.announcement == null
              ? 'Buat Pengumuman'
              : 'Edit Pengumuman',
        ),
        content: SizedBox(
          width: 540,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  label: 'Judul',
                  controller: _title,
                  validator: (value) =>
                      Validators.required(value, field: 'Judul'),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Isi Pengumuman',
                  controller: _content,
                  maxLines: 6,
                  validator: (value) =>
                      Validators.required(value, field: 'Isi pengumuman'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pin pengumuman'),
                  value: _pinned,
                  onChanged: (value) => setState(() => _pinned = value),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: _saving
                ? null
                : () async {
                    if (!_formKey.currentState!.validate()) return;
                    setState(() => _saving = true);
                    await ref.read(appRepositoryProvider).saveAnnouncement(
                          id: widget.announcement?.id,
                          communityId: widget.profile.communityId ??
                              AppConstants.demoCommunityId,
                          title: _title.text,
                          content: _content.text,
                          isPinned: _pinned,
                          userId: widget.profile.id,
                        );
                    if (mounted) Navigator.pop(context, true);
                  },
            child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
          ),
        ],
      );
}
