import 'dart:convert';
import 'dart:typed_data';

import 'package:body_composition_flutter/models/garmin_account.dart';
import 'package:body_composition_flutter/services/garmin_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  GarminClient client(MockClient mock) => GarminClient(
    httpClient: mock,
    delay: (_) async {},
    minLoginDelay: Duration.zero,
    maxLoginDelay: Duration.zero,
  );

  GarminAccount account({String accessToken = 'access-token'}) => GarminAccount(
    email: 'user@example.com',
    accessToken: accessToken,
    refreshToken: 'refresh-token',
    clientId: 'GARMIN_CONNECT_MOBILE_ANDROID_DI_2025Q2',
    accessTokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
  );

  http.Response json(Object value, [int status = 200]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json'},
  );

  test(
    'signs in with the mobile flow and keeps cookies between calls',
    () async {
      final requests = <http.Request>[];
      final mock = MockClient((request) async {
        requests.add(request);
        switch (request.url.path) {
          case '/mobile/sso/en_US/sign-in':
            return http.Response(
              '',
              200,
              headers: {
                'set-cookie': 'SESSION=session-value; Path=/; Secure; HttpOnly',
              },
            );
          case '/mobile/api/login':
            expect(
              request.headers['cookie'],
              contains('SESSION=session-value'),
            );
            expect(request.url.queryParameters['clientId'], 'GCM_IOS_DARK');
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['username'], 'user@example.com');
            expect(body['password'], 'secret');
            return json({
              'responseStatus': {'type': 'SUCCESSFUL'},
              'serviceTicketId': 'ST-123',
            });
          case '/di-oauth2-service/oauth/token':
            expect(request.headers['authorization'], startsWith('Basic '));
            expect(request.body, contains('service_ticket=ST-123'));
            expect(request.body, contains('grant_type='));
            return json({
              'access_token': 'access-1',
              'refresh_token': 'refresh-1',
              'expires_in': 3600,
            });
        }
        fail('Unexpected request ${request.method} ${request.url}');
      });

      final result = await client(
        mock,
      ).login(email: 'user@example.com', password: 'secret');

      expect(result.requiresMfa, isFalse);
      expect(result.account?.email, 'user@example.com');
      expect(result.account?.accessToken, 'access-1');
      expect(result.account?.refreshToken, 'refresh-1');
      expect(result.account?.clientId, isNotEmpty);
      expect(requests, hasLength(3));
    },
  );

  test('surfaces invalid credentials', () async {
    final mock = MockClient((request) async {
      if (request.url.path == '/mobile/sso/en_US/sign-in') {
        return http.Response('', 200);
      }
      return json({
        'responseStatus': {'type': 'INVALID_USERNAME_PASSWORD'},
      });
    });

    await expectLater(
      client(mock).login(email: 'bad@example.com', password: 'wrong'),
      throwsA(
        isA<GarminException>().having(
          (error) => error.kind,
          'kind',
          GarminFailureKind.invalidCredentials,
        ),
      ),
    );
  });

  test('completes an MFA challenge and exchanges the ticket', () async {
    final mock = MockClient((request) async {
      switch (request.url.path) {
        case '/mobile/sso/en_US/sign-in':
          return http.Response('', 200);
        case '/mobile/api/login':
          return json({
            'responseStatus': {'type': 'MFA_REQUIRED'},
            'customerMfaInfo': {'mfaLastMethodUsed': 'email'},
          });
        case '/mobile/api/mfa/verifyCode':
          expect(request.url.queryParameters['clientId'], 'GCM_IOS_DARK');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['mfaMethod'], 'email');
          expect(body['mfaVerificationCode'], '123456');
          return json({
            'responseStatus': {'type': 'SUCCESSFUL'},
            'serviceTicketId': 'ST-456',
          });
        case '/di-oauth2-service/oauth/token':
          expect(request.body, contains('service_ticket=ST-456'));
          return json({
            'access_token': 'access-2',
            'refresh_token': 'refresh-2',
            'expires_in': 3600,
          });
      }
      fail('Unexpected request ${request.method} ${request.url}');
    });

    final garmin = client(mock);
    final result = await garmin.login(
      email: 'user@example.com',
      password: 'secret',
    );

    expect(result.requiresMfa, isTrue);
    expect(result.challenge?.method, 'email');

    final account = await garmin.completeMfa('123456');
    expect(account.email, 'user@example.com');
    expect(account.accessToken, 'access-2');
  });

  test('refreshes an expired access token', () async {
    final mock = MockClient((request) async {
      expect(request.url.host, 'diauth.garmin.com');
      expect(request.body, contains('grant_type=refresh_token'));
      expect(request.body, contains('refresh_token=refresh-token'));
      return json({
        'access_token': 'access-new',
        'refresh_token': 'refresh-new',
        'expires_in': 7200,
      });
    });

    final refreshed = await client(mock).refresh(account());

    expect(refreshed.accessToken, 'access-new');
    expect(refreshed.refreshToken, 'refresh-new');
    expect(refreshed.clientId, account().clientId);
  });

  test('uploads a FIT file with a bearer token', () async {
    final mock = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/upload-service/upload/.fit');
      expect(request.headers['authorization'], 'Bearer access-token');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data'),
      );
      expect(request.headers['origin'], 'https://sso.garmin.com');
      final multipart = latin1.decode(request.bodyBytes);
      expect(multipart, contains('name="file"'));
      expect(multipart, contains('filename="reading.fit"'));
      return json({
        'detailedImportResult': {
          'uploadId': 99,
          'successes': [
            {'internalId': 1234},
          ],
          'failures': <Object>[],
        },
      }, 201);
    });

    final outcome = await client(mock).uploadWeightFit(
      account: account(),
      fitFile: Uint8List.fromList([1, 2, 3, 4]),
      filename: 'reading.fit',
    );

    expect(outcome.uploadId, 99);
    expect(outcome.duplicate, isFalse);
    expect(outcome.account.accessToken, 'access-token');
  });

  test('treats Garmin duplicate uploads as success', () async {
    final mock = MockClient((request) async {
      return json({
        'detailedImportResult': {
          'successes': <Object>[],
          'failures': [
            {
              'messages': [
                {'code': 202, 'content': 'Activity already uploaded'},
              ],
            },
          ],
        },
      }, 201);
    });

    final outcome = await client(mock).uploadWeightFit(
      account: account(),
      fitFile: Uint8List.fromList([1]),
      filename: 'reading.fit',
    );

    expect(outcome.duplicate, isTrue);
  });

  test('reports a rejected upload with Garmin messages', () async {
    final mock = MockClient((request) async {
      return json({
        'detailedImportResult': {
          'successes': <Object>[],
          'failures': [
            {
              'messages': [
                {'code': 500, 'content': 'Invalid file'},
              ],
            },
          ],
        },
      }, 201);
    });

    await expectLater(
      client(mock).uploadWeightFit(
        account: account(),
        fitFile: Uint8List.fromList([1]),
        filename: 'reading.fit',
      ),
      throwsA(
        isA<GarminException>()
            .having(
              (error) => error.kind,
              'kind',
              GarminFailureKind.uploadRejected,
            )
            .having((error) => error.message, 'message', contains('Invalid')),
      ),
    );
  });

  test('refreshes once and retries when the upload token expired', () async {
    var uploads = 0;
    final mock = MockClient((request) async {
      if (request.url.path == '/di-oauth2-service/oauth/token') {
        return json({
          'access_token': 'access-new',
          'refresh_token': 'refresh-new',
          'expires_in': 3600,
        });
      }
      uploads++;
      if (uploads == 1) {
        return http.Response('', 401);
      }
      expect(request.headers['authorization'], 'Bearer access-new');
      return json({
        'detailedImportResult': {
          'uploadId': 7,
          'successes': [
            {'internalId': 7},
          ],
          'failures': <Object>[],
        },
      }, 201);
    });

    final outcome = await client(mock).uploadWeightFit(
      account: account(),
      fitFile: Uint8List.fromList([1]),
      filename: 'reading.fit',
    );

    expect(uploads, 2);
    expect(outcome.uploadId, 7);
    expect(outcome.account.accessToken, 'access-new');
  });

  test('maps blocked sign-in responses', () async {
    final mock = MockClient((request) async {
      return http.Response('blocked', 403);
    });

    await expectLater(
      client(mock).login(email: 'user@example.com', password: 'secret'),
      throwsA(
        isA<GarminException>().having(
          (error) => error.kind,
          'kind',
          GarminFailureKind.blocked,
        ),
      ),
    );
  });
}
