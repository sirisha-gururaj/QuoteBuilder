import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quote_builder/models/line_item.dart';
import 'package:quote_builder/widgets/form_helpers.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf;
import 'package:printing/printing.dart';

enum QuoteStatus { draft, sent, accepted }

extension QuoteStatusExt on QuoteStatus {
  String get label {
    switch (this) {
      case QuoteStatus.draft:
        return 'Draft';
      case QuoteStatus.sent:
        return 'Sent';
      case QuoteStatus.accepted:
        return 'Accepted';
    }
  }

  String toJson() => this.toString().split('.').last;

  static QuoteStatus fromJson(String s) {
    switch (s.toLowerCase()) {
      case 'sent':
        return QuoteStatus.sent;
      case 'accepted':
        return QuoteStatus.accepted;
      default:
        return QuoteStatus.draft;
    }
  }
}

// The main page, as a StatefulWidget to hold our app's state
class QuoteBuilderPage extends StatefulWidget {
  const QuoteBuilderPage({super.key});

  @override
  State<QuoteBuilderPage> createState() => _QuoteBuilderPageState();
}

class _QuoteBuilderPageState extends State<QuoteBuilderPage> {
  // --- STATE VARIABLES ---
  // This is the "single source of truth" for our app data.

  // Client Info
  final _clientNameController = TextEditingController();
  final _clientAddressController = TextEditingController();
  final _clientRefController = TextEditingController();

  // Quote Settings
  // Quote Settings
  QuoteStatus _quoteStatus = QuoteStatus.draft;
  String _taxMode = 'exclusive'; // 'exclusive' or 'inclusive'
  String _selectedCurrencySymbol = '₹'; // Replaced controller

  bool get _isEditable => _quoteStatus == QuoteStatus.draft;

  // Define our currency options
  final Map<String, String> _currencies = {
    '₹': 'INR (₹)',
    '\$': 'USD (\$)',
    '€': 'EUR (€)',
    '£': 'GBP (£)',
    '¥': 'JPY (¥)',
    'A\$': 'AUD (A\$)',
    'C\$': 'CAD (C\$)',
  };

  // Line Items
  List<LineItem> _lineItems = [];

  // Calculated Totals
  double _subtotal = 0;
  double _totalTax = 0;
  double _grandTotal = 0;

  // For currency formatting
  late NumberFormat _currencyFormatter;
  // Key used to locate the currency field for custom popup positioning
  final GlobalKey _currencyFieldKey = GlobalKey();
  // Key for tax mode field so we can position its popup similarly
  final GlobalKey _taxFieldKey = GlobalKey();
  // LayerLinks for composited transforms so overlays follow scrolling
  final LayerLink _currencyLink = LayerLink();
  final LayerLink _taxLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _updateCurrencyFormatter();
    // Start with one blank row
    _addRow();
  }

  /// Build Tax Mode dropdown using a positioned `showMenu` so the popup
  /// appears slightly below the field (avoids overlap).
  Widget _buildTaxModeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tax Mode',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: CompositedTransformTarget(
            link: _taxLink,
            child: GestureDetector(
              key: _taxFieldKey,
              onTap: () async {
                if (!_isEditable) return;
                final RenderBox? rb =
                    _taxFieldKey.currentContext?.findRenderObject()
                        as RenderBox?;
                if (rb == null) return;
                const double menuHeight = 120.0;

                // Controller to handle pointer-wheel scrolling inside the overlay
                final ScrollController listController = ScrollController();
                late OverlayEntry overlayEntry;

                overlayEntry = OverlayEntry(
                  builder: (ctx) {
                    return CompositedTransformFollower(
                      link: _taxLink,
                      offset: Offset(0, rb.size.height + 8),
                      targetAnchor: Alignment.topLeft,
                      followerAnchor: Alignment.topLeft,
                      showWhenUnlinked: false,
                      child: Material(
                        color: Colors.transparent,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: rb.size.width,
                            ),
                            child: SizedBox(
                              width: rb.size.width,
                              height: menuHeight,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Listener(
                                  behavior: HitTestBehavior.opaque,
                                  onPointerSignal: (ps) {
                                    if (!listController.hasClients) return;
                                    try {
                                      final dy =
                                          (ps as dynamic).scrollDelta.dy
                                              as double;
                                      final newOffset =
                                          (listController.offset + dy).clamp(
                                            listController
                                                .position
                                                .minScrollExtent,
                                            listController
                                                .position
                                                .maxScrollExtent,
                                          );
                                      listController.jumpTo(newOffset);
                                    } catch (_) {}
                                  },
                                  child: ListView(
                                    controller: listController,
                                    padding: EdgeInsets.zero,
                                    primary: false,
                                    physics: const ClampingScrollPhysics(),
                                    shrinkWrap: false,
                                    children: [
                                      ListTile(
                                        title: const Text('Tax Exclusive'),
                                        onTap: () {
                                          overlayEntry.remove();
                                          if (_taxMode != 'exclusive') {
                                            setState(
                                              () => _taxMode = 'exclusive',
                                            );
                                            _calculateQuote();
                                          }
                                        },
                                      ),
                                      ListTile(
                                        title: const Text('Tax Inclusive'),
                                        onTap: () {
                                          overlayEntry.remove();
                                          if (_taxMode != 'inclusive') {
                                            setState(
                                              () => _taxMode = 'inclusive',
                                            );
                                            _calculateQuote();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );

                Overlay.of(context, rootOverlay: true).insert(overlayEntry);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _taxMode == 'exclusive'
                          ? 'Tax Exclusive'
                          : 'Tax Inclusive',
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _updateCurrencyFormatter() {
    setState(() {
      _currencyFormatter = NumberFormat.currency(
        symbol: _selectedCurrencySymbol,
        decimalDigits: 2,
      );
    });
  }

  @override
  void dispose() {
    // Clean up controllers
    _clientNameController.dispose();
    _clientAddressController.dispose();
    _clientRefController.dispose();
    super.dispose();
  }

  // --- CORE LOGIC ---

  /// Adds a new blank LineItem to our state
  void _addRow() {
    setState(() {
      _lineItems.add(LineItem(id: UniqueKey().toString()));
    });
    _calculateQuote();
  }

  /// Removes a LineItem from our state by its unique ID
  void _removeRow(String id) {
    setState(() {
      _lineItems.removeWhere((item) => item.id == id);
    });
    _calculateQuote();
  }

  /// The main calculation engine.
  /// Iterates over the _lineItems list (our state) and calculates totals.
  void _calculateQuote() {
    double newSubtotal = 0;
    double newTotalTax = 0;

    for (var item in _lineItems) {
      double lineSubtotal, lineTax, lineTotal;
      double basePrice = (item.rate - item.discount) * item.quantity;

      if (_taxMode == 'exclusive') {
        // Tax is ADDED to the price
        lineSubtotal = basePrice;
        lineTax = basePrice * (item.taxPercent / 100);
        lineTotal = lineSubtotal + lineTax;
      } else {
        // Tax is INCLUDED in the price
        lineTotal = basePrice; // The total paid is the base price
        double preTaxAmount = lineTotal / (1 + (item.taxPercent / 100));
        lineTax = lineTotal - preTaxAmount;
        lineSubtotal = preTaxAmount;
      }

      item.total = lineTotal; // Update the item's total
      newSubtotal += lineSubtotal;
      newTotalTax += lineTax;
    }

    // Update the state variables, which will trigger the UI to rebuild
    setState(() {
      _subtotal = newSubtotal;
      _totalTax = newTotalTax;
      _grandTotal = newSubtotal + newTotalTax;
    });
  }

  // --- MOCK ACTIONS ---

  void _showMockSnackBar(String message, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green[600],
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 16),
            Text(message, style: const TextStyle(fontSize: 16)),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _saveQuote() {
    _saveDraft();
  }

  /// Persist current quote state as a draft in SharedPreferences.
  Future<void> _saveDraft() async {
    _calculateQuote(); // Ensure totals are current
    // If there's nothing meaningful to save, inform the user and return.
    if (!_hasDraftData()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nothing to save')));
      return;
    }
    // If the current filled data is incomplete (partial line items or missing
    // required bits), inform the user and don't save.
    if (_isDraftIncomplete()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Draft is incomplete. Please fill required fields before saving.',
          ),
        ),
      );
      return;
    }

    // If the user has only filled client details and nothing else, ask them
    // whether they want to continue editing or save anyway. This prevents
    // accidental saves when only the client info was entered.
    if (_isOnlyClientData()) {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Incomplete draft'),
          content: const Text(
            'You have only filled client details. Do you want to save the draft now or continue filling the remaining details?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Continue editing'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save anyway'),
            ),
          ],
        ),
      );

      // If the user chose not to save, just return.
      if (result != true) return;
    }
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'clientName': _clientNameController.text,
      'clientAddress': _clientAddressController.text,
      'clientRef': _clientRefController.text,
      'quoteStatus': _quoteStatus.toJson(),
      'taxMode': _taxMode,
      'currency': _selectedCurrencySymbol,
      'lineItems': _lineItems
          .map(
            (item) => {
              'id': item.id,
              'name': item.name,
              'quantity': item.quantity,
              'rate': item.rate,
              'discount': item.discount,
              'taxPercent': item.taxPercent,
              'total': item.total,
            },
          )
          .toList(),
    };
    // We store drafts as a list under the key 'quote_drafts' so the user can
    // save multiple drafts. Keep the legacy 'quote_draft' key updated for
    // compatibility with older flows.
    try {
      final rawList = prefs.getString('quote_drafts');
      List<dynamic> list = rawList != null ? jsonDecode(rawList) as List : [];

      final entry = Map<String, dynamic>.from(data);
      entry['id'] = DateTime.now().toIso8601String();
      entry['createdAt'] = DateTime.now().toIso8601String();

      list.add(entry);
      await prefs.setString('quote_drafts', jsonEncode(list));

      // Also update the single-key for backward compatibility
      await prefs.setString('quote_draft', jsonEncode(data));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.save_rounded, color: Colors.white),
              const SizedBox(width: 12),
              const Expanded(child: Text('Draft saved locally')),
            ],
          ),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Load',
            textColor: Colors.white,
            onPressed: () => _openDraftManager(),
          ),
        ),
      );
    } catch (err) {
      // Fallback: try writing to single key
      await prefs.setString('quote_draft', jsonEncode(data));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.save_rounded, color: Colors.white),
              const SizedBox(width: 12),
              const Expanded(child: Text('Draft saved locally (fallback)')),
            ],
          ),
        ),
      );
    }
  }

  /// Returns true if the current form contains any non-default data
  /// that should be considered worth saving as a draft.
  bool _hasDraftData() {
    // Check basic text fields
    if (_clientNameController.text.trim().isNotEmpty) return true;
    if (_clientAddressController.text.trim().isNotEmpty) return true;
    if (_clientRefController.text.trim().isNotEmpty) return true;

    // Check settings
    if (_quoteStatus != QuoteStatus.draft) return true;
    if (_taxMode != 'exclusive') return true;
    if (_selectedCurrencySymbol != '₹') return true;

    // Check line items for any non-default values
    for (var item in _lineItems) {
      if (item.name.trim().isNotEmpty) return true;
      if (item.rate != 0) return true;
      if (item.discount != 0) return true;
      if (item.taxPercent != 0) return true;
      if (item.quantity != 1) return true;
    }

    // Nothing significant found
    return false;
  }

  /// Returns true if the current data appears incomplete/partial and should
  /// not be saved as a draft. Examples:
  /// - A line item has any non-default values but is missing the product name
  /// - A line item has a name but zero rate (likely incomplete)
  bool _isDraftIncomplete() {
    for (var item in _lineItems) {
      final hasNonDefault =
          item.name.trim().isNotEmpty ||
          item.rate != 0 ||
          item.discount != 0 ||
          item.taxPercent != 0 ||
          item.quantity != 1;

      if (hasNonDefault) {
        // If name is empty but other fields are filled -> incomplete
        if (item.name.trim().isEmpty) return true;
        // If name present but rate is zero -> likely incomplete
        if (item.name.trim().isNotEmpty && item.rate == 0) return true;
      }
    }

    // Also consider client name required when any line items exist
    final anyLinePopulated = _lineItems.any((it) => it.name.trim().isNotEmpty);
    if (anyLinePopulated && _clientNameController.text.trim().isEmpty) {
      return true;
    }

    return false;
  }

  /// Returns true when only client-related fields are filled and no other
  /// meaningful data (settings or line items) has been entered. Used to
  /// prompt the user before saving a draft that would contain only client info.
  bool _isOnlyClientData() {
    final clientFilled =
        _clientNameController.text.trim().isNotEmpty ||
        _clientAddressController.text.trim().isNotEmpty ||
        _clientRefController.text.trim().isNotEmpty;
    if (!clientFilled) return false;

    // If any non-default setting is present, it's not "only client" data.
    if (_quoteStatus != QuoteStatus.draft) return false;
    if (_taxMode != 'exclusive') return false;
    if (_selectedCurrencySymbol != '₹') return false;

    // If any line item has non-default values, it's not only client info.
    for (var item in _lineItems) {
      final hasNonDefault =
          item.name.trim().isNotEmpty ||
          item.rate != 0 ||
          item.discount != 0 ||
          item.taxPercent != 0 ||
          item.quantity != 1;
      if (hasNonDefault) return false;
    }

    return true;
  }

  /// Apply a decoded draft map to the current UI state.
  void _applyDraftMap(Map<String, dynamic> map) {
    setState(() {
      _clientNameController.text = map['clientName'] ?? '';
      _clientAddressController.text = map['clientAddress'] ?? '';
      _clientRefController.text = map['clientRef'] ?? '';
      _quoteStatus = QuoteStatusExt.fromJson(
        (map['quoteStatus'] as String?) ?? 'draft',
      );
      _taxMode = map['taxMode'] ?? 'exclusive';
      _selectedCurrencySymbol = map['currency'] ?? _selectedCurrencySymbol;
      final items = (map['lineItems'] as List<dynamic>?) ?? [];
      _lineItems = items.map((e) {
        return LineItem(
          id: e['id'] ?? UniqueKey().toString(),
          name: e['name'] ?? '',
          quantity: (e['quantity'] is num)
              ? (e['quantity'] as num).toDouble()
              : double.tryParse('${e['quantity']}') ?? 1,
          rate: (e['rate'] is num)
              ? (e['rate'] as num).toDouble()
              : double.tryParse('${e['rate']}') ?? 0,
          discount: (e['discount'] is num)
              ? (e['discount'] as num).toDouble()
              : double.tryParse('${e['discount']}') ?? 0,
          taxPercent: (e['taxPercent'] is num)
              ? (e['taxPercent'] as num).toDouble()
              : double.tryParse('${e['taxPercent']}') ?? 0,
          total: (e['total'] is num)
              ? (e['total'] as num).toDouble()
              : double.tryParse('${e['total']}') ?? 0,
        );
      }).toList();
    });

    _updateCurrencyFormatter();
    _calculateQuote();
  }

  void _sendQuote() {
    setState(() {
      _quoteStatus = QuoteStatus.sent;
    });
    _calculateQuote();
    // In a real app, you'd save and maybe trigger an email
    _showMockSnackBar('Quote marked as "Sent" and saved!', Icons.send_rounded);
  }

  void _printQuote() {
    _generateAndPrintPdf();
  }

  /// Whether the Send / Print actions should be enabled.
  /// We reuse the existing validation helpers: require there to be draft-worthy
  /// data and to not be considered "incomplete".
  bool get _canSendOrPrint => _hasDraftData() && !_isDraftIncomplete();

  Future<void> _generateAndPrintPdf() async {
    // Build a simple PDF document reflecting the current quote state.
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
        build: (context) {
          // Header
          final header = pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'QUOTE',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'FROM',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: pdf.PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        'Sample Company',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        '123 Dummy Road, Test City',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'FOR',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: pdf.PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        _clientNameController.text.isEmpty
                            ? 'Client Name'
                            : _clientNameController.text,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        _clientAddressController.text.isEmpty
                            ? 'Client Address'
                            : _clientAddressController.text,
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(),
            ],
          );

          // Items table
          final tableHeaders = ['Item', 'Qty', 'Rate', 'Total'];
          // Use a currency code label (e.g., 'INR') for the PDF so symbols
          // like '₹' (which may be unavailable in the PDF font) are avoided.
          final currencyLabel =
              (_currencies[_selectedCurrencySymbol] ?? _selectedCurrencySymbol)
                  .split(' ')
                  .first
                  .toUpperCase();

          String pdfMoney(double amount) {
            final formatted = _currencyFormatter.format(amount);
            final withoutSymbol = formatted
                .replaceAll(_selectedCurrencySymbol, '')
                .trim();
            return '$currencyLabel $withoutSymbol';
          }

          final tableData = _lineItems.map((item) {
            return [
              item.name.isEmpty ? 'Untitled Item' : item.name,
              item.quantity.toString(),
              pdfMoney(item.rate),
              pdfMoney(item.total),
            ];
          }).toList();

          final totals = pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [pw.Text('Subtotal: '), pw.Text(pdfMoney(_subtotal))],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [pw.Text('Tax: '), pw.Text(pdfMoney(_totalTax))],
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Grand Total: ',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    pdfMoney(_grandTotal),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ],
          );

          return <pw.Widget>[
            header,
            pw.SizedBox(height: 8),
            pw.Text(
              'Quote Items',
              style: pw.TextStyle(fontSize: 12, color: pdf.PdfColors.grey700),
            ),
            pw.SizedBox(height: 6),
            pw.Table.fromTextArray(
              headers: tableHeaders,
              data: tableData,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: pw.BoxDecoration(color: pdf.PdfColors.grey300),
            ),
            pw.SizedBox(height: 12),
            totals,
          ];
        },
      ),
    );

    try {
      final bytes = await doc.save();
      await Printing.layoutPdf(onLayout: (format) async => bytes);
    } catch (err) {
      _showMockSnackBar('Failed to generate/print PDF', Icons.error);
    }
  }

  /// Opens a small Draft Manager dialog that lets the user view the saved
  /// draft JSON, load it into the form, or delete it from SharedPreferences.
  Future<void> _openDraftManager() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    // Try to load the drafts list. If not present, attempt to migrate any
    // legacy single draft into the list.
    String? rawList = prefs.getString('quote_drafts');
    if (rawList == null) {
      final legacy = prefs.getString('quote_draft');
      if (legacy != null) {
        // Migrate the single draft into the drafts list
        try {
          final decoded = jsonDecode(legacy);
          final list = [decoded];
          await prefs.setString('quote_drafts', jsonEncode(list));
          rawList = jsonEncode(list);
        } catch (_) {
          // ignore migration errors, fall through
        }
      }
    }

    List<dynamic> drafts = [];
    if (rawList != null) {
      try {
        drafts = jsonDecode(rawList) as List<dynamic>;
      } catch (_) {
        drafts = [];
      }
    }

    // Provide immediate feedback so the user knows whether drafts were found.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Found ${drafts.length} saved draft(s)')),
      );
    }

    if (drafts.isEmpty) {
      // No drafts available. Provide a small diagnostic dialog showing
      // what keys exist in SharedPreferences so users can see why nothing
      // is displayed (helps diagnose platform/storage issues).
      final keys = prefs.getKeys().toList();
      final keysStr = keys.isEmpty ? '(no keys)' : keys.join(', ');
      // Print for Console/DevTools visibility as well.
      // ignore: avoid_print
      print('Draft Manager opened: no drafts found; prefs keys: $keysStr');

      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No saved drafts'),
          content: const Text('There are no saved drafts to view.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    // Show a dialog with a list of drafts. Use StatefulBuilder to update the
    // dialog UI when drafts are deleted.
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInnerState) {
          void deleteAt(int idx) async {
            drafts.removeAt(idx);
            await prefs.setString('quote_drafts', jsonEncode(drafts));
            setInnerState(() {});
            if (drafts.isEmpty) Navigator.of(ctx).pop();
          }

          return AlertDialog(
            title: const Text('Saved Drafts'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: drafts.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (c, i) {
                  final d = drafts[i] as Map<String, dynamic>;
                  final client = (d['clientName'] as String?)?.trim();
                  final title = (client != null && client.isNotEmpty)
                      ? client
                      : (d['clientRef'] as String?)?.trim().isNotEmpty == true
                      ? d['clientRef']
                      : 'Untitled Draft';
                  final created = (d['createdAt'] as String?) ?? d['id'] ?? '';
                  return ListTile(
                    title: Text(title),
                    subtitle: Text(created),
                    isThreeLine: false,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.download_rounded),
                          tooltip: 'Load',
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            try {
                              _applyDraftMap(Map<String, dynamic>.from(d));
                              _showMockSnackBar('Draft loaded', Icons.refresh);
                            } catch (_) {
                              _showMockSnackBar(
                                'Failed to load draft',
                                Icons.error,
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete',
                          onPressed: () => deleteAt(i),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  // Delete all
                  drafts.clear();
                  await prefs.remove('quote_drafts');
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All drafts deleted')),
                  );
                },
                child: const Text('Delete All'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- UI WIDGETS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 64,
        titleSpacing: 20,
        title: Row(
          children: [
            // Minimal, professional title — intentionally concise
            Text(
              'QuoteBuilder',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        // subtle bottom divider to separate appbar from content
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      // Use a LayoutBuilder to create a responsive layout
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Check for a wide screen (e.g., tablet landscape or desktop)
          bool isWideScreen = constraints.maxWidth > 1024;

          if (isWideScreen) {
            // --- WIDE SCREEN LAYOUT (Row) ---
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Side: Form (2/3 width)
                Flexible(
                  flex: 2,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: _buildForm(),
                    ),
                  ),
                ),
                // Right Side: Preview (1/3 width)
                Flexible(
                  flex: 1,
                  child: Container(
                    color: Colors.blueGrey.shade50.withOpacity(0.5),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        // Sticky preview using ConstrainedBox
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 48,
                          ),
                          child: _buildPreview(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            // --- NARROW SCREEN LAYOUT (Column) ---
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildForm(),
                    const SizedBox(height: 24),
                    const Divider(thickness: 1),
                    const SizedBox(height: 24),
                    Text(
                      'Quote Preview',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    _buildPreview(),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }

  /// Builds the entire left-hand form
  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildClientInfoCard(),
        _buildLineItemsCard(),
        _buildTotalsCard(),
        _buildActionsCard(),
      ],
    );
  }

  /// Builds a custom currency selector that uses `showMenu` so we can
  /// control the popup's position and nudge it slightly downwards.
  Widget _buildCurrencyDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Currency',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: CompositedTransformTarget(
            link: _currencyLink,
            child: GestureDetector(
              key: _currencyFieldKey,
              onTap: () async {
                if (!_isEditable) return;
                final RenderBox? rb =
                    _currencyFieldKey.currentContext?.findRenderObject()
                        as RenderBox?;
                if (rb == null) return;

                const double menuHeight = 300.0;

                // Controller to handle pointer-wheel scrolling inside the currency overlay
                final ScrollController currencyListController =
                    ScrollController();
                late OverlayEntry overlayEntry;

                overlayEntry = OverlayEntry(
                  builder: (ctx) {
                    return CompositedTransformFollower(
                      link: _currencyLink,
                      offset: Offset(0, rb.size.height + 8),
                      targetAnchor: Alignment.topLeft,
                      followerAnchor: Alignment.topLeft,
                      showWhenUnlinked: false,
                      child: Material(
                        color: Colors.transparent,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: rb.size.width,
                            ),
                            child: SizedBox(
                              width: rb.size.width,
                              height: menuHeight,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Listener(
                                    behavior: HitTestBehavior.opaque,
                                    onPointerSignal: (ps) {
                                      if (!currencyListController.hasClients)
                                        return;
                                      try {
                                        final dy =
                                            (ps as dynamic).scrollDelta.dy
                                                as double;
                                        final newOffset =
                                            (currencyListController.offset + dy)
                                                .clamp(
                                                  currencyListController
                                                      .position
                                                      .minScrollExtent,
                                                  currencyListController
                                                      .position
                                                      .maxScrollExtent,
                                                );
                                        currencyListController.jumpTo(
                                          newOffset,
                                        );
                                      } catch (_) {
                                        // ignore non-scroll signals
                                      }
                                    },
                                    child: ListView.builder(
                                      controller: currencyListController,
                                      padding: EdgeInsets.zero,
                                      primary: false,
                                      physics: const ClampingScrollPhysics(),
                                      shrinkWrap: false,
                                      itemCount: _currencies.length,
                                      itemBuilder: (context, i) {
                                        final symbol = _currencies.keys
                                            .elementAt(i);
                                        return ListTile(
                                          title: Text(
                                            _currencies[symbol] ?? symbol,
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 14,
                                            ),
                                          ),
                                          onTap: () {
                                            overlayEntry.remove();
                                            if (symbol !=
                                                _selectedCurrencySymbol) {
                                              setState(() {
                                                _selectedCurrencySymbol =
                                                    symbol;
                                              });
                                              _updateCurrencyFormatter();
                                              _calculateQuote();
                                            }
                                          },
                                          dense: true,
                                          hoverColor: Colors.grey.shade100,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                              ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );

                Overlay.of(context, rootOverlay: true).insert(overlayEntry);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _currencies[_selectedCurrencySymbol] ??
                          _selectedCurrencySymbol,
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Client Info Card (Name, Address, Ref)
  Widget _buildClientInfoCard() {
    return Card(
      clipBehavior: Clip.none,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Client Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            ResponsiveFieldGrid(
              children: [
                buildTextField(
                  label: 'Client Name',
                  controller: _clientNameController,
                  onChanged: (_) => setState(() {}),
                  enabled: _isEditable,
                ),
                buildTextField(
                  label: 'Reference / PO Number',
                  controller: _clientRefController,
                  onChanged: (_) => setState(() {}),
                  enabled: _isEditable,
                ),
              ],
            ),
            const SizedBox(height: 16),
            buildTextField(
              label: 'Client Address',
              controller: _clientAddressController,
              onChanged: (_) => setState(() {}),
              maxLines: 3,
              enabled: _isEditable,
            ),
            const SizedBox(height: 16),
            // Place Tax Mode and Currency fields side-by-side horizontally.
            Row(
              children: [
                Expanded(child: _buildTaxModeDropdown()),
                const SizedBox(width: 16),
                Expanded(child: _buildCurrencyDropdown()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Line Items Card (Dynamic List)
  Widget _buildLineItemsCard() {
    return Card(
      clipBehavior: Clip.none,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Line Items',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add Item'),
                  onPressed: _isEditable ? _addRow : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // The dynamic list of TextFormFields
            // We use ListView.builder to efficiently create a row for each item in our state
            ListView.builder(
              shrinkWrap: true, // Important inside a SingleChildScrollView
              physics:
                  const NeverScrollableScrollPhysics(), // Parent handles scrolling
              itemCount: _lineItems.length,
              itemBuilder: (context, index) {
                final item = _lineItems[index];
                return _buildLineItemRow(item, index);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// A single row in the Line Items list
  Widget _buildLineItemRow(LineItem item, int index) {
    // This is a complex widget. We use a combination of LayoutBuilder
    // and manual layout to make it responsive.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          buildTextField(
            label: 'Product/Service Name',
            initialValue: item.name,
            // When the text changes, update the item in our state list
            // and trigger a recalculation.
            onChanged: (val) {
              item.name = val;
              _calculateQuote();
            },
            prefixIcon: IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
              onPressed: _isEditable ? () => _removeRow(item.id) : null,
            ),
            enabled: _isEditable,
          ),
          const SizedBox(height: 12),
          // Use a Row for the number fields
          Row(
            children: [
              Expanded(
                flex: 2,
                child: buildTextField(
                  label: 'Qty',
                  initialValue: item.quantity.toString(),
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    item.quantity = double.tryParse(val) ?? 0;
                    _calculateQuote();
                  },
                  enabled: _isEditable,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: buildTextField(
                  label: 'Rate',
                  initialValue: item.rate != 0 ? item.rate.toString() : null,
                  hint: '0',
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    item.rate = double.tryParse(val) ?? 0;
                    _calculateQuote();
                  },
                  enabled: _isEditable,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: buildTextField(
                  label: 'Discount',
                  initialValue: item.discount != 0
                      ? item.discount.toString()
                      : null,
                  hint: '0',
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    item.discount = double.tryParse(val) ?? 0;
                    _calculateQuote();
                  },
                  enabled: _isEditable,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: buildTextField(
                  label: 'Tax %',
                  initialValue: item.taxPercent != 0
                      ? item.taxPercent.toString()
                      : null,
                  hint: '0',
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    item.taxPercent = double.tryParse(val) ?? 0;
                    _calculateQuote();
                  },
                  enabled: _isEditable,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Show the calculated total for this row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Item Total: ',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              Text(
                _currencyFormatter.format(item.total),
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (index < _lineItems.length - 1)
            const Divider(height: 24, thickness: 1),
        ],
      ),
    );
  }

  /// Totals Card (Subtotal, Tax, Grand Total)
  Widget _buildTotalsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildTotalRow('Subtotal', _currencyFormatter.format(_subtotal)),
            _buildTotalRow('Total Tax', _currencyFormatter.format(_totalTax)),
            const Divider(height: 20, thickness: 1),
            _buildTotalRow(
              'Grand Total',
              _currencyFormatter.format(_grandTotal),
              isGrandTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  /// A helper for a single row in the totals card
  Widget _buildTotalRow(
    String label,
    String value, {
    bool isGrandTotal = false,
  }) {
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal,
      fontSize: isGrandTotal ? 20 : 16,
      color: isGrandTotal
          ? Colors.blueAccent
          : Theme.of(context).textTheme.bodyMedium?.color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }

  /// Actions Card (Save, Send, Print)
  Widget _buildActionsCard() {
    return Card(
      color: Colors.transparent,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ResponsiveFieldGrid(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.save_alt_rounded),
              label: const Text('Save Draft'),
              onPressed: _saveQuote,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('Load Draft'),
              onPressed: _openDraftManager,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo[600],
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.send_rounded),
              label: const Text('Simulate Send'),
              onPressed: _canSendOrPrint ? _sendQuote : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _canSendOrPrint
                    ? Colors.green[600]
                    : Colors.grey[400],
              ),
            ),
            // Wrap with Tooltip when disabled to explain why actions are gated
            Tooltip(
              message: _canSendOrPrint
                  ? ''
                  : 'Please complete required fields and line items to enable',
              preferBelow: false,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.print_rounded),
                label: const Text('Print / PDF'),
                onPressed: _canSendOrPrint ? _printQuote : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canSendOrPrint
                      ? Colors.blueGrey[600]
                      : Colors.grey[400],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the right-hand, read-only preview panel
  Widget _buildPreview() {
    Color statusColor;
    Color statusBgColor;

    switch (_quoteStatus) {
      case QuoteStatus.sent:
        statusColor = Colors.blue[800]!;
        statusBgColor = Colors.blue[100]!;
        break;
      case QuoteStatus.accepted:
        statusColor = Colors.green[800]!;
        statusBgColor = Colors.green[100]!;
        break;
      // no declined state; handled above
      default: // Draft
        statusColor = Colors.orange[800]!;
        statusBgColor = Colors.orange[100]!;
    }

    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Preview Header ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QUOTE',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (_clientRefController.text.isNotEmpty)
                      Text(
                        'Ref: ${_clientRefController.text}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                  ],
                ),
                MouseRegion(
                  cursor: _quoteStatus == QuoteStatus.sent
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _quoteStatus == QuoteStatus.sent
                          ? () {
                              setState(() {
                                _quoteStatus = QuoteStatus.draft;
                              });
                              _showMockSnackBar(
                                'Quote set to Draft. Editing enabled.',
                                Icons.edit_rounded,
                              );
                            }
                          : null,
                      child: Chip(
                        label: Text(_quoteStatus.label.toUpperCase()),
                        backgroundColor: statusBgColor,
                        labelStyle: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),

            // --- Preview From/To ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FROM',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        'Sample Company',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '123 Dummy Road, Test City',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FOR',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        _clientNameController.text.isEmpty
                            ? 'Client Name'
                            : _clientNameController.text,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _clientAddressController.text.isEmpty
                            ? 'Client Address'
                            : _clientAddressController.text,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- Preview Items ---
            Text(
              'QUOTE ITEMS',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            ..._lineItems.map((item) => _buildPreviewItemRow(item)).toList(),
            if (_lineItems.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Text(
                  'No items added yet.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
              ),

            // --- Preview Totals ---
            const SizedBox(height: 24),
            const Divider(thickness: 1),
            const SizedBox(height: 16),
            _buildTotalRow('Subtotal', _currencyFormatter.format(_subtotal)),
            _buildTotalRow('Tax', _currencyFormatter.format(_totalTax)),
            const SizedBox(height: 8),
            const Divider(thickness: 1, indent: 100),
            _buildTotalRow(
              'Grand Total',
              _currencyFormatter.format(_grandTotal),
              isGrandTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  /// A helper for a single item row in the preview
  Widget _buildPreviewItemRow(LineItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name.isEmpty ? 'Untitled Item' : item.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${item.quantity} x ${_currencyFormatter.format(item.rate)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            _currencyFormatter.format(item.total),
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
