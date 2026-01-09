/// Metadata returned on successful link
class LinkSuccessMetadata {
  final LinkInstitution institution;
  final List<LinkAccount> accounts;
  final String linkSessionId;
  
  LinkSuccessMetadata({
    required this.institution,
    required this.accounts,
    required this.linkSessionId,
  });
  
  factory LinkSuccessMetadata.fromJson(Map<String, dynamic> json) {
    return LinkSuccessMetadata(
      institution: LinkInstitution.fromJson(Map<String, dynamic>.from(json['institution'] ?? {})),
      accounts: (json['accounts'] as List? ?? [])
          .map((a) => LinkAccount.fromJson(Map<String, dynamic>.from(a)))
          .toList(),
      linkSessionId: json['link_session_id'] ?? '',
    );
  }
}

/// Institution information
class LinkInstitution {
  final String id;
  final String name;
  
  LinkInstitution({required this.id, required this.name});
  
  factory LinkInstitution.fromJson(Map<String, dynamic> json) {
    return LinkInstitution(
      id: json['institution_id'] ?? '',
      name: json['name'] ?? '',
    );
  }
}

/// Account information
class LinkAccount {
  final String id;
  final String name;
  final String? mask;
  final String type;
  final String subtype;
  
  LinkAccount({
    required this.id,
    required this.name,
    this.mask,
    required this.type,
    required this.subtype,
  });
  
  factory LinkAccount.fromJson(Map<String, dynamic> json) {
    return LinkAccount(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      mask: json['mask'],
      type: json['type'] ?? '',
      subtype: json['subtype'] ?? '',
    );
  }
}

/// Error information
class LinkError {
  final String errorCode;
  final String errorMessage;
  final String errorType;
  final String displayMessage;
  
  LinkError({
    required this.errorCode,
    required this.errorMessage,
    required this.errorType,
    required this.displayMessage,
  });
  
  factory LinkError.fromJson(Map<String, dynamic> json) {
    return LinkError(
      errorCode: json['error_code'] ?? '',
      errorMessage: json['error_message'] ?? '',
      errorType: json['error_type'] ?? '',
      displayMessage: json['display_message'] ?? '',
    );
  }
}

/// Exit metadata
class LinkExitMetadata {
  final String? institutionId;
  final String? institutionName;
  final String? linkSessionId;
  final String status;
  
  LinkExitMetadata({
    this.institutionId,
    this.institutionName,
    this.linkSessionId,
    required this.status,
  });
  
  factory LinkExitMetadata.fromJson(Map<String, dynamic> json) {
    return LinkExitMetadata(
      institutionId: json['institution_id'],
      institutionName: json['institution_name'],
      linkSessionId: json['link_session_id'],
      status: json['status'] ?? 'unknown',
    );
  }
}

/// Event metadata
class LinkEventMetadata {
  final String? errorCode;
  final String? errorMessage;
  final String? exitStatus;
  final String? institutionId;
  final String? institutionName;
  final String? linkSessionId;
  final String? mfaType;
  final String? viewName;
  
  LinkEventMetadata({
    this.errorCode,
    this.errorMessage,
    this.exitStatus,
    this.institutionId,
    this.institutionName,
    this.linkSessionId,
    this.mfaType,
    this.viewName,
  });
  
  factory LinkEventMetadata.fromJson(Map<String, dynamic> json) {
    return LinkEventMetadata(
      errorCode: json['error_code'],
      errorMessage: json['error_message'],
      exitStatus: json['exit_status'],
      institutionId: json['institution_id'],
      institutionName: json['institution_name'],
      linkSessionId: json['link_session_id'],
      mfaType: json['mfa_type'],
      viewName: json['view_name'],
    );
  }
}
