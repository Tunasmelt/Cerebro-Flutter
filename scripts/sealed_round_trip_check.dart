// Milestone 5.2 device verification, intentionally outside production routes.
// Run: flutter run -d <device> -t scripts/sealed_round_trip_check.dart
// Use only disposable test documents. Restore lib/main.dart afterward.
import 'dart:convert';

import 'package:chopper/chopper.dart' show Response;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cerebro_mobile/core/config/supabase_config.dart';
import 'package:cerebro_mobile/core/crypto/sealed_crypto.dart';
import 'package:cerebro_mobile/core/network/generated/cerebro_api.swagger.dart';
import 'package:cerebro_mobile/core/network/generated_api_client.dart';
import 'package:cerebro_mobile/features/auth/data/supabase_session_token_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  runApp(const MaterialApp(home: _VerificationScreen()));
}

class _VerificationScreen extends StatefulWidget {
  const _VerificationScreen();
  @override
  State<_VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<_VerificationScreen> {
  final _id = TextEditingController();
  final _password = TextEditingController();
  late final _api = buildGeneratedApiClient(
    tokenProvider: const SupabaseSessionTokenProvider(),
  );
  List<Map<String, dynamic>>? _baseline;
  String? _baselineId;
  String _status =
      'Use a disposable ready document. Read baseline before sealing.';
  bool _busy = false;

  Map<String, dynamic> _body(Response response) {
    if (!response.isSuccessful) throw StateError('Request failed');
    return response.body as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> _chunks(Map<String, dynamic> body) {
    final chunks = (body['chunks'] as List).map((item) {
      final row = item as Map<String, dynamic>;
      return <String, dynamic>{
        'ordinal': row['ordinal'],
        'content': row['content'],
      };
    }).toList();
    chunks.sort((a, b) => (a['ordinal'] as int).compareTo(b['ordinal'] as int));
    return chunks;
  }

  Future<void> _run(String action) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _status = 'Working...';
    });
    try {
      final id = _id.text.trim();
      if (id.isEmpty) throw StateError('Missing document');
      final auth = Supabase.instance.client.auth;
      if (auth.currentSession == null) {
        throw StateError('Sign in through the normal app first');
      }
      if (auth.currentSession!.isExpired) await auth.refreshSession();
      if (action == 'baseline') {
        final response = await _api.apiV1GraphNodesDocumentIdChunksGet(
          documentId: id,
        );
        final candidate = _chunks(_body(response));
        if (candidate.isEmpty) throw StateError('No chunks');
        _baseline = candidate;
        _baselineId = id;
        _status =
            'Baseline captured: ${_baseline!.length} chunks. Seal on web or here.';
      } else {
        if (action != 'reject' && (_baseline == null || _baselineId != id)) {
          throw StateError('Read baseline for this document first');
        }
        if (action == 'seal') {
          final salt = generateSealedSalt();
          final key = await deriveSealedKey(_password.text, salt);
          final chunks = <SealChunkBody>[];
          for (final row in _baseline!) {
            final chunk = await encryptSealedChunk(
              utf8.encode(row['content'] as String),
              key,
            );
            chunks.add(
              SealChunkBody(
                ordinal: row['ordinal'] as int,
                contentCiphertext: base64Encode(chunk.ciphertext),
                salt: base64Encode(salt),
                nonce: base64Encode(chunk.nonce),
              ),
            );
          }
          _body(
            await _api.apiV1DocumentsDocumentIdSealPost(
              documentId: id,
              body: SealBody(chunks: chunks),
            ),
          );
          _password.clear();
          _status =
              'Sealed on mobile: ${chunks.length} chunks. Unlock on web next.';
          debugPrint('MILESTONE_5_2_MOBILE_SEAL_PASS');
        } else {
          final salt =
              _body(
                    await _api.apiV1DocumentsDocumentIdSealSaltGet(
                      documentId: id,
                    ),
                  )['salt']
                  as String;
          final key = await deriveSealedKey(_password.text, base64Decode(salt));
          final keyB64 = base64Encode(await key.extractBytes());
          final unlock = await _api.apiV1DocumentsDocumentIdUnlockPost(
            documentId: id,
            body: UnlockBody(key: keyB64),
          );
          if (action == 'reject') {
            final errorBody =
                jsonDecode(unlock.bodyString) as Map<String, dynamic>;
            debugPrint('MILESTONE_5_2_REJECTION_HTTP_${unlock.statusCode}');
            if (unlock.statusCode != 401 ||
                errorBody['error']?['code'] != 'invalid_key') {
              throw StateError(
                'Expected wrong-key rejection, not another failure',
              );
            }
            _password.clear();
            _status = "Couldn't unlock this document. Try again.";
            debugPrint('MILESTONE_5_2_WRONG_PASSPHRASE_REJECTION_PASS');
            return;
          }
          final claim = _body(unlock);
          final clear = _chunks(
            _body(
              await _api.apiV1DocumentsDocumentIdUnsealPost(
                documentId: id,
                body: UnsealBody(
                  claimId: claim['claim_id'] as String,
                  key: keyB64,
                ),
              ),
            ),
          );
          if (jsonEncode(clear) != jsonEncode(_baseline)) {
            throw StateError('Content mismatch');
          }
          _password.clear();
          _status =
              'PASS: ${clear.length} chunks match baseline byte for byte.';
          debugPrint('MILESTONE_5_2_MOBILE_UNLOCK_PARITY_PASS');
        }
      }
    } catch (_) {
      _password.clear();
      _status = action == 'reject'
          ? "Couldn't unlock this document. Try again."
          : "Couldn't complete verification. Check inputs and try again.";
      debugPrint('MILESTONE_5_2_VERIFICATION_INCOMPLETE');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    _api.client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sealed interoperability check')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _id,
          enabled: !_busy,
          decoration: const InputDecoration(labelText: 'Test document ID'),
        ),
        TextField(
          controller: _password,
          enabled: !_busy,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(labelText: 'Passphrase'),
        ),
        const SizedBox(height: 16),
        for (final action in ['baseline', 'seal', 'unlock', 'reject'])
          ElevatedButton(
            onPressed: _busy ? null : () => _run(action),
            child: Text(
              {
                'baseline': 'Read baseline',
                'seal': 'Seal on mobile',
                'unlock': 'Unlock and compare',
                'reject': 'Verify wrong passphrase rejection',
              }[action]!,
            ),
          ),
        const SizedBox(height: 16),
        Text(_status),
      ],
    ),
  );
}
