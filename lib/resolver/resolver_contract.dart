import 'package:dio/dio.dart';

import 'resolve_result.dart';

abstract class SourceResolver {
  String get name;
  Future<ResolveResult> resolve(Uri uri, ProbeContext ctx);
}

class ProbeContext {
  ProbeContext(this.dio);
  final Dio dio;
}
