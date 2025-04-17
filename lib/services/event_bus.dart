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
  // Singleton pattern
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  
  EventBus._internal();
  
  // Stream controller for entity events
  final StreamController<EntityEvent> _entityController = StreamController<EntityEvent>.broadcast();
  
  // Get the stream
  Stream<EntityEvent> get entityStream => _entityController.stream;
  
  // Add an event to the stream
  void fireEntityEvent(EntityEvent event) {
    _entityController.add(event);
  }
  
  // Close the stream controller
  void dispose() {
    _entityController.close();
  }
} 