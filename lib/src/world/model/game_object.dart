class GameObject {
  GameObject(this.name, [String? longDescription])
      : longDescription = (longDescription == null || longDescription.isEmpty)
            ? 'The devs were too lazy to provide a description'
            : longDescription;

  String name;
  String longDescription;

  String get short => name;
  set short(String value) {
    if (value.isNotEmpty) {
      name = value;
    }
  }

  String get long => longDescription;
  set long(String value) {
    if (value.isNotEmpty) {
      longDescription = value;
    }
  }

  String get description => '$name\n$longDescription';
}
