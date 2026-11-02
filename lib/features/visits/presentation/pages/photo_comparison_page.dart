import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/patient_photo.dart';
import '../../domain/usecases/get_patient_photos.dart';

/// Lets the doctor pick any two photos from a patient's whole visit history
/// and see them side by side, labeled "قبل"/"بعد" by date — not a draggable
/// slider (too fiddly to be reliable on iPad), just two plain panels that
/// always sort chronologically regardless of tap order.
class PhotoComparisonPage extends StatefulWidget {
  const PhotoComparisonPage({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  final int patientId;
  final String patientName;

  @override
  State<PhotoComparisonPage> createState() => _PhotoComparisonPageState();
}

class _PhotoComparisonPageState extends State<PhotoComparisonPage> {
  static final _dateFormat = DateFormat('yyyy/MM/dd');

  bool _loading = true;
  String? _error;
  List<PatientPhoto> _photos = const [];
  final List<PatientPhoto> _selected = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await sl<GetPatientPhotos>().call(widget.patientId);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _error = failure.message;
        _loading = false;
      }),
      (photos) => setState(() {
        _photos = photos;
        _loading = false;
      }),
    );
  }

  void _toggle(PatientPhoto photo) {
    setState(() {
      final index = _selected.indexWhere((p) => p.id == photo.id);
      if (index != -1) {
        _selected.removeAt(index);
      } else {
        if (_selected.length >= 2) _selected.removeAt(0);
        _selected.add(photo);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sortedSelection = [..._selected]
      ..sort((a, b) => a.visitDate.compareTo(b.visitDate));

    return Scaffold(
      appBar: AppBar(title: Text('مقارنة صور — ${widget.patientName}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            )
          : _photos.isEmpty
          ? const _EmptyPhotos()
          : ResponsiveBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (sortedSelection.length == 2)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        0,
                      ),
                      child: _ComparisonPanel(
                        before: sortedSelection[0],
                        after: sortedSelection[1],
                        dateFormat: _dateFormat,
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        0,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.sky,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.aqua,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                _selected.isEmpty
                                    ? 'اختاري صورتين من الأسفل للمقارنة بينهما.'
                                    : 'اختاري صورة واحدة أخرى لإتمام المقارنة.',
                                style: const TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'كل صور المريض (${_photos.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: AppSpacing.sm,
                            mainAxisSpacing: AppSpacing.sm,
                            childAspectRatio: 0.82,
                          ),
                      itemCount: _photos.length,
                      itemBuilder: (context, index) {
                        final photo = _photos[index];
                        final selectionIndex = sortedSelection.indexWhere(
                          (p) => p.id == photo.id,
                        );
                        return _PhotoTile(
                          photo: photo,
                          dateFormat: _dateFormat,
                          selectedLabel: selectionIndex == -1
                              ? null
                              : (selectionIndex == 0 ? 'قبل' : 'بعد'),
                          onTap: () => _toggle(photo),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ComparisonPanel extends StatelessWidget {
  const _ComparisonPanel({
    required this.before,
    required this.after,
    required this.dateFormat,
  });

  final PatientPhoto before;
  final PatientPhoto after;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ComparisonSide(
            label: 'قبل',
            photo: before,
            dateFormat: dateFormat,
            color: AppColors.inkSoft,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ComparisonSide(
            label: 'بعد',
            photo: after,
            dateFormat: dateFormat,
            color: AppColors.ok,
          ),
        ),
      ],
    );
  }
}

class _ComparisonSide extends StatelessWidget {
  const _ComparisonSide({
    required this.label,
    required this.photo,
    required this.dateFormat,
    required this.color,
  });

  final String label;
  final PatientPhoto photo;
  final DateFormat dateFormat;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
        ),
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.memory(photo.imageData, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          dateFormat.format(photo.visitDate),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.dateFormat,
    required this.selectedLabel,
    required this.onTap,
  });

  final PatientPhoto photo;
  final DateFormat dateFormat;
  final String? selectedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = selectedLabel != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? AppColors.aqua : Colors.black12,
                        width: selected ? 2.5 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.memory(
                      photo.imageData,
                      fit: BoxFit.cover,
                      cacheWidth: 200,
                      cacheHeight: 200,
                    ),
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.aqua,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        selectedLabel!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dateFormat.format(photo.visitDate),
            style: const TextStyle(fontSize: 9.5, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _EmptyPhotos extends StatelessWidget {
  const _EmptyPhotos();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.sky,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.aqua,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'لا توجد صور بعد',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'أضيفي صورًا من داخل زيارات الفحص ليمكن مقارنتها هنا.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
