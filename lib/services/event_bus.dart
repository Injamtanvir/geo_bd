import 'dart:async';

class EntityEvent {
  final int entityId;
  final EventType type;

  EntityEvent(this.entityId, this.type);
}

enum EventType {
  deleted,
  updated,
  created
}

class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  
  EventBus._internal();

  final StreamController<EntityEvent> _entityController = StreamController<EntityEvent>.broadcast();

  Stream<EntityEvent> get entityStream => _entityController.stream;

  void fireEntityEvent(EntityEvent event){
    _entityController.add(event);
  }

  void dispose(){
    _entityController.close();
  }
} 