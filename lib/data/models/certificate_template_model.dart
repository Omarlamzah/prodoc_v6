class CertificateTemplateModel {
  final int? id;
  final String? title;
  final String? content;
  final String? description;

  CertificateTemplateModel({
    this.id,
    this.title,
    this.content,
    this.description,
  });

  factory CertificateTemplateModel.fromJson(Map<String, dynamic> json) {
    return CertificateTemplateModel(
      id: json['id'] as int?,
      title: json['title'] as String?,
      content: json['content'] as String?,
      description: json['description'] as String?,
    );
  }
}
