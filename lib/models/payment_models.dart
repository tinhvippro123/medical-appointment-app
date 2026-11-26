import 'order.dart';

class VnPaySession {
  final int orderId;
  final double amount;
  final String txnRef;
  final String paymentUrl;
  final String callbackSuccessUrl;
  final String callbackCancelUrl;

  const VnPaySession({
    required this.orderId,
    required this.amount,
    required this.txnRef,
    required this.paymentUrl,
    required this.callbackSuccessUrl,
    required this.callbackCancelUrl,
  });

  String get amountFormatted => Order.formatMoney(amount);

  factory VnPaySession.fromJson(Map<String, dynamic> json) => VnPaySession(
    orderId: Order.parseInt(json['orderId']),
    amount: Order.parseDouble(json['amount']),
    txnRef: Order.parseString(json['txnRef']),
    paymentUrl: Order.parseString(json['paymentUrl']),
    callbackSuccessUrl: Order.parseString(json['callbackSuccessUrl']),
    callbackCancelUrl: Order.parseString(json['callbackCancelUrl']),
  );
}

class VietQrSession {
  final int orderId;
  final double amount;
  final String txnRef;
  final String bankId;
  final String bankName;
  final String accountNo;
  final String accountName;
  final String transferContent;
  final String qrData;
  final String vietQrImageUrl;

  const VietQrSession({
    required this.orderId,
    required this.amount,
    required this.txnRef,
    required this.bankId,
    required this.bankName,
    required this.accountNo,
    required this.accountName,
    required this.transferContent,
    required this.qrData,
    required this.vietQrImageUrl,
  });

  String get amountFormatted => Order.formatMoney(amount);

  factory VietQrSession.fromJson(Map<String, dynamic> json) => VietQrSession(
    orderId: Order.parseInt(json['orderId']),
    amount: Order.parseDouble(json['amount']),
    txnRef: Order.parseString(json['txnRef']),
    bankId: Order.parseString(json['bankId']),
    bankName: Order.parseString(json['bankName']),
    accountNo: Order.parseString(json['accountNo']),
    accountName: Order.parseString(json['accountName']),
    transferContent: Order.parseString(json['transferContent']),
    qrData: Order.parseString(json['qrData']),
    vietQrImageUrl: Order.parseString(json['vietQrImageUrl']),
  );
}

class PaymentResult {
  final bool success;
  final int orderId;
  final String paymentMethod;
  final String paymentStatus;
  final String? transactionId;
  final String responseCode;
  final String message;

  const PaymentResult({
    required this.success,
    required this.orderId,
    required this.paymentMethod,
    required this.paymentStatus,
    this.transactionId,
    required this.responseCode,
    required this.message,
  });

  factory PaymentResult.fromJson(Map<String, dynamic> json) => PaymentResult(
    success: json['success'] == true,
    orderId: Order.parseInt(json['orderId']),
    paymentMethod: Order.parseString(json['paymentMethod']),
    paymentStatus: Order.parseString(json['paymentStatus']),
    transactionId: Order.parseNullableString(json['transactionId']),
    responseCode: Order.parseString(json['responseCode']),
    message: Order.parseString(json['message']),
  );
}
