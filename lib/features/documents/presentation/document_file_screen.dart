import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/app_exception.dart';
import '../../../shared/widgets/error_view.dart';
import '../../auth/data/current_user_provider.dart';
import '../data/document.dart';
import '../data/document_detail_provider.dart';
import '../data/document_file_provider.dart';

class DocumentFileScreen extends ConsumerWidget {
  const DocumentFileScreen({super.key, required this.documentId});
  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(currentUserIdProvider) == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view this file.')),
      );
    }
    final detail = ref.watch(documentDetailProvider(documentId));
    final document = detail.asData?.value;
    return Scaffold(
      appBar: AppBar(title: Text(document?.title ?? 'View file')),
      body: SafeArea(
        top: false,
        child: detail.when(
          skipLoadingOnReload: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Text('Could not load this document.')),
          data: (document) {
            if (document.status == DocumentStatus.sealed) {
              return const Center(
                child: Text('Original files cannot be viewed while sealed.'),
              );
            }
            final file = ref.watch(documentFileProvider(documentId));
            return file.when(
              skipLoadingOnReload: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(
                exception: error is AppException
                    ? error
                    : const UnknownApiException(),
                expanded: true,
                onRetry: () => ref.invalidate(documentFileProvider(documentId)),
              ),
              data: (bytes) => DocumentFileContent(
                key: ObjectKey(bytes),
                bytes: bytes,
                mime: document.mime,
              ),
            );
          },
        ),
      ),
    );
  }
}

class DocumentFileContent extends StatefulWidget {
  const DocumentFileContent({
    super.key,
    required this.bytes,
    required this.mime,
  });
  final Uint8List bytes;
  final String mime;

  @override
  State<DocumentFileContent> createState() => _DocumentFileContentState();
}

class _DocumentFileContentState extends State<DocumentFileContent> {
  MemoryImage? _image;
  PdfController? _pdf;

  Future<PdfDocument> _openPdf() async {
    final cache = await getApplicationCacheDirectory();
    final folder = await cache.createTemp('document-view-');
    final file = File('${folder.path}/original.pdf');
    try {
      await file.writeAsBytes(widget.bytes, flush: true);
      return await PdfDocument.openFile(file.path);
    } finally {
      // Android/iOS retain the opened descriptor; remove the temporary bytes.
      await folder.delete(recursive: true);
    }
  }

  @override
  void dispose() {
    _image?.evict();
    if (_pdf != null) {
      // The PDF package caches rendered pages globally; discard those on exit.
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
    _pdf?.document
        .then((document) => document.close())
        .catchError((Object _) {});
    _pdf?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mime.startsWith('image/')) {
      _image ??= MemoryImage(widget.bytes);
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 8,
        child: Center(
          child: Image(
            image: _image!,
            errorBuilder: (_, _, _) =>
                const Text('This image could not be displayed.'),
          ),
        ),
      );
    }
    if (widget.mime == 'application/pdf') {
      _pdf ??= PdfController(document: _openPdf());
      return Column(
        children: [
          Expanded(
            child: PdfView(
              controller: _pdf!,
              builders: PdfViewBuilders<DefaultBuilderOptions>(
                options: const DefaultBuilderOptions(),
                documentLoaderBuilder: (_) =>
                    const Center(child: CircularProgressIndicator()),
                pageLoaderBuilder: (_) =>
                    const Center(child: CircularProgressIndicator()),
                errorBuilder: (_, _) => const Center(
                  child: Text('This PDF could not be displayed.'),
                ),
              ),
            ),
          ),
          PdfPageNumber(
            controller: _pdf!,
            builder: (_, loading, page, count) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                loading == PdfLoadingState.success
                    ? 'Page $page of $count'
                    : '',
              ),
            ),
          ),
        ],
      );
    }
    if (widget.mime == 'text/plain' || widget.mime == 'text/markdown') {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(utf8.decode(widget.bytes, allowMalformed: true)),
      );
    }
    return const Center(child: Text('This file type cannot be displayed.'));
  }
}
