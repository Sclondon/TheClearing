class_name Voice
extends Node
## Talking to the others in a room, heard as if they were where they stand in
## the maze: loud close by, fading out by FAR metres, from the side they are on,
## and muffled with a wall between. The microphone is off until it is turned on
## (MIC in the HUD, or V), and stays as it was set from one maze to the next.
##
## The sound goes straight between the players' browsers (WebRTC, one connection
## for each other player: four at most), not through the server. What the
## browsers say to each other to make those connections (offers, answers, ways
## through) goes through the room, as packets of K_VOICE: a guest can only talk
## to the host, so the host passes each one on to the seat it is for. Each
## voice is played through the browser's Web Audio: a panner placed where that
## player is, heard from where this player is, facing the way the camera faces.
##
## Only the web build has it: elsewhere (the editor, tests) it does nothing.

const K_VOICE := 86  # V
## Heard in full this close, metres, and not at all this far.
const NEAR := 4.0
const FAR := 30.0
## How high their mouths are over their feet.
const MOUTH := 1.4
## How often a wall between is looked for, seconds.
const WALLS_EVERY := 0.25

signal changed

## The world being played (main.gd sets it each round), for where everyone is.
var world: World
## "off", "asking", "on", "denied" (the browser said no) or "none" (no microphone here).
var state := "off"
## How loud each other seat is talking now, 0..1, and this player.
var levels := {}
var mic_level := 0.0

var _js: JavaScriptObject
var _running := false
var _walls_in := 0.0
var _muffled := {}
var _bubbles := {}


## Whether this build can talk at all.
func available() -> bool:
	return _js != null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(_browser_half(), true)
	_js = JavaScriptBridge.get_interface("clearingVoice")
	if _js == null:
		return
	Net.started.connect(_on_started)
	Net.packet.connect(_on_packet)
	Net.left.connect(_on_left)
	Net.back.connect(_on_back)
	Net.closed.connect(func(_reason: String) -> void: _stop())


## Turns the microphone on (the first time, the browser asks) or off.
func toggle_mic() -> void:
	if _js == null:
		return
	_js.setMic(state != "on" and state != "asking")


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_V and _running:
		toggle_mic()
		get_viewport().set_input_as_handled()


func _on_started(players: Array) -> void:
	_stop()
	_running = true
	_js.start(Net.slot)
	for entry: Dictionary in players:
		var seat := int(entry["slot"])
		if seat != Net.slot:
			_js.link(seat)


## Back after a drop: the sound may have carried on between the browsers, but in
## case it didn't, the one of the two who offers makes the connection afresh.
func _on_back(seat: int) -> void:
	if _running and Net.slot < seat:
		_js.drop(seat)
		_js.link(seat)


func _on_left(seat: int) -> void:
	if _running:
		_js.drop(seat)
		levels.erase(seat)


func _stop() -> void:
	if _running:
		_js.stop()
		# (out of the room, nobody is listening: the microphone goes off)
		_js.setMic(false)
	_running = false
	levels.clear()
	for bubble: Node in _bubbles.values():
		if is_instance_valid(bubble):
			bubble.queue_free()
	_bubbles.clear()


func _on_packet(from: int, kind: int, data: PackedByteArray) -> void:
	if kind != K_VOICE:
		return
	var message: Variant = JSON.parse_string(data.get_string_from_utf8())
	if not (message is Dictionary):
		return
	if Net.is_host and from != Net.slot:
		# (a guest speaks only for itself; what isn't for the host goes on to its seat)
		message["from"] = from
		var to := int(message.get("to", -1))
		if to != Net.slot:
			Net.send(to, K_VOICE, JSON.stringify(message).to_utf8_buffer())
			return
	if int(message.get("to", -1)) == Net.slot and _running:
		_js.receive(JSON.stringify(message))


func _process(delta: float) -> void:
	if _js == null:
		return
	if _running and not Net.active():
		_stop()
	var news: Variant = JSON.parse_string(str(_js.poll()))
	if not (news is Dictionary):
		return
	# What this browser has to say to the others' (see the class note on the way it goes).
	for said: String in news.get("out", []):
		var message: Variant = JSON.parse_string(said)
		if message is Dictionary:
			Net.send(int(message["to"]), K_VOICE, said.to_utf8_buffer())
	var was := state
	state = str(news.get("state", "off"))
	mic_level = float(news.get("mic", 0.0))
	levels.clear()
	var heard: Dictionary = news.get("levels", {})
	for seat: String in heard:
		levels[int(seat)] = float(heard[seat])
	if state != was:
		changed.emit()
	if _running:
		_place(delta)


## Puts this player's ears and the others' voices where they are in the maze.
func _place(delta: float) -> void:
	if world == null or not is_instance_valid(world) or world.player == null or world.camera == null:
		return
	var ear := world.player.global_position + Vector3.UP * MOUTH
	var facing := world.camera.global_basis
	_walls_in -= delta
	var look_for_walls := _walls_in <= 0.0
	if look_for_walls:
		_walls_in = WALLS_EVERY
	var voices := {}
	for seat: int in world.remotes:
		var other: RemotePlayer = world.remotes[seat]
		if not is_instance_valid(other):
			continue
		var mouth := other.global_position + Vector3.UP * MOUTH
		if look_for_walls:
			_muffled[seat] = _wall_between(ear, mouth)
		voices[str(seat)] = [mouth.x, mouth.y, mouth.z, 1 if _muffled.get(seat, false) else 0]
		_bubble(seat, other)
	var forward := -facing.z
	var up := facing.y
	_js.place(JSON.stringify({"ear": [ear.x, ear.y, ear.z, forward.x, forward.y, forward.z, up.x, up.y, up.z], "voices": voices}))


func _wall_between(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## A few dots over the head of someone talking, swelling as they talk louder.
func _bubble(seat: int, other: RemotePlayer) -> void:
	var bubble: Label3D = _bubbles.get(seat)
	if bubble == null or not is_instance_valid(bubble) or bubble.get_parent() != other:
		bubble = Label3D.new()
		bubble.text = "• • •"
		bubble.font_size = 48
		bubble.pixel_size = 0.0025
		bubble.outline_size = 6
		bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		bubble.no_depth_test = true
		bubble.modulate = Color(0.93, 0.9, 0.8)
		bubble.position = Vector3.UP * 1.75
		other.add_child(bubble)
		_bubbles[seat] = bubble
	var loud: float = levels.get(seat, 0.0)
	bubble.visible = loud > 0.04
	bubble.scale = Vector3.ONE * (0.8 + minf(loud * 2.0, 0.4))


## The browser's half: microphone, connections and the sound of each voice in
## place. Called from above through JavaScriptBridge; what it has to send waits
## in an outbox that `poll` empties, with the state and how loud everyone is.
static func _browser_half() -> String:
	return """
(function () {
	if (window.clearingVoice) return;
	const NEAR = %NEAR%, FAR = %FAR%;
	const ICE = [{ urls: 'stun:stun.l.google.com:19302' }, { urls: 'stun:stun1.l.google.com:19302' }];
	const v = { me: -1, peers: {}, outbox: [], mic: null, micLevel: null, state: 'off', ctx: null };
	const supported = !!(window.RTCPeerConnection && navigator.mediaDevices && navigator.mediaDevices.getUserMedia);
	if (!supported) v.state = 'none';

	function audio() {
		if (!v.ctx) {
			const Context = window.AudioContext || window.webkitAudioContext;
			v.ctx = new Context();
		}
		if (v.ctx.state === 'suspended') v.ctx.resume().catch(function () {});
		return v.ctx;
	}
	// (browsers only let sound start after a touch or a key)
	['pointerdown', 'touchend', 'keydown'].forEach(function (name) {
		document.addEventListener(name, function () {
			if (v.ctx && v.ctx.state === 'suspended') v.ctx.resume().catch(function () {});
		}, true);
	});

	function send(to, message) {
		message.to = to;
		message.from = v.me;
		v.outbox.push(JSON.stringify(message));
	}

	function micTrack() {
		return v.mic ? v.mic.getAudioTracks()[0] : null;
	}

	// One connection to a seat. The lower seat offers; the other answers.
	function peer(seat, offering) {
		const pc = new RTCPeerConnection({ iceServers: ICE });
		const p = { pc: pc, seat: seat, sender: null, nodes: null, waiting: [] };
		v.peers[seat] = p;
		if (offering) {
			p.sender = pc.addTransceiver('audio', { direction: 'sendrecv' }).sender;
			p.sender.replaceTrack(micTrack()).catch(function () {});
		}
		pc.onicecandidate = function (e) {
			if (e.candidate) send(seat, { ice: e.candidate.toJSON() });
		};
		pc.ontrack = function (e) {
			hear(p, e.streams && e.streams[0] ? e.streams[0] : new MediaStream([e.track]));
		};
		pc.onconnectionstatechange = function () {
			// (lost: the one who offered tries again, by a fresh way through)
			if (pc.connectionState === 'failed' && offering && v.peers[seat] === p) offer(p, true);
		};
		return p;
	}

	function offer(p, restart) {
		p.pc.createOffer(restart ? { iceRestart: true } : {}).then(function (d) {
			return p.pc.setLocalDescription(d);
		}).then(function () {
			send(p.seat, { sdp: p.pc.localDescription.toJSON() });
		}).catch(function (e) { console.warn('voice offer', e); });
	}

	// A voice: played through a panner where they stand, and listened to for how loud it is.
	function hear(p, stream) {
		if (p.nodes) return;
		const ctx = audio();
		// (Chrome plays a far-away stream through Web Audio only if an element holds it too)
		const holder = new Audio();
		holder.srcObject = stream;
		holder.muted = true;
		holder.play().catch(function () {});
		const source = ctx.createMediaStreamSource(stream);
		const muffle = ctx.createBiquadFilter();
		muffle.type = 'lowpass';
		muffle.frequency.value = 20000;
		const panner = ctx.createPanner();
		panner.panningModel = 'HRTF';
		panner.distanceModel = 'linear';
		panner.refDistance = NEAR;
		panner.maxDistance = FAR;
		panner.rolloffFactor = 1;
		const meter = ctx.createAnalyser();
		meter.fftSize = 256;
		source.connect(meter);
		source.connect(muffle);
		muffle.connect(panner);
		panner.connect(ctx.destination);
		p.nodes = { holder: holder, source: source, muffle: muffle, panner: panner, meter: meter };
	}

	function loudness(meter) {
		const data = new Uint8Array(meter.fftSize);
		meter.getByteTimeDomainData(data);
		let sum = 0;
		for (let i = 0; i < data.length; i++) {
			const s = (data[i] - 128) / 128;
			sum += s * s;
		}
		return Math.sqrt(sum / data.length);
	}

	function drop(seat) {
		const p = v.peers[seat];
		if (!p) return;
		delete v.peers[seat];
		try { p.pc.close(); } catch (e) {}
		if (p.nodes) {
			p.nodes.panner.disconnect();
			p.nodes.source.disconnect();
			p.nodes.holder.srcObject = null;
		}
	}

	function at(param, value, now) {
		if (param.setTargetAtTime) param.setTargetAtTime(value, now, 0.05);
		else param.value = value;
	}

	window.clearingVoice = {
		start: function (me) {
			v.me = me;
		},
		link: function (seat) {
			if (!supported || v.peers[seat]) return;
			if (v.me < seat) offer(peer(seat, true), false);
		},
		receive: function (text) {
			if (!supported) return;
			const m = JSON.parse(text);
			if (v.me < 0) v.me = m.to;
			const seat = m.from;
			let p = v.peers[seat];
			if (m.sdp && m.sdp.type === 'offer') {
				// (a new offer is a new connection: they came back, or are trying again)
				if (p && p.pc.remoteDescription) drop(seat);
				p = v.peers[seat] || peer(seat, false);
				p.pc.setRemoteDescription(m.sdp).then(function () {
					const way = p.pc.getTransceivers()[0];
					way.direction = 'sendrecv';
					p.sender = way.sender;
					p.sender.replaceTrack(micTrack()).catch(function () {});
					p.waiting.forEach(function (c) { p.pc.addIceCandidate(c).catch(function () {}); });
					p.waiting = [];
					return p.pc.createAnswer();
				}).then(function (d) {
					return p.pc.setLocalDescription(d);
				}).then(function () {
					send(seat, { sdp: p.pc.localDescription.toJSON() });
				}).catch(function (e) { console.warn('voice answer', e); });
			} else if (m.sdp && p) {
				p.pc.setRemoteDescription(m.sdp).then(function () {
					p.waiting.forEach(function (c) { p.pc.addIceCandidate(c).catch(function () {}); });
					p.waiting = [];
				}).catch(function (e) { console.warn('voice answer taken', e); });
			} else if (m.ice) {
				if (!p) p = peer(seat, false);
				if (p.pc.remoteDescription) p.pc.addIceCandidate(m.ice).catch(function () {});
				else p.waiting.push(m.ice);
			}
		},
		drop: drop,
		stop: function () {
			Object.keys(v.peers).forEach(function (seat) { drop(seat); });
			v.me = -1;
			v.outbox = [];
		},
		setMic: function (on) {
			if (!supported) return;
			if (!on) {
				if (v.mic) v.mic.getTracks().forEach(function (t) { t.stop(); });
				v.mic = null;
				v.micLevel = null;
				v.state = 'off';
				Object.values(v.peers).forEach(function (p) {
					if (p.sender) p.sender.replaceTrack(null).catch(function () {});
				});
				return;
			}
			v.state = 'asking';
			audio();
			navigator.mediaDevices.getUserMedia({ audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true } }).then(function (stream) {
				v.mic = stream;
				v.state = 'on';
				const meter = audio().createAnalyser();
				meter.fftSize = 256;
				audio().createMediaStreamSource(stream).connect(meter);
				v.micLevel = meter;
				Object.values(v.peers).forEach(function (p) {
					if (p.sender) p.sender.replaceTrack(micTrack()).catch(function () {});
				});
			}).catch(function (e) {
				v.state = e && e.name === 'NotFoundError' ? 'none' : 'denied';
			});
		},
		place: function (text) {
			if (!v.ctx) return;
			const w = JSON.parse(text);
			const l = v.ctx.listener, e = w.ear, now = v.ctx.currentTime;
			if (l.positionX) {
				at(l.positionX, e[0], now); at(l.positionY, e[1], now); at(l.positionZ, e[2], now);
				at(l.forwardX, e[3], now); at(l.forwardY, e[4], now); at(l.forwardZ, e[5], now);
				at(l.upX, e[6], now); at(l.upY, e[7], now); at(l.upZ, e[8], now);
			} else {
				l.setPosition(e[0], e[1], e[2]);
				l.setOrientation(e[3], e[4], e[5], e[6], e[7], e[8]);
			}
			Object.keys(w.voices).forEach(function (seat) {
				const p = v.peers[seat];
				if (!p || !p.nodes) return;
				const o = w.voices[seat], n = p.nodes;
				if (n.panner.positionX) {
					at(n.panner.positionX, o[0], now); at(n.panner.positionY, o[1], now); at(n.panner.positionZ, o[2], now);
				} else {
					n.panner.setPosition(o[0], o[1], o[2]);
				}
				at(n.muffle.frequency, o[3] ? 900 : 20000, now);
			});
		},
		// (for looking at from the browser's console: where everything is heard)
		debug: function () {
			const l = v.ctx && v.ctx.listener;
			const out = { me: v.me, audio: v.ctx ? v.ctx.state : none, state: v.state, ear: l && l.positionX ? [l.positionX.value, l.positionY.value, l.positionZ.value] : null, voices: {} };
			Object.keys(v.peers).forEach(function (seat) {
				const p = v.peers[seat], n = p.nodes;
				out.voices[seat] = { link: p.pc.connectionState, at: n && n.panner.positionX ? [n.panner.positionX.value, n.panner.positionY.value, n.panner.positionZ.value] : null, muffled: n ? n.muffle.frequency.value < 5000 : null, level: n ? loudness(n.meter) : 0 };
			});
			return JSON.stringify(out);
		},
		poll: function () {
			const levels = {};
			Object.keys(v.peers).forEach(function (seat) {
				const p = v.peers[seat];
				if (p.nodes) levels[seat] = loudness(p.nodes.meter);
			});
			const news = { out: v.outbox, state: v.state, levels: levels, mic: v.micLevel ? loudness(v.micLevel) : 0 };
			v.outbox = [];
			return JSON.stringify(news);
		},
	};
})();
""".replace("%NEAR%", str(NEAR)).replace("%FAR%", str(FAR))
