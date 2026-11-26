class_name SimAudio
extends RefCounted

# Short authoritative cues, consumed once by the presentation. A bounded ring catches repeated attacks
# even when consecutive 20 Hz snapshots both show an active swing or the same projectile count.
const MAX_EVENTS: int = 96

static func emit(sim: GameSim, cue: String, at: Vector2, actor: int = 0) -> void:
	sim.audio_sequence += 1
	sim.audio_events.append([sim.audio_sequence, cue, at, actor])
	if sim.audio_events.size() > MAX_EVENTS:
		sim.audio_events.pop_front()
