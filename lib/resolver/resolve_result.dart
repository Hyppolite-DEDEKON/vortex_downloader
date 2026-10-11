import '../core/utils/format_utils.dart';
import 'analyzed_resource.dart';
import 'media_variant.dart';

sealed class ResolveResult {
  const ResolveResult();
}

final class ResolveSuccess extends ResolveResult {
  const ResolveSuccess(this.resource, {this.variants = const []});

  final AnalyzedResource resource;

  /// Formats disponibles (vide = uniquement [resource]).
  final List<MediaVariant> variants;

  List<MediaVariant> get choices {
    if (variants.isNotEmpty) return variants;
    return [MediaVariant.fromResource(resource, label: _defaultLabel(resource))];
  }
}

String _defaultLabel(AnalyzedResource r) {
  final parts = <String>[r.resolverName];
  if (r.totalBytes != null) {
    parts.add(FormatUtils.formatBytes(r.totalBytes));
  } else if (r.mimeType != null) {
    parts.add(r.mimeType!);
  }
  return parts.join(' · ');
}

final class ResolveFailure extends ResolveResult {
  const ResolveFailure(this.message);
  final String message;
}

final class ResolveUnsupported extends ResolveResult {
  const ResolveUnsupported(this.message);
  final String message;
}
