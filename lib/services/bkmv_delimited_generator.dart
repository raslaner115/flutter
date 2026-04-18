class BkmvDelimitedValidationError implements Exception {
  final String message;

  const BkmvDelimitedValidationError(this.message);

  @override
  String toString() => 'BkmvDelimitedValidationError: $message';
}

class BkmvDelimitedGenerator {
  static const String systemConstant = 'OF1.31';

  static String buildRecord(String type, List<String> fields) {
    _validateRecordType(type);
    final normalizedFields = fields.map(_sanitizeField).toList(growable: false);
    return '${<String>[type, ...normalizedFields].join('|')}|';
  }

  static String buildA000({
    required String businessVatNumber,
    required int totalRecords,
    required String softwareName,
    required String softwareVersion,
    required String businessName,
    required String taxBranch,
    required String city,
    required String street,
    required String houseNumber,
    required String fromDate,
    required String toDate,
    String currency = 'ILS',
  }) {
    final vat = validateIsraeliVatNumber(businessVatNumber);
    final branch = requireDigitsOnly(taxBranch, fieldName: 'taxBranch');
    final start = requireDate(fromDate, fieldName: 'fromDate');
    final end = requireDate(toDate, fieldName: 'toDate');

    return buildRecord('A000', [
      vat,
      totalRecords.toString(),
      systemConstant,
      requireText(softwareName, fieldName: 'softwareName'),
      requireText(softwareVersion, fieldName: 'softwareVersion'),
      requireText(businessName, fieldName: 'businessName'),
      branch,
      requireText(city, fieldName: 'city'),
      requireText(street, fieldName: 'street'),
      requireText(houseNumber, fieldName: 'houseNumber'),
      start,
      end,
      requireCurrency(currency),
    ]);
  }

  static String buildA100({
    required int recordNumber,
    required String businessVatNumber,
    required String mainKey,
  }) {
    final vat = validateIsraeliVatNumber(businessVatNumber);
    final mainId = requireDigitsOnly(mainKey, fieldName: 'mainKey');

    return buildRecord('A100', [
      recordNumber.toString(),
      vat,
      mainId,
      systemConstant,
    ]);
  }

  static String buildD110({
    required int recordNumber,
    required String businessVatNumber,
    required int documentType,
    required String documentNumber,
    required int lineNumber,
    required String itemDescription,
    required String quantity,
    required String unitPrice,
    required String lineTotal,
    required String vatRate,
    required String documentDate,
    required String lineLinkKey,
    String baseDocumentType = '',
    String baseDocumentNumber = '',
    String itemCode = '',
    String unitName = 'UNIT',
  }) {
    final vat = validateIsraeliVatNumber(businessVatNumber);
    final docNo = requireDigitsOnly(
      documentNumber,
      fieldName: 'documentNumber',
    );
    final date = requireDate(documentDate, fieldName: 'documentDate');

    return buildRecord('D110', [
      recordNumber.toString(),
      vat,
      documentType.toString(),
      docNo,
      lineNumber.toString(),
      digitsOrEmpty(baseDocumentType, fieldName: 'baseDocumentType'),
      digitsOrEmpty(baseDocumentNumber, fieldName: 'baseDocumentNumber'),
      '1',
      digitsOrEmpty(itemCode, fieldName: 'itemCode'),
      requireText(itemDescription, fieldName: 'itemDescription'),
      requireText(unitName, fieldName: 'unitName'),
      requireDecimal(quantity, fieldName: 'quantity'),
      requireDecimal(unitPrice, fieldName: 'unitPrice'),
      requireDecimal(lineTotal, fieldName: 'lineTotal'),
      requireDigitsOnly(vatRate, fieldName: 'vatRate'),
      date,
      requireDigitsOnly(lineLinkKey, fieldName: 'lineLinkKey'),
    ]);
  }

  static String buildD120({
    required int recordNumber,
    required String businessVatNumber,
    required int documentType,
    required String documentNumber,
    required int lineNumber,
    required String paymentType,
    required String paymentDate,
    required String amount,
    required String documentDate,
    required String lineLinkKey,
    String bankNumber = '',
    String branchNumber = '',
    String accountNumber = '',
    String checkNumber = '',
    String creditCompany = '',
    String cardName = '',
    String creditDealType = '',
  }) {
    final vat = validateIsraeliVatNumber(businessVatNumber);
    final docNo = requireDigitsOnly(
      documentNumber,
      fieldName: 'documentNumber',
    );
    final payDate = requireDate(paymentDate, fieldName: 'paymentDate');
    final docDate = requireDate(documentDate, fieldName: 'documentDate');

    return buildRecord('D120', [
      recordNumber.toString(),
      vat,
      documentType.toString(),
      docNo,
      lineNumber.toString(),
      requireDigitsOnly(paymentType, fieldName: 'paymentType'),
      digitsOrEmpty(bankNumber, fieldName: 'bankNumber'),
      digitsOrEmpty(branchNumber, fieldName: 'branchNumber'),
      digitsOrEmpty(accountNumber, fieldName: 'accountNumber'),
      digitsOrEmpty(checkNumber, fieldName: 'checkNumber'),
      payDate,
      requireDecimal(amount, fieldName: 'amount'),
      digitsOrEmpty(creditCompany, fieldName: 'creditCompany'),
      textOrEmpty(cardName),
      digitsOrEmpty(creditDealType, fieldName: 'creditDealType'),
      docDate,
      requireDigitsOnly(lineLinkKey, fieldName: 'lineLinkKey'),
    ]);
  }

  static String buildZ900({
    required int recordNumber,
    required String businessVatNumber,
    required String mainKey,
    required int totalRecords,
  }) {
    final vat = validateIsraeliVatNumber(businessVatNumber);
    final mainId = requireDigitsOnly(mainKey, fieldName: 'mainKey');

    return buildRecord('Z900', [
      recordNumber.toString(),
      vat,
      mainId,
      systemConstant,
      totalRecords.toString(),
    ]);
  }

  static String buildSampleFile() {
    const vat = '514728653';
    const mainKey = '202604080001';

    final records = <String>[
      buildA100(recordNumber: 1, businessVatNumber: vat, mainKey: mainKey),
      buildD110(
        recordNumber: 2,
        businessVatNumber: vat,
        documentType: 400,
        documentNumber: '1',
        lineNumber: 1,
        itemDescription: 'Sample service',
        quantity: '1',
        unitPrice: '1500.00',
        lineTotal: '1500.00',
        vatRate: '0',
        documentDate: '20260408',
        lineLinkKey: '1',
      ),
      buildD120(
        recordNumber: 3,
        businessVatNumber: vat,
        documentType: 400,
        documentNumber: '1',
        lineNumber: 1,
        paymentType: '1',
        paymentDate: '20260408',
        amount: '1500.00',
        documentDate: '20260408',
        lineLinkKey: '1',
      ),
      buildZ900(
        recordNumber: 4,
        businessVatNumber: vat,
        mainKey: mainKey,
        totalRecords: 4,
      ),
    ];

    return '${records.join('\n')}\n';
  }

  static String buildSampleIni() {
    final sample = buildSampleFile().trim().split('\n');
    return '${buildA000(businessVatNumber: '514728653', totalRecords: sample.length, softwareName: 'hiro', softwareVersion: '1.0.0', businessName: 'Sample Business', taxBranch: '1', city: 'Tel Aviv', street: 'Herzl', houseNumber: '1', fromDate: '20260401', toDate: '20260430')}\nD110|000000000000001|\nD120|000000000000001|\n';
  }

  static String validateIsraeliVatNumber(String value) {
    final digits = requireDigitsOnly(
      value,
      fieldName: 'vatNumber',
    ).padLeft(9, '0');
    if (digits.length != 9 || !_isValidIsraeliVatNumber(digits)) {
      throw const BkmvDelimitedValidationError(
        'Invalid Israeli VAT number checksum.',
      );
    }
    return digits;
  }

  static String requireDigitsOnly(String value, {required String fieldName}) {
    final normalized = value.trim();
    if (normalized.isEmpty || !RegExp(r'^\d+$').hasMatch(normalized)) {
      throw BkmvDelimitedValidationError(
        '$fieldName must contain digits only.',
      );
    }
    return normalized;
  }

  static String digitsOrEmpty(String value, {required String fieldName}) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return '';
    }
    if (!RegExp(r'^\d+$').hasMatch(normalized)) {
      throw BkmvDelimitedValidationError(
        '$fieldName must contain digits only.',
      );
    }
    return normalized;
  }

  static String requireDate(String value, {required String fieldName}) {
    final digits = requireDigitsOnly(value, fieldName: fieldName);
    if (digits.length != 8) {
      throw BkmvDelimitedValidationError('$fieldName must be YYYYMMDD.');
    }
    final year = int.parse(digits.substring(0, 4));
    final month = int.parse(digits.substring(4, 6));
    final day = int.parse(digits.substring(6, 8));
    final date = DateTime.tryParse(
      '$year-${digits.substring(4, 6)}-${digits.substring(6, 8)}',
    );
    if (date == null ||
        date.year != year ||
        date.month != month ||
        date.day != day) {
      throw BkmvDelimitedValidationError(
        '$fieldName must be a valid YYYYMMDD date.',
      );
    }
    return digits;
  }

  static String requireDecimal(String value, {required String fieldName}) {
    final normalized = value.trim();
    if (normalized.isEmpty ||
        normalized.contains(',') ||
        normalized.contains('&')) {
      throw BkmvDelimitedValidationError(
        '$fieldName must use dot decimal format only.',
      );
    }
    if (!RegExp(r'^\d+(\.\d{1,4})?$').hasMatch(normalized)) {
      throw BkmvDelimitedValidationError(
        '$fieldName must be an unsigned decimal number.',
      );
    }
    return normalized;
  }

  static String requireText(String value, {required String fieldName}) {
    final normalized = textOrEmpty(value);
    if (normalized.isEmpty) {
      throw BkmvDelimitedValidationError('$fieldName is required.');
    }
    return normalized;
  }

  static String textOrEmpty(String value) {
    return _sanitizeField(value);
  }

  static String requireCurrency(String value) {
    final normalized = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(normalized)) {
      throw const BkmvDelimitedValidationError(
        'currency must be a 3-letter code.',
      );
    }
    return normalized;
  }

  static String _sanitizeField(String value) {
    final normalized = value
        .replaceAll('\r\n', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll(RegExp(r'\s+'), '')
        .trim();

    if (normalized.contains('|')) {
      throw const BkmvDelimitedValidationError(
        'Fields cannot contain the "|" character.',
      );
    }
    if (normalized.contains('&')) {
      throw const BkmvDelimitedValidationError(
        'Fields cannot contain the "&" character.',
      );
    }
    return normalized;
  }

  static void _validateRecordType(String value) {
    if (!RegExp(r'^[A-Z]\d{3}$').hasMatch(value)) {
      throw const BkmvDelimitedValidationError(
        'Record type must look like A000 or D120.',
      );
    }
  }

  static bool _isValidIsraeliVatNumber(String digits) {
    var sum = 0;
    for (var i = 0; i < 8; i++) {
      var product = int.parse(digits[i]) * ((i % 2) + 1);
      if (product > 9) {
        product = (product ~/ 10) + (product % 10);
      }
      sum += product;
    }
    final checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit == int.parse(digits[8]);
  }
}
