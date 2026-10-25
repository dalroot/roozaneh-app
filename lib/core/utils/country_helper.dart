import 'dart:convert';
import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:roozaneh/core/model/constants.dart';
import 'package:roozaneh/features/profile/data/profile_data_providers.dart';
import 'package:roozaneh/features/profile/notifier/active_profile_notifier.dart';
import 'package:roozaneh/hiddifycore/generated/v2/hcore/hcore.pb.dart';

const Map<String, (String fa, String en)> kCountryNames = {
  'DE': ('آلمان', 'Germany'),
  'NL': ('هلند', 'Netherlands'),
  'FR': ('فرانسه', 'France'),
  'US': ('آمریکا', 'United States'),
  'TR': ('ترکیه', 'Turkey'),
  'GB': ('انگلستان', 'United Kingdom'),
  'UK': ('انگلستان', 'United Kingdom'),
  'AE': ('امارات', 'United Arab Emirates'),
  'FI': ('فنلاند', 'Finland'),
  'SE': ('سوئد', 'Sweden'),
  'SG': ('سنگاپور', 'Singapore'),
  'CA': ('کانادا', 'Canada'),
  'JP': ('ژاپن', 'Japan'),
  'CH': ('سوئیس', 'Switzerland'),
  'IT': ('ایتالیا', 'Italy'),
  'ES': ('اسپانیا', 'Spain'),
  'RU': ('روسیه', 'Russia'),
  'PL': ('لهستان', 'Poland'),
  'AT': ('اتریش', 'Austria'),
  'RO': ('رومانی', 'Romania'),
  'UA': ('اوکراین', 'Ukraine'),
  'IR': ('ایران', 'Iran'),
};

String detectCountryCode(String tag, String? ipCountryCode) {
  if (ipCountryCode != null && ipCountryCode.trim().isNotEmpty && ipCountryCode.trim().length == 2) {
    return ipCountryCode.trim().toUpperCase();
  }

  // Emoji flags
  if (tag.contains('🇩🇪')) return 'DE';
  if (tag.contains('🇳🇱')) return 'NL';
  if (tag.contains('🇫🇷')) return 'FR';
  if (tag.contains('🇺🇸')) return 'US';
  if (tag.contains('🇹🇷')) return 'TR';
  if (tag.contains('🇬🇧')) return 'GB';
  if (tag.contains('🇦🇪')) return 'AE';
  if (tag.contains('🇫🇮')) return 'FI';
  if (tag.contains('🇸🇪')) return 'SE';
  if (tag.contains('🇸🇬')) return 'SG';
  if (tag.contains('🇨🇦')) return 'CA';
  if (tag.contains('🇯🇵')) return 'JP';
  if (tag.contains('🇨🇭')) return 'CH';
  if (tag.contains('🇮🇹')) return 'IT';
  if (tag.contains('🇪🇸')) return 'ES';
  if (tag.contains('🇷🇺')) return 'RU';
  if (tag.contains('🇮🇷')) return 'IR';

  final lower = tag.toLowerCase();
  if (lower.contains('germany') || lower.contains('آلمان') || lower.contains('frankfurt') || lower.contains('[de]') || lower.contains('de -') || lower.contains('de-')) return 'DE';
  if (lower.contains('netherlands') || lower.contains('هلند') || lower.contains('amsterdam') || lower.contains('[nl]') || lower.contains('nl -') || lower.contains('nl-')) return 'NL';
  if (lower.contains('france') || lower.contains('فرانسه') || lower.contains('paris') || lower.contains('[fr]') || lower.contains('fr -') || lower.contains('fr-')) return 'FR';
  if (lower.contains('united states') || lower.contains('america') || lower.contains('usa') || lower.contains('آمریکا') || lower.contains('[us]') || lower.contains('us -') || lower.contains('us-')) return 'US';
  if (lower.contains('turkey') || lower.contains('ترکیه') || lower.contains('istanbul') || lower.contains('[tr]') || lower.contains('tr -') || lower.contains('tr-')) return 'TR';
  if (lower.contains('united kingdom') || lower.contains('uk') || lower.contains('انگلیس') || lower.contains('london') || lower.contains('[gb]') || lower.contains('[uk]') || lower.contains('gb -') || lower.contains('gb-')) return 'GB';
  if (lower.contains('uae') || lower.contains('امارات') || lower.contains('dubai') || lower.contains('[ae]')) return 'AE';
  if (lower.contains('finland') || lower.contains('فنلاند') || lower.contains('helsinki') || lower.contains('[fi]')) return 'FI';
  if (lower.contains('sweden') || lower.contains('سوئد') || lower.contains('stockholm') || lower.contains('[se]')) return 'SE';
  if (lower.contains('singapore') || lower.contains('سنگاپور') || lower.contains('[sg]')) return 'SG';
  if (lower.contains('canada') || lower.contains('کانادا') || lower.contains('[ca]')) return 'CA';
  if (lower.contains('japan') || lower.contains('ژاپن') || lower.contains('tokyo') || lower.contains('[jp]')) return 'JP';

  return '';
}

class CountryGroup {
  final String code;
  final String nameFa;
  final String nameEn;
  final List<OutboundInfo> proxies;
  final OutboundInfo primaryProxy;
  final int bestDelay;
  final bool isSelected;

  CountryGroup({
    required this.code,
    required this.nameFa,
    required this.nameEn,
    required this.proxies,
    required this.primaryProxy,
    required this.bestDelay,
    required this.isSelected,
  });
}

List<CountryGroup> groupProxiesByCountry(List<OutboundInfo> items, String? selectedTag) {
  final Map<String, List<OutboundInfo>> map = {};

  for (final proxy in items) {
    if (proxy.tagDisplay.contains("ERROR") || proxy.tagDisplay.contains("Unknown parse")) continue;

    final lower = proxy.tagDisplay.toLowerCase();
    // Skip balancers / auto selectors from country buckets
    if (lower.contains("balance") || lower.contains("lowest") || proxy.type == "urltest" || proxy.type == "selector") {
      continue;
    }

    final code = detectCountryCode(proxy.tagDisplay, proxy.ipinfo.countryCode);
    final key = code.isNotEmpty ? code : 'OTHER';

    map.putIfAbsent(key, () => []).add(proxy);
  }

  final List<CountryGroup> result = [];

  for (final entry in map.entries) {
    final code = entry.key;
    final proxies = entry.value;
    if (proxies.isEmpty) continue;

    int bestDelay = 0;
    for (final p in proxies) {
      if (ConnectionConst.isValidDelay(p.urlTestDelay)) {
        if (bestDelay == 0 || p.urlTestDelay < bestDelay) {
          bestDelay = p.urlTestDelay;
        }
      }
    }

    final isSelected = proxies.any((p) => p.tag == selectedTag);
    final primary = proxies.firstWhere(
      (p) => p.tag == selectedTag,
      orElse: () => proxies.firstWhere(
        (p) => ConnectionConst.isValidDelay(p.urlTestDelay),
        orElse: () => proxies.firstWhere(
          (p) => !p.tag.contains("تانل") && !p.tag.contains("VIP"),
          orElse: () => proxies.first,
        ),
      ),
    );

    final info = kCountryNames[code] ?? (code == 'OTHER' ? ('سرورهای اختصاصی', 'Custom Servers') : (code, code));

    result.add(CountryGroup(
      code: code == 'OTHER' ? '' : code,
      nameFa: info.$1,
      nameEn: info.$2,
      proxies: proxies,
      primaryProxy: primary,
      bestDelay: bestDelay,
      isSelected: isSelected,
    ));
  }

  return result;
}

List<OutboundInfo> parseOutboundsFromConfigContent(String content) {
  final clean = content.trim();
  if (clean.isEmpty) return [];

  final List<OutboundInfo> result = [];

  // 1. Try JSON (Sing-box / Clash meta JSON)
  try {
    final decoded = jsonDecode(clean);
    if (decoded is Map && decoded['outbounds'] is List) {
      for (final item in decoded['outbounds']) {
        if (item is Map && item['tag'] is String) {
          final tag = item['tag'] as String;
          final type = (item['type'] as String?) ?? 'proxy';
          final code = detectCountryCode(tag, '');
          result.add(OutboundInfo(
            tag: tag,
            tagDisplay: tag,
            type: type,
            urlTestDelay: 0,
            ipinfo: IpInfo(countryCode: code),
          ));
        }
      }
      if (result.isNotEmpty) return result;
    }
  } catch (_) {}

  // 2. Try Base64 decode if not JSON
  String rawText = clean;
  try {
    if (!clean.startsWith('{') && !clean.contains('://')) {
      final normalized = base64.normalize(clean.replaceAll('\n', '').replaceAll('\r', '').trim());
      rawText = utf8.decode(base64.decode(normalized));
    }
  } catch (_) {}

  // 3. Parse URI lines
  final lines = rawText.split(RegExp(r'[\r\n]+'));
  for (final line in lines) {
    final l = line.trim();
    if (l.isEmpty || l.startsWith('#') || l.startsWith('//')) continue;

    if (l.contains('://')) {
      final parts = l.split('://');
      final scheme = parts[0].toLowerCase();
      final rest = parts.sublist(1).join('://');

      String name = '';
      if (rest.contains('#')) {
        final hashPart = rest.split('#').last;
        try {
          name = Uri.decodeComponent(hashPart).trim();
        } catch (_) {
          name = hashPart.trim();
        }
      }
      if (name.isEmpty) {
        name = '$scheme server';
      }

      final code = detectCountryCode(name, '');
      result.add(OutboundInfo(
        tag: name,
        tagDisplay: name,
        type: scheme,
        urlTestDelay: 0,
        ipinfo: IpInfo(countryCode: code),
      ));
    }
  }

  return result;
}

final offlineOutboundsProvider = FutureProvider.autoDispose<OutboundGroup?>((ref) async {
  final activeProfile = await ref.watch(activeProfileProvider.future);
  if (activeProfile == null) return null;

  try {
    final pathResolver = ref.watch(profilePathResolverProvider);
    final file = pathResolver.file(activeProfile.id);
    if (!await file.exists()) return null;

    final content = await file.readAsString();
    final items = parseOutboundsFromConfigContent(content);
    if (items.isEmpty) return null;

    return OutboundGroup(
      tag: "select",
      type: "selector",
      selected: items.first.tag,
      items: items,
    );
  } catch (e) {
    return null;
  }
});
