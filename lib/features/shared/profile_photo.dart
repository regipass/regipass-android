import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../l10n/app_strings.dart';
import '../../services/firebase_refs.dart';
import 'common_widgets.dart';
import 'media_viewer.dart';

/// info.js ile aynı sınır.
const int kMaxProfilePhotoBytes = 3 * 1024 * 1024;

/// Kaynak seçimi (galeri / kamera) sorup fotoğrafı döndürür.
///
/// İzinler: Android'de sistem fotoğraf seçicisi izin istemez, kamera için
/// manifest'teki CAMERA izni yeterlidir. iOS'ta Info.plist'e eklenen
/// NSPhotoLibraryUsageDescription ve NSCameraUsageDescription açıklamaları
/// olmadan uygulama seçici açıldığı anda çöker — ikisi de tanımlı.
/// Fotoğraf seçer ve kırpma ekranını açar. [circle]: profil fotoğrafı için
/// yuvarlak, organizatör logosu için kare çerçeve. Kırpma iptal edilirse null.
Future<XFile?> pickProfilePhoto(BuildContext context, {bool circle = true}) async {
  final ImageSource? source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: context.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (BuildContext sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: sheetContext.hairline,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(
              Icons.photo_library_outlined,
              color: sheetContext.brandInk,
            ),
            title: Text(sheetContext.t('form.photoFromGallery')),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
          ),
          ListTile(
            leading: Icon(
              Icons.photo_camera_outlined,
              color: sheetContext.brandInk,
            ),
            title: Text(sheetContext.t('form.photoFromCamera')),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (source == null) return null;

  final XFile? picked = await ImagePicker().pickImage(
    source: source,
    maxWidth: 2048,
    imageQuality: 90,
  );
  if (picked == null || !context.mounted) return null;
  final bool en = context.lang == 'en';
  final String title = circle
      ? (en ? 'Crop photo' : 'Fotoğrafı kırp')
      : (en ? 'Crop logo' : 'Logoyu kırp');
  final CroppedFile? cropped = await ImageCropper().cropImage(
    sourcePath: picked.path,
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    maxWidth: 1024,
    maxHeight: 1024,
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: 88,
    uiSettings: <PlatformUiSettings>[
      AndroidUiSettings(
        toolbarTitle: title,
        toolbarColor: BrandColors.red,
        toolbarWidgetColor: Colors.white,
        activeControlsWidgetColor: BrandColors.red,
        lockAspectRatio: true,
        hideBottomControls: false,
        cropStyle: circle ? CropStyle.circle : CropStyle.rectangle,
        aspectRatioPresets: <CropAspectRatioPresetData>[
          CropAspectRatioPreset.square,
        ],
      ),
      IOSUiSettings(
        title: title,
        doneButtonTitle: en ? 'Done' : 'Bitti',
        cancelButtonTitle: en ? 'Cancel' : 'Vazgeç',
        aspectRatioLockEnabled: true,
        resetAspectRatioEnabled: false,
        aspectRatioPickerButtonHidden: true,
        cropStyle: circle ? CropStyle.circle : CropStyle.rectangle,
      ),
    ],
  );
  if (cropped == null) return null;
  return XFile(cropped.path, mimeType: 'image/jpeg', name: 'photo.jpg');
}

/// Seçilen dosyayı Storage'a yükler ve indirme adresini döndürür.
///
/// Uzantı değiştiğinde eski dosya adı da değişir; bu yüzden yeni yüklemeden
/// sonra eski yol temizlenir (yoksa kullanılmayan dosyalar birikir).
Future<({String url, String path})> uploadStudentPhoto({
  required String uid,
  required XFile file,
  required String previousPath,
}) => _uploadPickedImage(
  file: file,
  path: 'student_photos/$uid/profile',
  previousPath: previousPath,
);

/// Kulüp logosu — öğrenci fotoğrafıyla aynı akış, ayrı Storage klasörü.
///
/// Logo etkinliklerde de görüneceği için adres herkese açık okunabilir
/// olmalı; Storage kuralı için bkz. `docs/kulup-logosu.md`.
Future<({String url, String path})> uploadClubLogo({
  required String uid,
  required XFile file,
  required String previousPath,
}) => _uploadPickedImage(
  file: file,
  path: 'club_logos/$uid/logo',
  previousPath: previousPath,
);

/// İP-KP: onaylı kulübün yeni logosu ayrı dosyaya yüklenir ve onaya gider;
/// mevcut logo onaylanana kadar yerinde kalır (eskisi silinmez).
Future<({String url, String path})> uploadPendingClubLogo({
  required String uid,
  required XFile file,
}) => _uploadPickedImage(
  file: file,
  path: 'club_logos/$uid/pending-${DateTime.now().millisecondsSinceEpoch}',
  previousPath: '',
);

/// Ortak yükleme adımı: `$basePath.$uzantı` olarak yazar, eskiyi siler.
Future<({String url, String path})> _uploadPickedImage({
  required XFile file,
  required String path,
  required String previousPath,
}) async {
  final String ext = (file.name.split('.').lastOrNull ?? 'jpg').toLowerCase();
  final String fullPath = '$path.$ext';

  await fbStorage.ref(fullPath).putFile(File(file.path));
  final String url = await fbStorage.ref(fullPath).getDownloadURL();

  if (previousPath.isNotEmpty && previousPath != fullPath) {
    try {
      await fbStorage.ref(previousPath).delete();
    } catch (_) {
      // Eski dosya yoksa yok say.
    }
  }

  return (url: url, path: fullPath);
}

/// Profil fotoğrafı + sağ altında değiştirme kalemi.
///
/// Fotoğraf yoksa boş bir hesap simgesi gösterilir; kalem her iki durumda da
/// aynı yerde durur ki kullanıcı fotoğrafın nereden değiştiğini arayıp
/// bulmak zorunda kalmasın.
class EditableAvatar extends StatelessWidget {
  const EditableAvatar({
    required this.photoUrl,
    required this.onEdit,
    this.radius = 46,
    this.busy = false,
    super.key,
  });

  final String photoUrl;
  final VoidCallback onEdit;
  final double radius;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          GestureDetector(
            onTap: busy || photoUrl.isEmpty
                ? null
                : () => openMedia(
                    context,
                    source: photoUrl,
                    title: context.t('form.photo'),
                    contentType: 'image/jpeg',
                  ),
            child: CircleAvatar(
              radius: radius,
              backgroundColor: context.subtleFill,
              backgroundImage: photoUrl.isNotEmpty
                  ? NetworkImage(photoUrl)
                  : null,
              child: photoUrl.isEmpty
                  ? Icon(
                      Icons.person_outline,
                      size: radius * 0.9,
                      color: context.hairline,
                    )
                  : null,
            ),
          ),
          if (busy)
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x66000000),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: BrandColors.white,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Material(
              color: BrandColors.red,
              // Kenarlık kartın zeminiyle aynı renk: rozet fotoğraftan
              // kesilmiş gibi durur, koyu modda beyaz halka olarak sırıtmaz.
              shape: CircleBorder(
                side: BorderSide(color: context.surface, width: 2.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: busy ? null : onEdit,
                child: const Padding(
                  padding: EdgeInsets.all(7),
                  child: Icon(Icons.edit, size: 15, color: BrandColors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kulüp logosu + sağ altında değiştirme kalemi.
///
/// [EditableAvatar]'ın kulüp karşılığı: kulübün kimliği yuvarlak bir portre
/// değil, kare bir logo. Logo yüklenmemişken kalem yine aynı yerde durur —
/// kulüp fotoğrafı nereden ekleyeceğini aramak zorunda kalmasın.
class EditableClubLogo extends StatelessWidget {
  const EditableClubLogo({
    required this.logoUrl,
    required this.onEdit,
    this.size = 96,
    this.busy = false,
    super.key,
  });

  final String logoUrl;
  final VoidCallback onEdit;
  final double size;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          GestureDetector(
            onTap: busy || logoUrl.isEmpty
                ? null
                : () => openMedia(
                    context,
                    source: logoUrl,
                    title: context.t('clubAccount.logo'),
                    contentType: 'image/jpeg',
                  ),
            child: ClubLogoBox(
              logoUrl: logoUrl,
              size: size,
              radius: 24,
              fill: true,
            ),
          ),
          if (busy)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: const Color(0x66000000),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: BrandColors.white,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Material(
              color: BrandColors.red,
              // Kenarlık kartın zeminiyle aynı renk: rozet logodan kesilmiş
              // gibi durur, koyu modda beyaz halka olarak sırıtmaz.
              shape: CircleBorder(
                side: BorderSide(color: context.surface, width: 2.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: busy ? null : onEdit,
                child: const Padding(
                  padding: EdgeInsets.all(7),
                  child: Icon(Icons.edit, size: 15, color: BrandColors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
