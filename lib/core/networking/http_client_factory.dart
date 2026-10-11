import 'package:dio/dio.dart';

Dio createProbeDio() => Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        followRedirects: false,
        validateStatus: (s) => s != null && s < 600,
        headers: {'User-Agent': 'Vortex/1.0', 'Accept': '*/*'},
      ),
    );

Dio createDownloadDio() => Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: Duration.zero,
        followRedirects: true,
        maxRedirects: 10,
      ),
    );
