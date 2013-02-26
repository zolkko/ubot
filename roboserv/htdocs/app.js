/**
 * vim:set noet tabstop=4 shiftwidth=4 nowrap fileencoding=utf-8:
 */
App = function (sigChannelUrl, iceConfig) {
	this.scUrl = sigChannelUrl || 'ws://localhost:3919/sc';
	this.iceConfig = iceConfig || 'STUN stun.l.google.com:19302';
	this.readyState = 0;
};

(function () {
    var onMediaRequestAccepted = function (mstreams) {
        var self = this;

        if (typeof(this.onconnecting) === "function")
            this.onconnecting();
        
        var offer;
        var pc = getPeerConnection.call(self, this.iceConfig, function (candidate, bMore) {
            if (candidate && offer) {
                offer.addCandidate(candidate);
            }
            if (!bMore) {
                var finalDescriptor = offer.toSdp();
            }
        });
        pc.addStream(mstreams);
        offer = pc.createOffer(function (desc) {
            pc.setLocalDescription(desc);
            try {
                var ws = new WebSocket(self.scUrl);
                ws.onopen = function () {
                    ws.send(desc.sdp);
                };
                ws.onmessage = function (e) {
                    onWsMessage.call(self, ws, e);
                };
                ws.onerror = function (e) {
                    // onWsError.call(self, ws, e);
                };
                ws.onclose = function () {
                    onWsClose.call(self, ws);
                };
            } catch (err) {
                alert('Failed to send SDP offer to a server. Reason: ' + err);
            }
        });
    };

    App.prototype = {
        NEW: 0,
        CONNECTING: 1,
        CONNECTED: 2,
        NEGOTIATING: 3,
        NEGOTIATED: 4,
        CLOSED: 5,
        ERROR: 6,

		isBrowserSupported: function () {
            return typeof(WebSocket) === 'function' && (typeof(webkitPeerConnection00) === 'function' || typeof(webkitRTCPeerConnection) === 'function') && typeof(navigator.webkitGetUserMedia) === 'function';
		},

		createPeerConnection = function (onIceCandidate, onAddStream) {
			var peerConnect = null;
			if (typeof(webkitPeerConnection00) === 'function') {
				peerConnect = new webkitPeerConnection00(this.iceConfig);
			} else if (typeof(webkitRTCPeerConnection) === 'function') {
				peerConnect = new webkitRTCPeerConnection(this.iceConfig);
			} else {
				throw 'The browser does not support RTCPeerConnection.';
			}
			peerConnect.onicecandidate = onIceCandidate;
			peerConnect.onaddstream = onAddStream;
			return peerConnect;
		},

		createObjectUrl: function (obj) {
			var res = null;
			if (typeof(webkitURL) === 'function') {
				res = webkitURL.createObjectURL(obj);
			} else {
				throw 'The browser does not support objectURL api.';
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

		connect: function () {
			var self = this;
			this.getUserMedia({audio: true, video: true},
					function (mediaStreams) {
						//
					},
					function (err) {
						self.readyState = self.ERROR;
					});
        },

        onlocalmedia: null,
    };
}) ();

