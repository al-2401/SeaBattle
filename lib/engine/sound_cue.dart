/// A one-off noise the simulation asks for.
///
/// The engine only names what happened; how it sounds — and whether anything
/// is audible at all — is the presentation layer's business.
enum SoundCue {
  /// Compressed air pushing a torpedo out of the tube.
  launch,

  /// A torpedo finding a ship.
  hit,

  /// A torpedo finding a mine instead.
  mine,

  /// A torpedo running out of fuel and going up harmlessly.
  splash,

  /// Tubes reloaded and ready.
  reload,

  /// The training gear hitting its stop.
  clunk,

  /// An escort's pattern going off around the boat: heard through the hull,
  /// so all the crack is gone and only the blow is left.
  depthCharge,

  /// A merchant sounding off somewhere out there.
  horn,

  /// The last torpedo has run: patrol over.
  gameOver;

  /// Path of the generated sample, relative to the asset bundle's `assets/`.
  String get asset => 'audio/$name.wav';
}

/// A continuous noise whose level follows the state of the boat.
enum SoundLoop {
  /// The training motor: louder and higher the faster the optics swing.
  motor,

  /// Propellers of every torpedo currently in the water.
  torpedo,

  /// Sea and hull, always there.
  sea,

  /// The howler: sounds for a while when a new threat is heard.
  alarm;

  String get asset => 'audio/$name.wav';
}
