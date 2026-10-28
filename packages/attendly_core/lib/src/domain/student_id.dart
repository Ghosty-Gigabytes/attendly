import 'dart:convert';
import 'dart:typed_data';

class StudentIdData {
  final String name,
      rollNumber,
      course,
      parentName,
      branch,
      mobile,
      address,
      dob,
      issueDate,
      bloodGroup,
      email;
  final Uint8List? photo, signature, logo;
  final DateTime fetchedAt;
  const StudentIdData({
    required this.name,
    required this.rollNumber,
    required this.course,
    required this.parentName,
    required this.branch,
    required this.mobile,
    required this.address,
    required this.dob,
    required this.issueDate,
    required this.bloodGroup,
    required this.email,
    required this.fetchedAt,
    this.photo,
    this.signature,
    this.logo,
  });
  String get admissionYear =>
      RegExp(r'^(20\d{2})').firstMatch(rollNumber)?.group(1) ?? '';
  int? get durationYears =>
      switch (course.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')) {
        'btech' => 4,
        'mtech' => 2,
        _ => null,
      };
  String get batch => admissionYear.isEmpty || durationYears == null
      ? ''
      : '$admissionYear–${int.parse(admissionYear) + durationYears!}';
  StudentIdData withImages({
    Uint8List? photo,
    Uint8List? signature,
    Uint8List? logo,
  }) => StudentIdData(
    name: name,
    rollNumber: rollNumber,
    course: course,
    parentName: parentName,
    branch: branch,
    mobile: mobile,
    address: address,
    dob: dob,
    issueDate: issueDate,
    bloodGroup: bloodGroup,
    email: email,
    fetchedAt: fetchedAt,
    photo: photo,
    signature: signature,
    logo: logo,
  );
  Map<String, dynamic> toJson() => {
    'name': name,
    'rollNumber': rollNumber,
    'course': course,
    'parentName': parentName,
    'branch': branch,
    'mobile': mobile,
    'address': address,
    'dob': dob,
    'issueDate': issueDate,
    'bloodGroup': bloodGroup,
    'email': email,
    'fetchedAt': fetchedAt.toIso8601String(),
    'photo': photo == null ? null : base64Encode(photo!),
    'signature': signature == null ? null : base64Encode(signature!),
    'logo': logo == null ? null : base64Encode(logo!),
  };
  factory StudentIdData.fromJson(Map<String, dynamic> j) => StudentIdData(
    name: j['name'],
    rollNumber: j['rollNumber'],
    course: j['course'],
    parentName: j['parentName'],
    branch: j['branch'],
    mobile: j['mobile'],
    address: j['address'],
    dob: j['dob'],
    issueDate: j['issueDate'],
    bloodGroup: j['bloodGroup'],
    email: j['email'],
    fetchedAt: DateTime.parse(j['fetchedAt']),
    photo: j['photo'] == null ? null : base64Decode(j['photo']),
    signature: j['signature'] == null ? null : base64Decode(j['signature']),
    logo: j['logo'] == null ? null : base64Decode(j['logo']),
  );
}
