enum AppFlavor {
  doctor,
  patient;

  static AppFlavor _current = AppFlavor.doctor;

  static AppFlavor get current => _current;

  static void setFlavor(AppFlavor flavor) {
    _current = flavor;
  }

  bool get isDoctor => this == AppFlavor.doctor;
  bool get isPatient => this == AppFlavor.patient;

  List<String> get allowedRoles {
    switch (this) {
      case AppFlavor.doctor:
        return ['doctor', 'admin'];
      case AppFlavor.patient:
        return ['patient'];
    }
  }

  String get appName {
    switch (this) {
      case AppFlavor.doctor:
        return 'Doctor App';
      case AppFlavor.patient:
        return 'Patient App';
    }
  }
}
