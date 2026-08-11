// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resume.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PersonalInfo _$PersonalInfoFromJson(Map<String, dynamic> json) =>
    _PersonalInfo(
      fullName: json['fullName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      location: json['location'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      linkedin: json['linkedin'] as String? ?? '',
      website: json['website'] as String? ?? '',
      photo: const Uint8ListConverter().fromJson(json['photo'] as String?),
    );

Map<String, dynamic> _$PersonalInfoToJson(_PersonalInfo instance) =>
    <String, dynamic>{
      'fullName': instance.fullName,
      'title': instance.title,
      'email': instance.email,
      'phone': instance.phone,
      'location': instance.location,
      'summary': instance.summary,
      'linkedin': instance.linkedin,
      'website': instance.website,
      'photo': ?const Uint8ListConverter().toJson(instance.photo),
    };

_Experience _$ExperienceFromJson(Map<String, dynamic> json) => _Experience(
  id: json['id'] as String,
  company: json['company'] as String? ?? '',
  position: json['position'] as String? ?? '',
  startDate: json['startDate'] as String? ?? '',
  endDate: json['endDate'] as String? ?? '',
  current: json['current'] as bool? ?? false,
  description: json['description'] as String? ?? '',
);

Map<String, dynamic> _$ExperienceToJson(_Experience instance) =>
    <String, dynamic>{
      'id': instance.id,
      'company': instance.company,
      'position': instance.position,
      'startDate': instance.startDate,
      'endDate': instance.endDate,
      'current': instance.current,
      'description': instance.description,
    };

_Education _$EducationFromJson(Map<String, dynamic> json) => _Education(
  id: json['id'] as String,
  institution: json['institution'] as String? ?? '',
  degree: json['degree'] as String? ?? '',
  field: json['field'] as String? ?? '',
  startDate: json['startDate'] as String? ?? '',
  endDate: json['endDate'] as String? ?? '',
  gpa: json['gpa'] as String? ?? '',
);

Map<String, dynamic> _$EducationToJson(_Education instance) =>
    <String, dynamic>{
      'id': instance.id,
      'institution': instance.institution,
      'degree': instance.degree,
      'field': instance.field,
      'startDate': instance.startDate,
      'endDate': instance.endDate,
      'gpa': instance.gpa,
    };

_Skill _$SkillFromJson(Map<String, dynamic> json) => _Skill(
  id: json['id'] as String,
  name: json['name'] as String? ?? '',
  level: (json['level'] as num?)?.toInt() ?? 3,
);

Map<String, dynamic> _$SkillToJson(_Skill instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'level': instance.level,
};

_Project _$ProjectFromJson(Map<String, dynamic> json) => _Project(
  id: json['id'] as String,
  name: json['name'] as String? ?? '',
  description: json['description'] as String? ?? '',
  link: json['link'] as String? ?? '',
  technologies: json['technologies'] as String? ?? '',
);

Map<String, dynamic> _$ProjectToJson(_Project instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'link': instance.link,
  'technologies': instance.technologies,
};

_CustomItem _$CustomItemFromJson(Map<String, dynamic> json) => _CustomItem(
  id: json['id'] as String,
  title: json['title'] as String? ?? '',
  subtitle: json['subtitle'] as String? ?? '',
  description: json['description'] as String? ?? '',
);

Map<String, dynamic> _$CustomItemToJson(_CustomItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'subtitle': instance.subtitle,
      'description': instance.description,
    };

_CustomSection _$CustomSectionFromJson(Map<String, dynamic> json) =>
    _CustomSection(
      id: json['id'] as String,
      sectionTitle: json['sectionTitle'] as String? ?? '',
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => CustomItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <CustomItem>[],
    );

Map<String, dynamic> _$CustomSectionToJson(_CustomSection instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sectionTitle': instance.sectionTitle,
      'items': instance.items.map((e) => e.toJson()).toList(),
    };

_ResumeData _$ResumeDataFromJson(Map<String, dynamic> json) => _ResumeData(
  personalInfo: json['personalInfo'] == null
      ? const PersonalInfo()
      : PersonalInfo.fromJson(json['personalInfo'] as Map<String, dynamic>),
  experiences:
      (json['experiences'] as List<dynamic>?)
          ?.map((e) => Experience.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Experience>[],
  education:
      (json['education'] as List<dynamic>?)
          ?.map((e) => Education.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Education>[],
  skills:
      (json['skills'] as List<dynamic>?)
          ?.map((e) => Skill.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Skill>[],
  projects:
      (json['projects'] as List<dynamic>?)
          ?.map((e) => Project.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Project>[],
  customSections:
      (json['customSections'] as List<dynamic>?)
          ?.map((e) => CustomSection.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <CustomSection>[],
);

Map<String, dynamic> _$ResumeDataToJson(_ResumeData instance) =>
    <String, dynamic>{
      'personalInfo': instance.personalInfo.toJson(),
      'experiences': instance.experiences.map((e) => e.toJson()).toList(),
      'education': instance.education.map((e) => e.toJson()).toList(),
      'skills': instance.skills.map((e) => e.toJson()).toList(),
      'projects': instance.projects.map((e) => e.toJson()).toList(),
      'customSections': instance.customSections.map((e) => e.toJson()).toList(),
    };

_ResumeDocument _$ResumeDocumentFromJson(Map<String, dynamic> json) =>
    _ResumeDocument(
      id: json['id'] as String,
      templateId: json['templateId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      data: json['data'] == null
          ? const ResumeData()
          : ResumeData.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ResumeDocumentToJson(_ResumeDocument instance) =>
    <String, dynamic>{
      'id': instance.id,
      'templateId': instance.templateId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'data': instance.data.toJson(),
    };
