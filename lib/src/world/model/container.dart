import 'game_object.dart';

abstract interface class Container {
  GameObject? getObject(String name);
  bool hasObjectByName(String name);
  bool hasObject(GameObject obj);
  bool addObject(GameObject obj);
  bool removeObject(GameObject obj);
  GameObject? removeByName(String name);
}

class ContainerImpl extends GameObject implements Container {
  ContainerImpl(super.name, [super.longDescription]);

  final List<GameObject> _inventory = <GameObject>[];

  List<GameObject> get inventory => List<GameObject>.unmodifiable(_inventory);

  @override
  GameObject? getObject(String name) {
    for (final object in _inventory) {
      if (object.name == name) {
        return object;
      }
    }
    return null;
  }

  @override
  bool hasObjectByName(String name) => getObject(name) != null;

  @override
  bool hasObject(GameObject obj) => _inventory.contains(obj);

  @override
  bool addObject(GameObject obj) {
    if (hasObject(obj)) {
      return false;
    }

    _inventory.add(obj);
    return true;
  }

  @override
  bool removeObject(GameObject obj) => _inventory.remove(obj);

  @override
  GameObject? removeByName(String name) {
    final object = getObject(name);
    if (object != null) {
      _inventory.remove(object);
    }
    return object;
  }
}
