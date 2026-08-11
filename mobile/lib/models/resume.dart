import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

import 'converters.dart';

part 'resume.freezed.dart';
part 'resume.g.dart';

/// Contact block and headline shown at the top of every template.
@freezed
abstract class PersonalInfo with _$PersonalInfo {
  const factory PersonalInfo({
    @Default('') String fullName,
    @Default('') String title,
    @Default('') String email,
    @Default('') String phone,
    @Default('') String location,
    @Default('') String summary,
    @Default('') String linkedin,
    @Default('') String website,
    @Uint8ListConverter() Uint8List? photo,
  }) = _PersonalInfo;

  factory PersonalInfo.fromJson(Map<String, dynamic> json) =>
      _$PersonalInfoFromJson(json);
}

/// Dates are stored as free-form `YYYY-MM` strings rather than [DateTime].
///
/// Resume dates are month-granular, frequently partial ("2019"), and sometimes
/// deliberately vague. Forcing them through [DateTime] would invent a precision
/// the user never supplied.
@freezed
abstract class Experience with _$Experience {
  const factory Experience({
    required String id,
    @Default('') String company,
    @Default('') String position,
    @Default('') String startDate,
    @Default('') String endDate,
    @Default(false) bool current,
    @Default('') String description,
  }) = _Experience;

  factory Experience.fromJson(Map<String, dynamic> json) =>
      _$ExperienceFromJson(json);
}

@freezed
abstract class Education with _$Education {
  const factory Education({
    required String id,
    @Default('') String institution,
    @Default('') String degree,
    @Default('') String field,
    @Default('') String startDate,
    @Default('') String endDate,
    @Default('') String gpa,
  }) = _Education;

  factory Education.fromJson(Map<String, dynamic> json) =>
      _$EducationFromJson(json);
}

/// [level] is 0..5. Templates render it as bars, dots, or drop it entirely —
/// the value is presentation-independent.
@freezed
abstract class Skill with _$Skill {
  const factory Skill({
    required String id,
    @Default('') String name,
    @Default(3) int level,
  }) = _Skill;

  factory Skill.fromJson(Map<String, dynamic> json) => _$SkillFromJson(json);
}

@freezed
abstract class Project with _$Project {
  const factory Project({
    required String id,
    @Default('') String name,
    @Default('') String description,
    @Default('') String link,
    @Default('') String technologies,
  }) = _Project;

  factory Project.fromJson(Map<String, dynamic> json) =>
      _$ProjectFromJson(json);
}

@freezed
abstract class CustomItem with _$CustomItem {
  const factory CustomItem({
    required String id,
    @Default('') String title,
    @Default('') String subtitle,
    @Default('') String description,
  }) = _CustomItem;

  factory CustomItem.fromJson(Map<String, dynamic> json) =>
      _$CustomItemFromJson(json);
}

/// Escape hatch for anything the fixed schema does not model — certifications,
/// publications, languages, volunteering.
@freezed
abstract class CustomSection with _$CustomSection {
  const factory CustomSection({
    required String id,
    @Default('') String sectionTitle,
    @Default(<CustomItem>[]) List<CustomItem> items,
  }) = _CustomSection;

  factory CustomSection.fromJson(Map<String, dynamic> json) =>
      _$CustomSectionFromJson(json);
}

/// The complete user-entered content of one resume.
///
/// Deliberately free of any presentation concern: no colours, fonts, or layout.
/// That separation is what lets a template be swapped without touching content,
/// which is the product's core promise.
@freezed
abstract class ResumeData with _$ResumeData {
  const factory ResumeData({
    @Default(PersonalInfo()) PersonalInfo personalInfo,
    @Default(<Experience>[]) List<Experience> experiences,
    @Default(<Education>[]) List<Education> education,
    @Default(<Skill>[]) List<Skill> skills,
    @Default(<Project>[]) List<Project> projects,
    @Default(<CustomSection>[]) List<CustomSection> customSections,
  }) = _ResumeData;

  const ResumeData._();

  factory ResumeData.fromJson(Map<String, dynamic> json) =>
      _$ResumeDataFromJson(json);

  /// True when the user has not entered anything worth rendering yet — drives
  /// the editor's empty state and the "untitled" fallback in the resume list.
  bool get isEmpty =>
      personalInfo.fullName.trim().isEmpty &&
      personalInfo.title.trim().isEmpty &&
      personalInfo.summary.trim().isEmpty &&
      experiences.isEmpty &&
      education.isEmpty &&
      skills.isEmpty &&
      projects.isEmpty &&
      customSections.isEmpty;
}

/// A stored resume: content plus the metadata the list screen needs to show it
/// without deserializing every document.
@freezed
abstract class ResumeDocument with _$ResumeDocument {
  const factory ResumeDocument({
    required String id,
    required String templateId,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(ResumeData()) ResumeData data,
  }) = _ResumeDocument;

  const ResumeDocument._();

  factory ResumeDocument.fromJson(Map<String, dynamic> json) =>
      _$ResumeDocumentFromJson(json);

  /// Label for the resume list. Falls back through name, then job title, then a
  /// placeholder, so a half-filled resume never renders as a blank row.
  String get displayTitle {
    final name = data.personalInfo.fullName.trim();
    if (name.isNotEmpty) return name;
    final title = data.personalInfo.title.trim();
    if (title.isNotEmpty) return title;
    return 'Untitled resume';
  }
}
