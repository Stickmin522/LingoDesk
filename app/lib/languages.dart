import 'dart:convert';

import 'package:intl/intl.dart' show Bidi;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DeskLanguage {
  const DeskLanguage(this.code, this.name, this.english);
  final String code, name, english;
}

class AppStrings {
  static List<DeskLanguage> languages = const [
    DeskLanguage('ja', '日本語', 'Japanese'),
    DeskLanguage('zh', '中文', 'Chinese'),
    DeskLanguage('en', 'English', 'English'),
  ];
  static Map<String, String> _english = {}, _current = {};
  static String language = 'en';
  static Future<void>? _initializing;
  static bool _initialized = false;
  static final _catalogs = <String, Map<String, String>>{};
  static int _loadGeneration = 0;
  static Future<void> initialize() =>
      _initialized ? Future.value() : (_initializing ??= _initialize());
  static Future<void> _initialize() async {
    final data = jsonDecode(
      await rootBundle.loadString('assets/languages.json'),
    ) as List;
    languages = data
        .map(
          (v) => DeskLanguage(
            v['code'] as String,
            v['name'] as String,
            v['english'] as String,
          ),
        )
        .toList();
    _english = Map<String, String>.from(
      jsonDecode(
        await rootBundle.loadString('assets/i18n/en.json', cache: false),
      ) as Map,
    );
    _catalogs['en'] = _english;
    _initialized = true;
  }

  static Future<void> load(String code) async {
    final generation = ++_loadGeneration;
    await initialize();
    if (!languages.any((v) => v.code == code)) code = 'en';
    final data =
        _catalogs[code] ??
        Map<String, String>.from(
          jsonDecode(
            await rootBundle.loadString('assets/i18n/$code.json', cache: false),
          ) as Map,
        );
    _catalogs[code] = data;
    if (generation != _loadGeneration) return;
    language = code;
    _current = data;
  }

  static String text(String key) => _current[key] ?? _english[key] ?? key;
  static Locale get locale => Locale(switch (language) {
    'no' => 'nb',
    'tl' => 'tl',
    _ => language,
  });
  static bool get rtl => const ['ar', 'he', 'fa', 'ur'].contains(language);
  static String name(String code) =>
      languages.where((v) => v.code == code).firstOrNull?.name ?? code;
  static List<String> pair(dynamic value) {
    final parts = '$value'.split('-');
    return parts.length == 2 &&
            parts[0] != parts[1] &&
            parts.every((p) => languages.any((l) => l.code == p))
        ? parts
        : ['ja', 'zh'];
  }
}

String tr(String key) => AppStrings.text(key);

class LanguageField extends StatelessWidget {
  const LanguageField({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.exclude,
    this.followSystem = false,
  });
  final String value, label;
  final String? exclude;
  final bool followSystem;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    onPressed: onChanged == null
        ? null
        : () async {
            final selected = await showDialog<String>(
              context: context,
              builder: (_) => _LanguagePicker(
                value: value,
                exclude: exclude,
                followSystem: followSystem,
              ),
            );
            if (selected != null && selected != exclude) {
              onChanged?.call(selected);
            }
          },
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 4),
              Text(
                value == 'system' ? tr('跟随系统') : AppStrings.name(value),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const Icon(Icons.expand_more_rounded, size: 18),
      ],
    ),
  );
}

class _LanguagePicker extends StatefulWidget {
  const _LanguagePicker({
    required this.value,
    this.exclude,
    required this.followSystem,
  });
  final String value;
  final String? exclude;
  final bool followSystem;
  @override
  State<_LanguagePicker> createState() => _LanguagePickerState();
}

class _LanguagePickerState extends State<_LanguagePicker> {
  String search = '';
  @override
  Widget build(BuildContext context) {
    final choices = AppStrings.languages
        .where(
          (l) => '${l.name} ${l.english} ${l.code}'.toLowerCase().contains(
            search.toLowerCase(),
          ),
        )
        .toList();
    return AlertDialog(
      title: Text(tr('选择语言')),
      content: SizedBox(
        width: 440,
        height: MediaQuery.sizeOf(context).height * .58,
        child: Column(
          children: [
            TextField(
              autocorrect: false,
              onChanged: (v) => setState(() => search = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: tr('搜索语言'),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  if (widget.followSystem && search.isEmpty)
                    ListTile(
                      title: Text(tr('跟随系统')),
                      selected: widget.value == 'system',
                      onTap: () => Navigator.pop(context, 'system'),
                    ),
                  for (final l in choices)
                    ListTile(
                      key: ValueKey('language-${l.code}'),
                      title: Text(l.name),
                      subtitle: Text(l.english),
                      selected: l.code == widget.value,
                      enabled: l.code != widget.exclude,
                      trailing: l.code == widget.value
                          ? const Icon(Icons.check)
                          : null,
                      onTap: l.code == widget.exclude
                          ? null
                          : () => Navigator.pop(context, l.code),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('取消')),
        ),
      ],
    );
  }
}

TextDirection contentDirection(String text) =>
    Bidi.detectRtlDirectionality(text) ? TextDirection.rtl : TextDirection.ltr;
