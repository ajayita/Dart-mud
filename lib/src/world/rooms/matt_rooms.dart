import 'room.dart';
import 'room_registry.dart';

void registerMattRooms(RoomRegistry registry) {
  registry.register(
    'MattHome',
    () {
      final room = Room(
        id: 'MattHome',
        name: 'Simple Workshop',
        description: 'You find yourself standing in the midst of a simple '
            'workshop. Various tools line the walls to either side. A simple '
            'workbench sits off to the side, covered in a thick layer of '
            'sawdust.',
      );
      room.addExit('north', 'ZoneTest');
      return room;
    },
  );

  registry.register(
    'ZoneTest',
    () {
      final room = Room(
        id: 'ZoneTest',
        name: 'Maliche Square',
        description: 'The town square is a rather small area where many in '
            'the town congregate throughout the day. A small fountain, long '
            'since dried up, stands in the middle of the square. Many of the '
            'cobble stone bricks have worked loose leaving the ground rather '
            'uneven.',
      );
      room.addExit('portal', 'MattHome');
      return room;
    },
  );
}
