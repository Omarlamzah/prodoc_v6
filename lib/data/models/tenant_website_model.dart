// lib/data/models/tenant_website_model.dart
import 'dart:convert';

class TenantWebsiteModel {
  final int? id;
  final int? userId;
  final String? title;
  final String? description;
  final Map<String, dynamic>? contentBlocks;
  final String? logoPath;
  final String? faviconPath;
  final String? heroImagePath;
  final String? contactEmail;
  final String? contactPhone;
  final String? contactAddress;
  final String? contactFormRecipient;
  final String? workHours;
  final String? socialLinks;
  final String? seoTitle;
  final String? seoMetaDescription;
  final String? seoMetaKeywords;
  final String? seoImagePath;
  final String? themeColors;
  final String? fontFamily;
  final String? fontSize;
  final String? designSettings;
  final bool? isActive;
  final bool? maintenanceMode;
  final String? customCss;
  final String? customJs;
  final String? googleAnalyticsId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<dynamic>? pages;
  final Map<String, dynamic>? additionalData;
  final String? googleMapsLocation;
  final String? googleMapsReviewUrl;

  TenantWebsiteModel({
    this.id,
    this.userId,
    this.title,
    this.description,
    this.contentBlocks,
    this.logoPath,
    this.faviconPath,
    this.heroImagePath,
    this.contactEmail,
    this.contactPhone,
    this.contactAddress,
    this.contactFormRecipient,
    this.workHours,
    this.socialLinks,
    this.seoTitle,
    this.seoMetaDescription,
    this.seoMetaKeywords,
    this.seoImagePath,
    this.themeColors,
    this.fontFamily,
    this.fontSize,
    this.designSettings,
    this.isActive,
    this.maintenanceMode,
    this.customCss,
    this.customJs,
    this.googleAnalyticsId,
    this.createdAt,
    this.updatedAt,
    this.pages,
    this.additionalData,
    this.googleMapsLocation,
    this.googleMapsReviewUrl,
  });

  factory TenantWebsiteModel.fromJson(Map<String, dynamic> json) {
    // Parse content_blocks from JSON string if it's a string
    Map<String, dynamic>? parsedContentBlocks;
    if (json['content_blocks'] != null) {
      if (json['content_blocks'] is String) {
        try {
          parsedContentBlocks = jsonDecode(json['content_blocks'] as String)
              as Map<String, dynamic>?;
        } catch (e) {
          parsedContentBlocks = null;
        }
      } else if (json['content_blocks'] is Map) {
        parsedContentBlocks = json['content_blocks'] as Map<String, dynamic>?;
      }
    }

    return TenantWebsiteModel(
      id: json['id'] as int?,
      userId: json['user_id'] as int?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      contentBlocks: parsedContentBlocks,
      logoPath: json['logo_path'] as String?,
      faviconPath: json['favicon_path'] as String?,
      heroImagePath: json['hero_image_path'] as String?,
      contactEmail: json['contact_email'] as String?,
      contactPhone: json['contact_phone'] as String?,
      contactAddress: json['contact_address'] as String?,
      contactFormRecipient: json['contact_form_recipient'] as String?,
      workHours: json['work_hours'] is String
          ? json['work_hours'] as String
          : json['work_hours']?.toString(),
      socialLinks: json['social_links'] is String
          ? json['social_links'] as String
          : json['social_links']?.toString(),
      seoTitle: json['seo_title'] as String?,
      seoMetaDescription: json['seo_meta_description'] as String?,
      seoMetaKeywords: json['seo_meta_keywords'] is String
          ? json['seo_meta_keywords'] as String
          : json['seo_meta_keywords']?.toString(),
      seoImagePath: json['seo_image_path'] as String?,
      themeColors: json['theme_colors'] is String
          ? json['theme_colors'] as String
          : json['theme_colors']?.toString(),
      fontFamily: json['font_family'] as String?,
      fontSize: json['font_size'] as String?,
      designSettings: json['design_settings'] is String
          ? json['design_settings'] as String
          : json['design_settings']?.toString(),
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      maintenanceMode:
          json['maintenance_mode'] == 1 || json['maintenance_mode'] == true,
      customCss: json['custom_css'] as String?,
      customJs: json['custom_js'] as String?,
      googleAnalyticsId: json['google_analytics_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      pages: json['pages'] as List<dynamic>?,
      additionalData: json,
      googleMapsLocation: json['google_maps_location'] as String?,
      googleMapsReviewUrl: json['google_maps_review_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'content_blocks': contentBlocks,
      'logo_path': logoPath,
      'favicon_path': faviconPath,
      'hero_image_path': heroImagePath,
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
      'contact_address': contactAddress,
      'contact_form_recipient': contactFormRecipient,
      'work_hours': workHours,
      'social_links': socialLinks,
      'seo_title': seoTitle,
      'seo_meta_description': seoMetaDescription,
      'seo_meta_keywords': seoMetaKeywords,
      'seo_image_path': seoImagePath,
      'theme_colors': themeColors,
      'font_family': fontFamily,
      'font_size': fontSize,
      'design_settings': designSettings,
      'is_active': isActive == true ? 1 : 0,
      'maintenance_mode': maintenanceMode == true ? 1 : 0,
      'custom_css': customCss,
      'custom_js': customJs,
      'google_analytics_id': googleAnalyticsId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'pages': pages,
      'google_maps_location': googleMapsLocation,
      'google_maps_review_url': googleMapsReviewUrl,
      ...?additionalData,
    };
  }

  // Helper methods to parse JSON strings
  Map<String, dynamic>? get parsedWorkHours {
    if (workHours == null) return null;
    try {
      return jsonDecode(workHours!) as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic>? get parsedSocialLinks {
    if (socialLinks == null) return null;
    try {
      return jsonDecode(socialLinks!) as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic>? get parsedThemeColors {
    if (themeColors == null) return null;
    try {
      return jsonDecode(themeColors!) as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic>? get parsedDesignSettings {
    if (designSettings == null) return null;
    try {
      return jsonDecode(designSettings!) as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  List<String>? get parsedSeoMetaKeywords {
    if (seoMetaKeywords == null) return null;
    try {
      return List<String>.from(jsonDecode(seoMetaKeywords!) as List);
    } catch (e) {
      return null;
    }
  }
}
