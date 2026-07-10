import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:agrobravo/core/constants/translations.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/tokens/app_spacing.dart';
import 'package:agrobravo/core/tokens/app_text_styles.dart';
import 'package:agrobravo/core/components/app_header.dart';
import 'package:agrobravo/core/components/image_source_bottom_sheet.dart';
import 'package:agrobravo/core/components/country_picker_bottom_sheet.dart';
import 'package:agrobravo/core/data/countries.dart';
import 'package:agrobravo/core/di/injection.dart';
import 'package:agrobravo/core/components/document_preview_page.dart';
import 'package:agrobravo/features/documents/presentation/cubit/documents_cubit.dart';
import 'package:agrobravo/features/documents/domain/entities/document_entity.dart';
import 'package:agrobravo/features/documents/domain/entities/document_enums.dart';

class DocumentDetailsPage extends StatefulWidget {
  final DocumentType type;
  final DocumentEntity? currentDocument;
  final DocumentsCubit? cubit;

  const DocumentDetailsPage({
    super.key,
    required this.type,
    this.currentDocument,
    this.cubit,
  });

  @override
  State<DocumentDetailsPage> createState() => _DocumentDetailsPageState();
}

class _DocumentDetailsPageState extends State<DocumentDetailsPage> {
  final _numberController = TextEditingController();
  final _nameController = TextEditingController();
  DateTime? _selectedDate;
  File? _selectedFile;
  bool _isUploading = false;
  bool _isProcessingOcr = false;
  String? _ocrError;
  bool _fieldsModified = false;
  CountryItem? _selectedCountry; // apenas para tipo visto

  @override
  void initState() {
    super.initState();
    if (widget.currentDocument != null) {
      _numberController.text = widget.currentDocument!.documentNumber ?? '';
      _nameController.text = widget.currentDocument!.title ?? '';
      _selectedDate = widget.currentDocument!.expiryDate;
      // Carrega país salvo (só para visto)
      if (widget.type == DocumentType.visto) {
        _selectedCountry = countryByCode(widget.currentDocument!.visaCountry);
      }
    }
    _numberController.addListener(_onFieldChanged);
    _nameController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_fieldsModified) {
      setState(() {
        _fieldsModified = true;
      });
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Rótulo bilíngue do tipo de documento.
  String _typeLabel() {
    switch (widget.type) {
      case DocumentType.passaporte:
        return context.t('Passaporte', 'Passport');
      case DocumentType.visto:
        return context.t('Visto', 'Visa');
      case DocumentType.vacina:
        return context.t('Carteira de Vacinação', 'Vaccination Card');
      case DocumentType.seguro:
        return context.t('Seguro Viagem', 'Travel Insurance');
      case DocumentType.carteiraMotorista:
        return context.t('Carteira de Motorista', "Driver's License");
      case DocumentType.autorizacaoMenores:
        return context.t('Autorização de Menores', 'Minor Authorization');
      case DocumentType.outro:
        return context.t('Outro', 'Other');
    }
  }

  void _openImagePreview() {
    final selectedPath = _selectedFile?.path.toLowerCase();
    final hasLocalImage =
        _selectedFile != null && selectedPath?.endsWith('.pdf') == false;
    final hasLocalPdf =
        _selectedFile != null && selectedPath?.endsWith('.pdf') == true;
    final remoteUrl = widget.currentDocument?.imageUrl;
    final hasRemotePdf = remoteUrl != null &&
        (remoteUrl.toLowerCase().contains('.pdf') ||
            remoteUrl.toLowerCase().contains('/pdf'));
    final hasRemoteImage = widget.currentDocument?.imageUrl != null &&
        !widget.currentDocument!.imageUrl!.toLowerCase().contains('.pdf') &&
        !widget.currentDocument!.imageUrl!.toLowerCase().contains('/pdf');

    if (hasLocalPdf) {
      // Abrir PDF local in-app
      DocumentPreviewPage.show(
        context,
        filePath: _selectedFile!.path,
        title: _typeLabel(),
      );
      return;
    }

    if (hasRemotePdf) {
      // Abrir PDF remoto in-app
      DocumentPreviewPage.show(
        context,
        url: remoteUrl,
        title: _typeLabel(),
      );
      return;
    }

    if (!hasLocalImage && !hasRemoteImage) return;

    if (hasLocalImage) {
      // Abrir imagem local in-app
      DocumentPreviewPage.show(
        context,
        filePath: _selectedFile!.path,
        title: _typeLabel(),
      );
    } else {
      // Abrir imagem remota in-app
      DocumentPreviewPage.show(
        context,
        url: widget.currentDocument!.imageUrl!,
        title: _typeLabel(),
      );
    }
  }

  void _showDatePickerBottomSheet() {
    DateTime tempDate =
        _selectedDate ?? DateTime.now().add(const Duration(days: 365));
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).dividerColor.withOpacity(0.03),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          context.t('Cancelar', 'Cancel'),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        context.t('Data de Validade', 'Expiry Date'),
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedDate = tempDate;
                            _fieldsModified = true;
                          });
                          Navigator.pop(context);
                        },
                        child: Text(
                          context.t('Confirmar', 'Confirm'),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 220,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: tempDate,
                    minimumDate:
                        DateTime.now().subtract(const Duration(days: 3650)),
                    maximumDate: DateTime.now().add(const Duration(days: 3650)),
                    onDateTimeChanged: (DateTime newDate) {
                      tempDate = newDate;
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  DateTime? _parseDateFromOcr(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _processDocumentOcr(File file) async {
    final isPdf = file.path.toLowerCase().endsWith('.pdf');
    final isImage =
        ['.jpg', '.jpeg', '.png', '.webp'].any(file.path.toLowerCase().endsWith);
    final supportsOcr = widget.type == DocumentType.passaporte ||
        widget.type == DocumentType.visto;

    if ((!isImage && !isPdf) || !supportsOcr) {
      setState(() {
        _ocrError = null;
      });
      return;
    }

    setState(() {
      _isProcessingOcr = true;
      _ocrError = null;
    });

    File fileToProcess = file;

    if (isPdf) {
      try {
        final document = await PdfDocument.openFile(file.path);
        if (document.pagesCount > 0) {
          final page = await document.getPage(1);
          final pageImage = await page.render(
            width: page.width * 2,
            height: page.height * 2,
            format: PdfPageImageFormat.jpeg,
          );

          if (pageImage != null) {
            final tempDir = await getTemporaryDirectory();
            final tempFile = File(
                '${tempDir.path}/ocr_temp_${DateTime.now().millisecondsSinceEpoch}.jpg');
            await tempFile.writeAsBytes(pageImage.bytes);
            fileToProcess = tempFile;
          }

          await page.close();
        }
        await document.close();
      } catch (e) {
        if (mounted) {
          if (kDebugMode) debugPrint('[Documents] Erro ao converter PDF: $e');
          setState(() {
            _ocrError = context.t(
              'Não foi possível processar o PDF. Tente com uma imagem.',
              'Could not process the PDF. Try with an image.',
            );
            _isProcessingOcr = false;
          });
        }
        return;
      }
    }

    final cubit = widget.cubit ?? getIt<DocumentsCubit>();
    final result =
        await cubit.parseDocument(type: widget.type, file: fileToProcess);

    if (!mounted) return;

    result.fold(
      (error) {
        if (kDebugMode) debugPrint('[Documents] OCR error: $error');
        setState(() {
          _ocrError = context.t(
            'Não foi possível extrair os dados automaticamente. Preencha manualmente.',
            'Could not automatically extract the data. Please fill in manually.',
          );
          _isProcessingOcr = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t(
              'Não foi possível extrair os dados. Preencha manualmente.',
              'Could not extract the data. Please fill in manually.',
            )),
          ),
        );
      },
      (data) {
        setState(() {
          _isProcessingOcr = false;
        });

        final expectedKind =
            widget.type == DocumentType.passaporte ? 'passport' : 'visa';
        final detectedKind = data['document_kind'];

        if (detectedKind != null && detectedKind != expectedKind) {
          final detectedLabel = detectedKind == 'passport'
              ? context.t('Passaporte', 'Passport')
              : context.t('Visto', 'Visa');
          final selectedLabel = _typeLabel();
          setState(() {
            _ocrError = context.t(
                  'O documento anexado é um ',
                  'The attached document is a ',
                ) +
                detectedLabel +
                context.t(
                  ', mas você selecionou "',
                  ', but you selected "',
                ) +
                selectedLabel +
                context.t(
                  '". Envie o documento correto.',
                  '". Please submit the correct document.',
                );
            _selectedFile = null; // Reseta o arquivo inválido
          });
          return;
        }

        // Se o tipo coincidir, preenche os dados
        if (widget.type == DocumentType.passaporte) {
          final passportNumber = data['passport_number'];
          if (passportNumber != null) {
            _numberController.text = passportNumber.toString();
          }
        } else if (widget.type == DocumentType.visto) {
          final visaNumber = data['visa_number'];
          if (visaNumber != null) {
            _numberController.text = visaNumber.toString();
          }
          // Tenta extrair o país do visto via visa_origin ou country
          final visaOrigin = data['visa_origin']?.toString();
          final country = data['country']?.toString();
          final detectedCountry =
              countryByAny(visaOrigin) ?? countryByAny(country);
          if (detectedCountry != null) {
            setState(() {
              _selectedCountry = detectedCountry;
              _fieldsModified = true;
            });
          }
        }

        final givenName = data['given_name'];
        final surname = data['surname'];
        String? fullName;
        if (givenName != null || surname != null) {
          final parts = <String>[];
          if (givenName != null && givenName.toString().trim().isNotEmpty) {
            parts.add(givenName.toString().trim());
          }
          if (surname != null && surname.toString().trim().isNotEmpty) {
            parts.add(surname.toString().trim());
          }
          fullName = parts.join(' ');
        }
        if (fullName != null && fullName.isNotEmpty) {
          _nameController.text = fullName.toUpperCase();
        }

        final expirationDateStr = data['expiration_date'];
        if (expirationDateStr != null && expirationDateStr is String) {
          final expDate = _parseDateFromOcr(expirationDateStr);
          if (expDate != null) {
            setState(() {
              _selectedDate = expDate;
            });
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t(
              'Dados extraídos por Inteligência Artificial!',
              'Data extracted by Artificial Intelligence!',
            )),
            backgroundColor: AppColors.primary,
          ),
        );
      },
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final resultSource = await showModalBottomSheet<dynamic>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ImageSourceBottomSheet(
        title: _selectedFile != null || widget.currentDocument?.imageUrl != null
            ? context.t('Alterar arquivo do documento', 'Change document file')
            : context.t('Enviar ', 'Upload ') + _typeLabel(),
        supportFiles: true,
      ),
    );

    if (resultSource == null) return;

    File? file;

    if (resultSource == 'file') {
      final pickedResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      );
      if (pickedResult != null && pickedResult.files.single.path != null) {
        file = File(pickedResult.files.single.path!);
      }
    } else if (resultSource is ImageSource) {
      final image = await picker.pickImage(source: resultSource);
      if (image != null) {
        file = File(image.path);
      }
    }

    if (file != null) {
      setState(() {
        _selectedFile = file;
        _ocrError = null;
      });
      await _processDocumentOcr(file);
    }
  }

  Future<void> _onSave(BuildContext context) async {
    // For new documents, a file is required
    if (_selectedFile == null && widget.currentDocument == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(
            'Selecione um PDF ou imagem do documento.',
            'Select a PDF or image of the document.',
          )),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    final cubit = widget.cubit ?? getIt<DocumentsCubit>();

    try {
      await cubit.uploadDocument(
        id: widget.currentDocument?.id,
        type: widget.type,
        file: _selectedFile, // null is OK for existing documents (metadata-only update)
        documentNumber: _numberController.text,
        expiryDate: _selectedDate,
        documentName: _nameController.text,
        visaCountry: widget.type == DocumentType.visto
            ? _selectedCountry?.code
            : null,
      );

      if (mounted) {
        Navigator.pop(context, true); // Signal success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t(
              'Não foi possível salvar o documento. Tente novamente.',
              'Could not save the document. Please try again.',
            )),
          ),
        );
        if (kDebugMode) debugPrint('[Documents] _onSave error: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCurrentDocument = widget.currentDocument?.imageUrl != null;
    // For new documents: require a file. For existing documents: allow submit if file or fields changed.
    final isEditing = widget.currentDocument != null;
    final canSubmit = !_isUploading &&
        !_isProcessingOcr &&
        (_selectedFile != null || (isEditing && _fieldsModified));

    return Scaffold(
      appBar: AppHeader(mode: HeaderMode.back, title: _typeLabel()),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusHeader(),
            const SizedBox(height: AppSpacing.lg),

            if (_ocrError != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.2),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red[800]),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _ocrError!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.red.shade200
                              : Colors.red.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            Text(
              context.t('Arquivo do documento', 'Document file'),
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            GestureDetector(
              onTap: _openImagePreview,
              child: _buildImagePreview(),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _pickImage,
                icon: Icon(
                  hasCurrentDocument || _selectedFile != null
                      ? Icons.swap_horiz_rounded
                      : Icons.upload_file_rounded,
                  size: 20,
                ),
                label: Text(
                  hasCurrentDocument || _selectedFile != null
                      ? context.t('Substituir arquivo', 'Replace file')
                      : context.t(
                          'Selecionar PDF ou imagem',
                          'Select PDF or image',
                        ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.35),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            if (_hasDocumentNumber()) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildFieldLabel(_numberFieldLabel()),
              _DocumentTextField(
                controller: _numberController,
                hintText: _numberFieldHint(),
              ),
            ],

            // Campo de país — somente para visto
            if (widget.type == DocumentType.visto) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildFieldLabel(context.t('País do Visto', 'Visa Country')),
              InkWell(
                onTap: () async {
                  final picked = await CountryPickerBottomSheet.show(
                    context,
                    initialValue: _selectedCountry,
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedCountry = picked;
                      _fieldsModified = true;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.12),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.035),
                  ),
                  child: Row(
                    children: [
                      if (_selectedCountry != null) ...[
                        Text(
                          _flagEmoji(_selectedCountry!.code),
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedCountry!.name,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCountry = null;
                              _fieldsModified = true;
                            });
                          },
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.4),
                          ),
                        ),
                      ] else ...[
                        const Icon(
                          Icons.public_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.t('Selecionar país', 'Select country'),
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.35),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
            _buildFieldLabel(context.t('Nome no documento', 'Name on document')),
            _DocumentTextField(
              controller: _nameController,
            ),

            const SizedBox(height: AppSpacing.lg),
            _buildFieldLabel(context.t('Data de validade', 'Expiry date')),
            InkWell(
              onTap: _showDatePickerBottomSheet,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.03),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.surface,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedDate == null
                          ? context.t('Selecionar data', 'Select date')
                          : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                      style: AppTextStyles.bodyMedium,
                    ),
                    const Icon(
                      Icons.calendar_today,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: canSubmit ? () => _onSave(context) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.08),
                  disabledForegroundColor: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.38),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
                child: _isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        hasCurrentDocument
                            ? context.t(
                                'Enviar substituição para análise',
                                'Submit replacement for review',
                              )
                            : context.t(
                                'Enviar para análise',
                                'Submit for review',
                              ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// Converte código ISO 2 letras em emoji de bandeira
  String _flagEmoji(String code) {
    const base = 0x1F1E6 - 0x41;
    final chars = code.toUpperCase().codeUnits;
    if (chars.length != 2) return '🏳';
    return String.fromCharCode(base + chars[0]) +
        String.fromCharCode(base + chars[1]);
  }

  bool _hasDocumentNumber() {
    return widget.type == DocumentType.passaporte ||
        widget.type == DocumentType.visto ||
        widget.type == DocumentType.seguro ||
        widget.type == DocumentType.carteiraMotorista;
  }

  String _numberFieldLabel() {
    switch (widget.type) {
      case DocumentType.passaporte:
        return context.t('Número do Passaporte', 'Passport Number');
      case DocumentType.visto:
        return context.t('Número do Visto', 'Visa Number');
      case DocumentType.carteiraMotorista:
        return context.t('Número da CNH', "Driver's License Number");
      case DocumentType.seguro:
        return context.t('Número da Apólice', 'Policy Number');
      default:
        return context.t('Número do documento', 'Document number');
    }
  }

  String _numberFieldHint() {
    switch (widget.type) {
      case DocumentType.passaporte:
        return context.t('Ex: AA123456', 'e.g. AA123456');
      case DocumentType.visto:
        return context.t('Ex: V12345678', 'e.g. V12345678');
      case DocumentType.carteiraMotorista:
        return context.t('Ex: 00000000000', 'e.g. 00000000000');
      case DocumentType.seguro:
        return context.t('Ex: AP-000000', 'e.g. AP-000000');
      default:
        return context.t('Ex: 000000', 'e.g. 000000');
    }
  }

  Widget _buildStatusHeader() {
    if (widget.currentDocument == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.orange),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                context.t(
                  'Este documento ainda não foi enviado. Envie agora para análise.',
                  'This document has not been submitted yet. Submit it now for review.',
                ),
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.orange.shade200
                      : Colors.orange.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Color statusColor = Colors.orange;
    String statusText = context.t('Pendente de análise', 'Pending review');
    IconData icon = Icons.access_time;

    if (widget.currentDocument!.status == DocumentStatus.aprovado) {
      statusColor = AppColors.primary;
      statusText = context.t('Documento aprovado', 'Document approved');
      icon = Icons.check_circle_outline;
    } else if (widget.currentDocument!.status == DocumentStatus.recusado) {
      statusColor = AppColors.error;
      statusText = context.t('Documento recusado', 'Document rejected');
      icon = Icons.error_outline;
    } else if (widget.currentDocument!.status == DocumentStatus.expirado) {
      statusColor = AppColors.error;
      statusText = context.t('Documento expirado', 'Document expired');
      icon = Icons.warning_amber_outlined;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Icon(icon, color: statusColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  statusText,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.currentDocument!.rejectionReason != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              context.t('Motivo: ', 'Reason: ') +
                  widget.currentDocument!.rejectionReason!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label,
        style: AppTextStyles.bodyMedium.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    final localPath = _selectedFile?.path.toLowerCase();
    final remoteUrl = widget.currentDocument?.imageUrl;
    final remoteLower = remoteUrl?.toLowerCase() ?? '';
    final isLocalPdf = localPath?.endsWith('.pdf') ?? false;
    final isRemotePdf = remoteLower.contains('.pdf') ||
        remoteLower.contains('/pdf') ||
        remoteLower.contains('application/pdf');
    final fileName = _selectedFile?.path.split('/').last ??
        widget.currentDocument?.title ??
        '${_typeLabel()}.pdf';

    return Container(
      width: double.infinity,
      height: 230,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned.fill(
              child: _selectedFile != null
                  ? (isLocalPdf
                      ? _buildPdfPreview(fileName)
                      : Image.file(_selectedFile!, fit: BoxFit.cover))
                  : (remoteUrl != null
                      ? (isRemotePdf
                          ? _buildPdfPreview(fileName)
                          : Image.network(
                              widget.currentDocument!.imageUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                    child: CircularProgressIndicator());
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildPdfPreview(fileName),
                            ))
                      : _buildEmptyPreview()),
            ),
            if (_isProcessingOcr)
              const Positioned.fill(
                child: OcrScanningOverlay(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfPreview(String fileName) {
    return Container(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.025),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 30,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                fileName,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                context.t('PDF anexado • toque para abrir',
                    'PDF attached • tap to open'),
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPreview() {
    return Container(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.025),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.upload_file_rounded,
                  size: 30,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.t('Nenhum arquivo anexado', 'No file attached'),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                context.t(
                  'Envie um PDF ou uma imagem legível do documento.',
                  'Upload a PDF or a legible image of the document.',
                ),
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.54),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  const _DocumentTextField({
    required this.controller,
    this.hintText = '',
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: AppTextStyles.bodyMedium.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.36),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.035),
      ),
    );
  }
}

class OcrScanningOverlay extends StatefulWidget {
  const OcrScanningOverlay({super.key});

  @override
  State<OcrScanningOverlay> createState() => _OcrScanningOverlayState();
}

class _OcrScanningOverlayState extends State<OcrScanningOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: Colors.black.withOpacity(0.4),
        ),
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Positioned(
              top: 220 * _animation.value,
              left: 0,
              right: 0,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.8),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                  gradient: const LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.cyanAccent,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.cyanAccent,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  context.t('IA extraindo dados...', 'AI extracting data...'),
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
