// expense_capture.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

// Model for the main expense transaction (header)
class ExpenseTransaction {
  final int? id;
  final int? voucherNo;
  final int? procSupplierId;
  final int? documentNo;
  final int? sysPurchaseModeId;
  final DateTime? expenseDate;
  final String? paid;
  final String? remarks;
  final String? status;
  final int? sysPaymentModeId;
  final int? fnBankId;
  final int? fnImprestAccountId;
  final int? payorId;
  final String? chequeNo;

  ExpenseTransaction({
    this.id,
    this.voucherNo,
    this.procSupplierId,
    this.documentNo,
    this.sysPurchaseModeId,
    this.expenseDate,
    this.paid,
    this.remarks,
    this.status = 'active', // Default as per schema
    this.sysPaymentModeId,
    this.fnBankId,
    this.fnImprestAccountId,
    this.payorId,
    this.chequeNo,
  });

  factory ExpenseTransaction.fromJson(Map<String, dynamic> json) {
    return ExpenseTransaction(
      id: (json['id'] is num) ? json['id'].toInt() : null,
      voucherNo: (json['voucher_no'] is num) ? json['voucher_no'].toInt() : null,
      procSupplierId: (json['proc_supplier_id'] is num) ? json['proc_supplier_id'].toInt() : null,
      documentNo: (json['document_no'] is num) ? json['document_no'].toInt() : null,
      sysPurchaseModeId: (json['sys_purchase_mode_id'] is num) ? json['sys_purchase_mode_id'].toInt() : null,
      expenseDate: DateTime.tryParse(json['expense_date'] as String? ?? '')?.toLocal(),
      paid: json['paid'] as String?,
      remarks: json['remarks'] as String?,
      status: json['status'] as String? ?? 'active',
      sysPaymentModeId: (json['sys_payment_mode_id'] is num) ? json['sys_payment_mode_id'].toInt() : null,
      fnBankId: (json['fn_bank_id'] is num) ? json['fn_bank_id'].toInt() : null,
      fnImprestAccountId: (json['fn_imprest_account_id'] is num) ? json['fn_imprest_account_id'].toInt() : null,
      payorId: (json['payor_id'] is num) ? json['payor_id'].toInt() : null,
      chequeNo: json['cheque_no'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'voucher_no': voucherNo,
      'proc_supplier_id': procSupplierId,
      'document_no': documentNo,
      'sys_purchase_mode_id': sysPurchaseModeId,
      'expense_date': expenseDate?.toIso8601String().split('T')[0],
      'paid': paid,
      'remarks': remarks,
      'status': status,
      'sys_payment_mode_id': sysPaymentModeId,
      'fn_bank_id': fnBankId,
      'fn_imprest_account_id': fnImprestAccountId,
      'payor_id': payorId,
      'cheque_no': chequeNo,
    };
  }
}

// Model for expense transaction items (details)
class ExpenseTransactionItem {
  final int? id;
  final int? fnExpenseTransactionId;
  final String? transactionType;
  final int? transactionId;
  final String? receiverType;
  final int? receiverId;
  final int? emPaymentTermId;
  final double? quantity;
  final double? discount;
  final int? sysVatClassId;
  final String? tax;
  final double? amount;
  final double? total;
  final int? month;
  final int? year;
  final String? memo;

  ExpenseTransactionItem({
    this.id,
    this.fnExpenseTransactionId,
    this.transactionType,
    this.transactionId,
    this.receiverType,
    this.receiverId,
    this.emPaymentTermId,
    this.quantity,
    this.discount,
    this.sysVatClassId,
    this.tax,
    this.amount,
    this.total,
    this.month,
    this.year,
    this.memo,
  });

  factory ExpenseTransactionItem.fromJson(Map<String, dynamic> json) {
    return ExpenseTransactionItem(
      id: (json['id'] is num) ? json['id'].toInt() : null,
      fnExpenseTransactionId: (json['fn_expense_transaction_id'] is num) ? json['fn_expense_transaction_id'].toInt() : null,
      transactionType: json['transaction_type'] as String?,
      transactionId: (json['transaction_id'] is num) ? json['transaction_id'].toInt() : null,
      receiverType: json['receiver_type'] as String?,
      receiverId: (json['receiver_id'] is num) ? json['receiver_id'].toInt() : null,
      emPaymentTermId: (json['em_payment_term_id'] is num) ? json['em_payment_term_id'].toInt() : null,
      quantity: json['quantity'] != null
          ? (json['quantity'] is num
          ? (json['quantity'] as num).toDouble()
          : double.tryParse(json['quantity'].toString()) ?? 0.0)
          : null,
      discount: json['discount'] != null
          ? (json['discount'] is num
          ? (json['discount'] as num).toDouble()
          : double.tryParse(json['discount'].toString()) ?? 0.0)
          : null,
      sysVatClassId: (json['sys_vat_class_id'] is num) ? json['sys_vat_class_id'].toInt() : null,
      tax: json['tax'] as String?,
      amount: json['amount'] != null
          ? (json['amount'] is num
          ? (json['amount'] as num).toDouble()
          : double.tryParse(json['amount'].toString()) ?? 0.0)
          : null,
      total: json['total'] != null
          ? (json['total'] is num
          ? (json['total'] as num).toDouble()
          : double.tryParse(json['total'].toString()) ?? 0.0)
          : null,
      month: (json['month'] is num) ? json['month'].toInt() : null,
      year: (json['year'] is num) ? json['year'].toInt() : null,
      memo: json['memo'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fn_expense_transaction_id': fnExpenseTransactionId,
      'transaction_type': transactionType,
      'transaction_id': transactionId,
      'receiver_type': receiverType,
      'receiver_id': receiverId,
      'em_payment_term_id': emPaymentTermId,
      'quantity': quantity,
      'discount': discount,
      'sys_vat_class_id': sysVatClassId,
      'tax': tax,
      'amount': amount,
      'total': total,
      'month': month,
      'year': year,
      'memo': memo,
    };
  }
}

// Model for supplier (for filtering purposes)
class SupplierForFilter {
  final int id;
  final String name;

  SupplierForFilter({required this.id, required this.name});

  factory SupplierForFilter.fromJson(Map<String, dynamic> json) {
    return SupplierForFilter(
      id: (json['id'] is num) ? json['id'].toInt() : 0,
      name: json['name'] as String? ?? 'Unknown',
    );
  }
}

// Model for purchase mode (for filtering purposes)
class PurchaseMode {
  final int id;
  final String name;

  PurchaseMode({required this.id, required this.name});

  factory PurchaseMode.fromJson(Map<String, dynamic> json) {
    return PurchaseMode(
      id: (json['id'] is num) ? json['id'].toInt() : 0,
      name: json['name'] as String? ?? 'Unknown',
    );
  }
}

// Model for payment mode (for filtering purposes)
class PaymentMode {
  final int id;
  final String name;

  PaymentMode({required this.id, required this.name});

  factory PaymentMode.fromJson(Map<String, dynamic> json) {
    return PaymentMode(
      id: (json['id'] is num) ? json['id'].toInt() : 0,
      name: json['name'] as String? ?? 'Unknown',
    );
  }
}

// Model for bank (for filtering purposes)
class Bank {
  final int id;
  final String name;

  Bank({required this.id, required this.name});

  factory Bank.fromJson(Map<String, dynamic> json) {
    return Bank(
      id: (json['id'] is num) ? json['id'].toInt() : 0,
      name: json['name'] as String? ?? 'Unknown',
    );
  }
}

// Model for imprest account (for filtering purposes)
class ImprestAccount {
  final int id;
  final String name;

  ImprestAccount({required this.id, required this.name});

  factory ImprestAccount.fromJson(Map<String, dynamic> json) {
    return ImprestAccount(
      id: (json['id'] is num) ? json['id'].toInt() : 0,
      name: json['name'] as String? ?? 'Unknown',
    );
  }
}

// Model for payor (for filtering purposes)
class Payor {
  final int id;
  final String name;

  Payor({required this.id, required this.name});

  factory Payor.fromJson(Map<String, dynamic> json) {
    return Payor(
      id: (json['id'] is num) ? json['id'].toInt() : 0,
      name: json['name'] as String? ?? 'Unknown',
    );
  }
}

// Service class for capturing and submitting expense details to API
class ExpenseCaptureService {
  static const String _baseUrl = 'https://api.example.com'; // Replace with your actual API base URL
  static const String _endpoint = '/api/expenses'; // Assumed endpoint for creating expenses

  // Method to capture and submit expense (header + items)
  static Future<http.Response> submitExpense({
    required ExpenseTransaction transaction,
    required List<ExpenseTransactionItem> items,
  }) async {
    final url = Uri.parse('$_baseUrl$_endpoint');
    final requestBody = {
      'transaction': transaction.toJson(),
      'items': items.map((item) => item.toJson()).toList(),
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          // Add auth headers if needed, e.g., 'Authorization': 'Bearer $token'
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Expense submitted successfully: ${response.body}');
      } else {
        print('Failed to submit expense: ${response.statusCode} - ${response.body}');
      }

      return response;
    } catch (e) {
      print('Error submitting expense: $e');
      rethrow;
    }
  }

  // Example usage method (for testing or integration)
  static Future<void> createSampleExpense() async {
    final transaction = ExpenseTransaction(
      voucherNo: 12345,
      procSupplierId: 1,
      documentNo: 67890,
      sysPurchaseModeId: 2,
      expenseDate: DateTime.now(),
      paid: 'Yes',
      remarks: 'Sample expense remarks',
      status: 'active',
      sysPaymentModeId: 3,
      fnBankId: 4,
      fnImprestAccountId: 5,
      payorId: 6,
      chequeNo: 'CHK-001',
    );

    final items = [
      ExpenseTransactionItem(
        transactionType: 'Purchase',
        transactionId: 10,
        receiverType: 'Supplier',
        receiverId: 1,
        emPaymentTermId: 1,
        quantity: 2.0,
        discount: 5.0,
        sysVatClassId: 1,
        tax: 'inc',
        amount: 100.0,
        total: 105.0,
        month: DateTime.now().month,
        year: DateTime.now().year,
        memo: 'Item memo 1',
      ),
    ];

    await submitExpense(transaction: transaction, items: items);
  }
}