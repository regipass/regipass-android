/// Klavye kapatma davranışı — tek yerde toplanmış üç çıkış yolu.
///
/// Kullanıcı yazmayı bitirdiğinde klavyeden çıkmanın üç yolu da her ekranda,
/// pop-up'ta ve alt sayfada aynı şekilde çalışır:
///
///   1. **Boş bir yere dokunma** — [DismissKeyboardOnTap] uygulamanın kökünde
///      duruyor (bkz. `lib/app/app.dart`), dolayısıyla açık bir pencerenin
///      içindeki boşluğa dokunmak da pencereyi kapatmadan klavyeyi kapatır.
///   2. **Listeyi sürükleme** — [RegipassScrollBehavior] `MaterialApp` üzerinden
///      veriliyor; kaydırılabilir her alan sürükleme başlar başlamaz klavyeyi
///      indirir.
///   3. **Klavyedeki "Bitti"** — tek satırlık alanlarda Flutter'ın kendi
///      varsayılanı (`TextInputAction.done`) zaten kapatıyor. Çok satırlı
///      alanlarda dönüş tuşu satır sonu eklediği için klavyede kapatan bir tuş
///      hiç çizilmez; oradaki boşluğu [KeyboardDoneBar] dolduruyor.
///
/// Üçü de iOS ve Android'de aynıdır; platform tarafında yalnızca Android'in
/// `windowSoftInputMode="adjustResize"` ayarı şarttır (AndroidManifest.xml),
/// yoksa klavye açılınca düzen yukarı kaymaz ve yazılan metin klavyenin
/// altında kalır.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../l10n/app_strings.dart';

/// Odağı bırakır; yazılım klavyesi kapanır.
void dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

/// Alt ağacındaki boş bir noktaya dokunulduğunda klavyeyi kapatır.
///
/// `translucent`: dokunuş alttaki widget'lara da ulaşır. Bir düğme, liste
/// satırı ya da metin alanı dokunuşu sahiplenirse klavye kapanmaz — yalnızca
/// hiçbir şeyin ilgilenmediği "boş yer" dokunuşları buraya düşer.
class DismissKeyboardOnTap extends StatelessWidget {
  const DismissKeyboardOnTap({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    // Erişilebilirlik ağacında ekran boyunda "dokunulabilir" bir alan
    // oluşmasın; ekran okuyucu bunu bir düğme gibi okumamalı.
    excludeFromSemantics: true,
    onTap: dismissKeyboard,
    child: child,
  );
}

/// Sürükleme başlar başlamaz klavyeyi kapatan uygulama geneli kaydırma
/// davranışı.
///
/// `MaterialApp.scrollBehavior` ile verildiği için tek tek `ListView`'lara
/// `keyboardDismissBehavior` yazmak gerekmez; pop-up ve alt sayfaların içindeki
/// listeler de kapsama girer.
class RegipassScrollBehavior extends MaterialScrollBehavior {
  const RegipassScrollBehavior();

  @override
  ScrollViewKeyboardDismissBehavior getKeyboardDismissBehavior(
    BuildContext context,
  ) => ScrollViewKeyboardDismissBehavior.onDrag;
}

/// Odaktaki alanın klavyesinde kapatan bir tuş var mı?
///
/// Flutter'ın kendi varsayılanıyla aynı hesap: eylem açıkça verilmemişse çok
/// satırlı alan `newline`, diğerleri `done` alır. `newline` demek, klavyede
/// yalnızca satır sonu ekleyen bir dönüş tuşu var demektir — kullanıcının
/// klavyeden çıkabileceği bir tuş yok.
bool focusedFieldHasNoDoneKey() {
  final BuildContext? context = FocusManager.instance.primaryFocus?.context;
  if (context == null || !context.mounted) return false;

  final EditableTextState? field = context
      .findAncestorStateOfType<EditableTextState>();
  if (field == null) return false;

  final EditableText input = field.widget;
  final TextInputAction action =
      input.textInputAction ??
      (input.keyboardType == TextInputType.multiline
          ? TextInputAction.newline
          : TextInputAction.done);

  return action == TextInputAction.newline;
}

/// Çok satırlı bir alan yazılırken klavyenin hemen üstünde beliren "Bitti"
/// çubuğu.
///
/// Çok satırlı alanda dönüş tuşu satır sonu ekler; iOS'ta klavyeyi kapatan
/// hiçbir tuş kalmaz, Android'de de yalnızca sistem geri hareketi kalır. Bu
/// çubuk olmadan kullanıcı yazdığını göremeden pencereyi kapatmak zorunda
/// kalıyordu.
///
/// Yalnızca (a) klavye açıkken ve (b) odaktaki alanın kendi "Bitti" tuşu
/// yokken görünür; tek satırlık alanlarda ekranda ikinci bir çubuk çıkmaz.
class KeyboardDoneBar extends StatefulWidget {
  const KeyboardDoneBar({required this.child, super.key});

  final Widget child;

  @override
  State<KeyboardDoneBar> createState() => _KeyboardDoneBarState();
}

class _KeyboardDoneBarState extends State<KeyboardDoneBar> {
  bool _needsBar = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    final bool next = focusedFieldHasNoDoneKey();
    if (next == _needsBar || !mounted) return;
    setState(() => _needsBar = next);
  }

  @override
  Widget build(BuildContext context) {
    // Klavye yüksekliği: çubuk klavyenin üstüne oturur ve klavyeyle birlikte
    // yukarı çıkar. Donanım klavyesi kullanılıyorsa bu değer 0'dır ve çubuk
    // hiç görünmez.
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bool visible = _needsBar && keyboard > 0;

    return Stack(
      children: <Widget>[
        widget.child,
        if (visible)
          Positioned(
            left: 0,
            right: 0,
            bottom: keyboard,
            child: Material(
              color: context.surface,
              elevation: 6,
              child: Container(
                height: 44,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: context.hairline)),
                ),
                child: TextButton.icon(
                  onPressed: dismissKeyboard,
                  icon: const Icon(Icons.keyboard_hide_outlined, size: 18),
                  label: Text(context.t('common.done')),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Odaktaki alanı, klavye açılırken görünür alanın içinde tutar.
///
/// Giriş sahnesindeki kartlar tek bir kaydırma görünümünün içinde ortalanıyor.
/// Klavye açıldığında görünür yükseklik yarıya iniyor ve kartın alt tarafındaki
/// telefon alanı klavyenin altında kalıyordu: kullanıcı yazdığını görmüyordu.
///
/// Flutter'ın kendi "imleci göster" davranışı yalnızca odak alındığında ve
/// metin değiştiğinde çalışır; odak klavyeden ÖNCE geldiği için o an görünür
/// alan hâlâ tam yükseklikte olur ve kaydırma gerekmiyormuş gibi görünür.
/// Burada klavye yüksekliğinin her değişimi de bir tetikleyici sayılıyor —
/// düzen yalnızca klavye hareket ettiğinde oynar, başka hiçbir anda değil.
class EnsureVisibleOnFocus extends StatefulWidget {
  const EnsureVisibleOnFocus({
    required this.focusNode,
    required this.child,
    this.alignment = 0.5,
    super.key,
  });

  final FocusNode focusNode;

  /// Görünür alanda hedeflenen konum: 0 üst, 1 alt, 0.5 orta.
  final double alignment;

  final Widget child;

  @override
  State<EnsureVisibleOnFocus> createState() => _EnsureVisibleOnFocusState();
}

class _EnsureVisibleOnFocusState extends State<EnsureVisibleOnFocus> {
  double _keyboardInset = 0;

  /// Odak ve klavye yüksekliği aynı anda değişebiliyor; bekleyen istek
  /// tazelenir, üst üste iki kaydırma başlamaz. Alan ekrandan kalkarsa
  /// zamanlayıcı [dispose] içinde iptal edilir.
  Timer? _revealTimer;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(EnsureVisibleOnFocus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;
    oldWidget.focusNode.removeListener(_onFocusChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (widget.focusNode.hasFocus) _scheduleReveal();
  }

  /// Kaydırma, klavye payı düzene tam olarak işlendikten SONRA yapılır.
  /// Hemen çağrılırsa hedef konum küçülmekte olan bir pencereye göre hesaplanır
  /// ve alan yine klavyenin altında kalır. Bekleme süresi giriş sahnesinin
  /// klavye payı animasyonundan (`AuthFixedBody`) biraz uzun tutuldu.
  void _scheduleReveal() {
    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted || !widget.focusNode.hasFocus) return;
      if (Scrollable.maybeOf(context) == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: widget.alignment,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final double inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset != _keyboardInset) {
      _keyboardInset = inset;
      // Yalnızca klavye hareketinde: kapanışta da çalışır ama odak yoksa
      // `_scheduleReveal` kendi kontrolünde vazgeçer.
      if (inset > 0) _scheduleReveal();
    }
    return widget.child;
  }
}
