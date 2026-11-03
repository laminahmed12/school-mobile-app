const String studentCreateIdempotentRpc = 'create_student_with_fee_idempotent';

const String studentCreationRpcUnavailableMessage =
    'خدمة مزامنة إنشاء الطلاب غير موجودة على خادم المدرسة الحالي. احتُفظ بالعملية محليًا؛ يلزم نشر ترحيل قاعدة البيانات المعتمد قبل مزامنتها.';

Map<String, dynamic> buildStudentCreationRpcParams({
  required String operationId,
  required String name,
  required String className,
  required String phone,
  required num termFee,
  required String term,
}) => {
  'p_operation_id': operationId,
  'p_name': name.trim(),
  'p_class_name': className.trim(),
  'p_phone': phone.trim(),
  'p_term_fee': termFee,
  'p_term': term,
};

bool isMissingStudentCreationRpc(Object error) {
  final message = error.toString().toLowerCase();
  if (!message.contains(studentCreateIdempotentRpc)) return false;

  final missingCode = RegExp(r'\\b(?:pgrst202|42883)\\b').hasMatch(message);
  final missingDescription =
      message.contains('could not find the function') ||
      message.contains('function does not exist') ||
      message.contains('schema cache');

  return missingCode || missingDescription;
}
