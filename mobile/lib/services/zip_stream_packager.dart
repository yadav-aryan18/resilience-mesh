import 'dart:io';
import 'dart:typed_data';

/// Zero-memory streaming ZIP packager for large 2GB+ LiteRT model files.
/// Packages raw TFL3 binary files into valid MediaPipe .task Zip bundles
/// with exact entry names (TF_LITE_PREFILL_DECODE, TOKENIZER_MODEL, METADATA, llm_config.json).
class ZipStreamPackager {
  static Future<bool> createMediaPipeTaskBundle({
    required File inputFile,
    required File outputFile,
    File? tokenizerFile,
    required String configJson,
    void Function(String message)? logger,
  }) async {
    try {
      final inputLength = await inputFile.length();
      logger?.call('📦 ZipStreamPackager: Packaging $inputLength bytes into ZIP at ${outputFile.path}...');

      final outputSink = outputFile.openWrite();

      // Entry 1: TF_LITE_PREFILL_DECODE (ALL UPPERCASE as required by MediaPipe C++ litert_executor_utils.cc)
      const modelFilename = 'TF_LITE_PREFILL_DECODE';
      final modelFilenameBytes = Uint8List.fromList(modelFilename.codeUnits);
      const modelOffset = 0;

      // Write Local Header for TF_LITE_PREFILL_DECODE
      final modelHeader = BytesBuilder();
      modelHeader.add([0x50, 0x4B, 0x03, 0x04]); // Signature
      modelHeader.add([0x0A, 0x00]); // Version needed (1.0)
      modelHeader.add([0x00, 0x00]); // General purpose flags
      modelHeader.add([0x00, 0x00]); // Compression method (0 = Store)
      modelHeader.add([0x00, 0x00, 0x00, 0x00]); // Time & Date
      modelHeader.add([0x00, 0x00, 0x00, 0x00]); // Dummy CRC32
      modelHeader.add(_uint32Bytes(inputLength)); // Compressed size
      modelHeader.add(_uint32Bytes(inputLength)); // Uncompressed size
      modelHeader.add(_uint16Bytes(modelFilenameBytes.length)); // Filename len
      modelHeader.add([0x00, 0x00]); // Extra field len
      modelHeader.add(modelFilenameBytes);

      outputSink.add(modelHeader.toBytes());
      final modelDataOffset = 30 + modelFilenameBytes.length;

      // Stream raw 2GB input model file in 64KB chunks to output sink
      final inputStream = inputFile.openRead();
      int bytesCopied = 0;
      await for (final chunk in inputStream) {
        outputSink.add(chunk);
        bytesCopied += chunk.length;
      }
      logger?.call('✅ Streamed $bytesCopied / $inputLength bytes of TF_LITE_PREFILL_DECODE into ZIP.');

      // Entry 2: TOKENIZER_MODEL (if provided)
      int tokenizerLength = 0;
      int tokenizerOffset = modelDataOffset + inputLength;
      Uint8List? tokenizerFilenameBytes;

      if (tokenizerFile != null && await tokenizerFile.exists()) {
        tokenizerLength = await tokenizerFile.length();
        const tokenizerFilename = 'TOKENIZER_MODEL';
        tokenizerFilenameBytes = Uint8List.fromList(tokenizerFilename.codeUnits);

        final tokHeader = BytesBuilder();
        tokHeader.add([0x50, 0x4B, 0x03, 0x04]);
        tokHeader.add([0x0A, 0x00]);
        tokHeader.add([0x00, 0x00]);
        tokHeader.add([0x00, 0x00]);
        tokHeader.add([0x00, 0x00, 0x00, 0x00]);
        tokHeader.add([0x00, 0x00, 0x00, 0x00]);
        tokHeader.add(_uint32Bytes(tokenizerLength));
        tokHeader.add(_uint32Bytes(tokenizerLength));
        tokHeader.add(_uint16Bytes(tokenizerFilenameBytes.length));
        tokHeader.add([0x00, 0x00]);
        tokHeader.add(tokenizerFilenameBytes);

        outputSink.add(tokHeader.toBytes());

        final tokStream = tokenizerFile.openRead();
        int tokCopied = 0;
        await for (final chunk in tokStream) {
          outputSink.add(chunk);
          tokCopied += chunk.length;
        }
        logger?.call('✅ Streamed $tokCopied / $tokenizerLength bytes of TOKENIZER_MODEL into ZIP.');
      } else {
        logger?.call('⚠️ No TOKENIZER_MODEL file available for packaging.');
      }

      final tokenizerDataEndOffset = tokenizerOffset + (tokenizerFilenameBytes != null ? (30 + tokenizerFilenameBytes.length + tokenizerLength) : 0);

      // Entry 3: METADATA
      const metaFilename = 'METADATA';
      final metaFilenameBytes = Uint8List.fromList(metaFilename.codeUnits);
      final configDataBytes = Uint8List.fromList(configJson.codeUnits);
      final metaOffset = tokenizerDataEndOffset;

      final metaHeader = BytesBuilder();
      metaHeader.add([0x50, 0x4B, 0x03, 0x04]);
      metaHeader.add([0x0A, 0x00]);
      metaHeader.add([0x00, 0x00]);
      metaHeader.add([0x00, 0x00]);
      metaHeader.add([0x00, 0x00, 0x00, 0x00]);
      metaHeader.add([0x00, 0x00, 0x00, 0x00]);
      metaHeader.add(_uint32Bytes(configDataBytes.length));
      metaHeader.add(_uint32Bytes(configDataBytes.length));
      metaHeader.add(_uint16Bytes(metaFilenameBytes.length));
      metaHeader.add([0x00, 0x00]);
      metaHeader.add(metaFilenameBytes);

      outputSink.add(metaHeader.toBytes());
      outputSink.add(configDataBytes);

      // Entry 4: llm_config.json
      const configFilename = 'llm_config.json';
      final configFilenameBytes = Uint8List.fromList(configFilename.codeUnits);
      final configOffset = metaOffset + 30 + metaFilenameBytes.length + configDataBytes.length;

      final configHeader = BytesBuilder();
      configHeader.add([0x50, 0x4B, 0x03, 0x04]);
      configHeader.add([0x0A, 0x00]);
      configHeader.add([0x00, 0x00]);
      configHeader.add([0x00, 0x00]);
      configHeader.add([0x00, 0x00, 0x00, 0x00]);
      configHeader.add([0x00, 0x00, 0x00, 0x00]);
      configHeader.add(_uint32Bytes(configDataBytes.length));
      configHeader.add(_uint32Bytes(configDataBytes.length));
      configHeader.add(_uint16Bytes(configFilenameBytes.length));
      configHeader.add([0x00, 0x00]);
      configHeader.add(configFilenameBytes);

      outputSink.add(configHeader.toBytes());
      outputSink.add(configDataBytes);

      final cdOffset = configOffset + 30 + configFilenameBytes.length + configDataBytes.length;

      // Central Directory Header for TF_LITE_PREFILL_DECODE
      final cdModel = BytesBuilder();
      cdModel.add([0x50, 0x4B, 0x01, 0x02]);
      cdModel.add([0x1E, 0x03]);
      cdModel.add([0x0A, 0x00]);
      cdModel.add([0x00, 0x00]);
      cdModel.add([0x00, 0x00]);
      cdModel.add([0x00, 0x00, 0x00, 0x00]);
      cdModel.add([0x00, 0x00, 0x00, 0x00]);
      cdModel.add(_uint32Bytes(inputLength));
      cdModel.add(_uint32Bytes(inputLength));
      cdModel.add(_uint16Bytes(modelFilenameBytes.length));
      cdModel.add([0x00, 0x00]);
      cdModel.add([0x00, 0x00]);
      cdModel.add([0x00, 0x00]);
      cdModel.add([0x00, 0x00]);
      cdModel.add([0x00, 0x00, 0x00, 0x00]);
      cdModel.add(_uint32Bytes(modelOffset));
      cdModel.add(modelFilenameBytes);

      outputSink.add(cdModel.toBytes());
      int cdTotalSize = 46 + modelFilenameBytes.length;
      int entryCount = 1;

      // Central Directory Header for TOKENIZER_MODEL (if present)
      if (tokenizerFilenameBytes != null) {
        final cdTok = BytesBuilder();
        cdTok.add([0x50, 0x4B, 0x01, 0x02]);
        cdTok.add([0x1E, 0x03]);
        cdTok.add([0x0A, 0x00]);
        cdTok.add([0x00, 0x00]);
        cdTok.add([0x00, 0x00]);
        cdTok.add([0x00, 0x00, 0x00, 0x00]);
        cdTok.add([0x00, 0x00, 0x00, 0x00]);
        cdTok.add(_uint32Bytes(tokenizerLength));
        cdTok.add(_uint32Bytes(tokenizerLength));
        cdTok.add(_uint16Bytes(tokenizerFilenameBytes.length));
        cdTok.add([0x00, 0x00]);
        cdTok.add([0x00, 0x00]);
        cdTok.add([0x00, 0x00]);
        cdTok.add([0x00, 0x00]);
        cdTok.add([0x00, 0x00, 0x00, 0x00]);
        cdTok.add(_uint32Bytes(tokenizerOffset));
        cdTok.add(tokenizerFilenameBytes);

        outputSink.add(cdTok.toBytes());
        cdTotalSize += 46 + tokenizerFilenameBytes.length;
        entryCount++;
      }

      // Central Directory Header for METADATA
      final cdMeta = BytesBuilder();
      cdMeta.add([0x50, 0x4B, 0x01, 0x02]);
      cdMeta.add([0x1E, 0x03]);
      cdMeta.add([0x0A, 0x00]);
      cdMeta.add([0x00, 0x00]);
      cdMeta.add([0x00, 0x00]);
      cdMeta.add([0x00, 0x00, 0x00, 0x00]);
      cdMeta.add([0x00, 0x00, 0x00, 0x00]);
      cdMeta.add(_uint32Bytes(configDataBytes.length));
      cdMeta.add(_uint32Bytes(configDataBytes.length));
      cdMeta.add(_uint16Bytes(metaFilenameBytes.length));
      cdMeta.add([0x00, 0x00]);
      cdMeta.add([0x00, 0x00]);
      cdMeta.add([0x00, 0x00]);
      cdMeta.add([0x00, 0x00]);
      cdMeta.add([0x00, 0x00, 0x00, 0x00]);
      cdMeta.add(_uint32Bytes(metaOffset));
      cdMeta.add(metaFilenameBytes);

      outputSink.add(cdMeta.toBytes());
      cdTotalSize += 46 + metaFilenameBytes.length;
      entryCount++;

      // Central Directory Header for llm_config.json
      final cdConfig = BytesBuilder();
      cdConfig.add([0x50, 0x4B, 0x01, 0x02]);
      cdConfig.add([0x1E, 0x03]);
      cdConfig.add([0x0A, 0x00]);
      cdConfig.add([0x00, 0x00]);
      cdConfig.add([0x00, 0x00]);
      cdConfig.add([0x00, 0x00, 0x00, 0x00]);
      cdConfig.add([0x00, 0x00, 0x00, 0x00]);
      cdConfig.add(_uint32Bytes(configDataBytes.length));
      cdConfig.add(_uint32Bytes(configDataBytes.length));
      cdConfig.add(_uint16Bytes(configFilenameBytes.length));
      cdConfig.add([0x00, 0x00]);
      cdConfig.add([0x00, 0x00]);
      cdConfig.add([0x00, 0x00]);
      cdConfig.add([0x00, 0x00]);
      cdConfig.add([0x00, 0x00, 0x00, 0x00]);
      cdConfig.add(_uint32Bytes(configOffset));
      cdConfig.add(configFilenameBytes);

      outputSink.add(cdConfig.toBytes());
      cdTotalSize += 46 + configFilenameBytes.length;
      entryCount++;

      // End of Central Directory Record (EOCD)
      final eocd = BytesBuilder();
      eocd.add([0x50, 0x4B, 0x05, 0x06]);
      eocd.add([0x00, 0x00]);
      eocd.add([0x00, 0x00]);
      eocd.add(_uint16Bytes(entryCount)); // CD entries on disk
      eocd.add(_uint16Bytes(entryCount)); // Total CD entries
      eocd.add(_uint32Bytes(cdTotalSize));
      eocd.add(_uint32Bytes(cdOffset));
      eocd.add([0x00, 0x00]);

      outputSink.add(eocd.toBytes());
      await outputSink.flush();
      await outputSink.close();

      final outputLength = await outputFile.length();
      logger?.call('🎉 MediaPipe ZIP Task Bundle created successfully! Output size: $outputLength bytes.');
      return true;
    } catch (e) {
      logger?.call('❌ ZipStreamPackager error: $e');
      return false;
    }
  }

  static Uint8List _uint32Bytes(int value) {
    final bd = ByteData(4)..setUint32(0, value, Endian.little);
    return bd.buffer.asUint8List();
  }

  static Uint8List _uint16Bytes(int value) {
    final bd = ByteData(2)..setUint16(0, value, Endian.little);
    return bd.buffer.asUint8List();
  }
}
