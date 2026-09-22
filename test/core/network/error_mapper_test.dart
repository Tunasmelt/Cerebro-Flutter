import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/core/network/error_mapper.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorMapper', () {
    test('a connection timeout maps to NetworkUnreachableException', () {
      final options = RequestOptions(path: '/health');
      final error = DioException(
        requestOptions: options,
        type: DioExceptionType.connectionTimeout,
      );

      expect(ErrorMapper.map(error), isA<NetworkUnreachableException>());
    });

    test('a connection error maps to NetworkUnreachableException', () {
      final options = RequestOptions(path: '/health');
      final error = DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );

      expect(ErrorMapper.map(error), isA<NetworkUnreachableException>());
    });

    test('a 500 response maps to ServerErrorException', () {
      final options = RequestOptions(path: '/documents');
      final error = DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: options, statusCode: 500),
      );

      final mapped = ErrorMapper.map(error);
      expect(mapped, isA<ServerErrorException>());
      expect((mapped as ServerErrorException).statusCode, 500);
    });

    test('a 401 response maps to UnauthorizedException', () {
      final options = RequestOptions(path: '/documents');
      final error = DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: options, statusCode: 401),
      );

      expect(ErrorMapper.map(error), isA<UnauthorizedException>());
    });

    test(
      'the three mapped types are distinct, not one generic exception',
      () {
        final options = RequestOptions(path: '/x');
        final timeout = ErrorMapper.map(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
          ),
        );
        final serverError = ErrorMapper.map(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: options, statusCode: 503),
          ),
        );
        final unauthorized = ErrorMapper.map(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: options, statusCode: 401),
          ),
        );

        expect(timeout.runtimeType, isNot(equals(serverError.runtimeType)));
        expect(
          serverError.runtimeType,
          isNot(equals(unauthorized.runtimeType)),
        );
        expect(timeout.runtimeType, isNot(equals(unauthorized.runtimeType)));
      },
    );
  });
}
