/**
 * vim:set noet tabstop=4 shiftwidth=4 nowrap fileencoding=utf-8:
 */
App = function (url, icecfg) {
	this.url = url || 'ws://localhost:3919/sc';
	this.icecfg = icecfg || {'iceServers': [{'url': 'stun:stun.l.google.com:19302'}]};
	this.ws = null;
	this.ws_buffer = [];
	this.ps = null;
};

(function () {
    var onMediaRequestAccepted = function (streams) {
        var self = this;
		this.pc = this.createPeerConnection(function (e) {
			if (e.candidate) {
				self.signalMessage(JSON.stringify(e.candidate));
			}
        }, function (e) {
			if (typeof(self.onremotemedia) === 'function') {
				self.onremotemedia(e.stream);
			}
		});
		this.pc.addStream(streams);
		this.pc.createOffer(function (desc) {
			self.pc.setLocalDescription(desc);
			self.signalMessage(desc.sdp);
        });
    };

	var onRemoteIceCandidate = function (candidate) {
		if (this.pc != null) {
			this.pc.addIceCandidate(new RTCIceCandidate(candidate));
		}
	};

	var onRemoteSessionDescription = function (desc) {
		if (this.pc != null && typeof(desc.sdp) != 'undefined' && typeof(desc.type) != 'undefined') {
			this.pc.setRemoteDescription(new RTCSessionDescription(desc));
		}
	};

    App.prototype = {
		isBrowserSupported: function () {
            return typeof(WebSocket) === 'function' && (typeof(webkitPeerConnection00) === 'function' || typeof(webkitRTCPeerConnection) === 'function') && typeof(navigator.webkitGetUserMedia) === 'function';
		},

		createPeerConnection: function (onIceCandidate, onAddStream) {
			var peerConnect = null;
			if (typeof(webkitPeerConnection00) === 'function') {
				peerConnect = new webkitPeerConnection00(this.icecfg);
			} else if (typeof(webkitRTCPeerConnection) === 'function') {
				peerConnect = new webkitRTCPeerConnection(this.icecfg);
			} else {
				throw 'The browser does not support RTCPeerConnection.';
			}
			peerConnect.onicecandidate = onIceCandidate;
			peerConnect.onaddstream = onAddStream;
			return peerConnect;
		},

		createSessionDescription: function (sdp) {
			if (typeof(RTCSessionDescription) === 'function') {
				return new RTCSessionDescription({type: 'answer', sdp: e.data});
			} else {
				throw 'The browser does not support RTCSessionDescription.'
			}
		},

		createObjectURL: function (obj) {
			var res = obj;
			if (typeof(webkitURL) === 'function') {
				try {
					res = webkitURL.createObjectURL(obj);
				} catch (err) {
					throw err;
				}
			}
			return res;
		},

		getUserMedia: function(media, onOk) {
			if (typeof(navigator.webkitGetUserMedia) === 'function') {
				navigator.webkitGetUserMedia(media, onOk);
			} else {
				throw 'The browser does not support getUserMedia api.';
			}
		},

		signalMessage: function(msg) {
			var self = this;
			if (this.ws == null) {
				this.ws = new WebSocket(this.url);
				this.ws.onopen = function () {
					if (self.ws_buffer.length > 0) {
						var tmp_buffer = self.ws_buffer;
						self.ws_buffer = [];
						for (var i = 0; i < tmp_buffer.length; i++) {
							self.ws.send(tmp_buffer[i]);
						}
					}
				};
				this.ws.onmessage = function (e) {
					if (e.data && e.data != 'error') {
						var res = null;
						try {
							res = JSON.parse(e.data);
							if (typeof(res.sdp) != 'undefined') {
								onRemoteSessionDescription.call(self, res);
							} else if (typeof(res.candidate) != 'undefined') {
								onRemoteIceCandidate.call(self, res);
							}
						} catch (err) {
							alert(err);
						}
					}
				};
			}
			if (this.ws.readyState == 1) {
				this.ws.send(msg);
			} else {
				this.ws_buffer.push(msg);
			}
		},

		connect: function () {
			var self = this;
			this.getUserMedia({audio: true, video: true},
					function (streams) {
						if (typeof(self.onlocalmedia) === 'function') {
							self.onlocalmedia(streams);
						}
						onMediaRequestAccepted.call(self, streams);
					},
					function (err) {
					});
        },
        onlocalmedia: null,
		onremotemedia: null,
    };
}) ();

