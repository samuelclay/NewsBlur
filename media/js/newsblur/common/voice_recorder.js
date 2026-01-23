NEWSBLUR.VoiceRecorder = function(options) {
    var defaults = {
        on_transcription_start: function() {},
        on_transcription_complete: function() {},
        on_transcription_error: function() {},
        on_recording_start: function() {},
        on_recording_stop: function() {},
        on_recording_cancel: function() {},
        on_audio_level: function() {}
    };

    this.options = _.extend({}, defaults, options);
    this.media_recorder = null;
    this.audio_chunks = [];
    this.is_recording = false;
    this.stream = null;
    this.audio_context = null;
    this.analyser = null;
    this.level_interval = null;
};

NEWSBLUR.VoiceRecorder.prototype = {

    is_supported: function() {
        return !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia && window.MediaRecorder);
    },

    start_recording: function() {
        var self = this;

        if (!this.is_supported()) {
            this.options.on_transcription_error("Voice recording is not supported in your browser");
            return;
        }

        if (this.is_recording) {
            return;
        }

        navigator.mediaDevices.getUserMedia({ audio: true })
            .then(function(stream) {
                self.stream = stream;
                self.audio_chunks = [];

                // Set up audio level monitoring
                self.setup_audio_level_monitor(stream);

                // Use webm codec as it's widely supported
                var mime_type = 'audio/webm';
                if (!MediaRecorder.isTypeSupported(mime_type)) {
                    // Fallback to ogg if webm not supported
                    mime_type = 'audio/ogg';
                    if (!MediaRecorder.isTypeSupported(mime_type)) {
                        // Last fallback
                        mime_type = '';
                    }
                }

                var options = mime_type ? { mimeType: mime_type } : {};
                self.media_recorder = new MediaRecorder(stream, options);

                self.media_recorder.ondataavailable = function(event) {
                    if (event.data.size > 0) {
                        self.audio_chunks.push(event.data);
                    }
                };

                self.media_recorder.onstop = function() {
                    self.is_recording = false;
                    self.stop_audio_level_monitor();
                    self.options.on_recording_stop();

                    // Stop all tracks to release microphone
                    if (self.stream) {
                        self.stream.getTracks().forEach(function(track) {
                            track.stop();
                        });
                        self.stream = null;
                    }

                    // Create blob from chunks
                    var mime_type = self.media_recorder.mimeType || 'audio/webm';
                    var audio_blob = new Blob(self.audio_chunks, { type: mime_type });

                    // Send to transcription
                    self.transcribe_audio(audio_blob);
                };

                self.media_recorder.start();
                self.is_recording = true;
                self.options.on_recording_start();
            })
            .catch(function(error) {
                console.error('Error accessing microphone:', error);
                var error_message;
                if (error.name === 'NotFoundError') {
                    error_message = 'No microphone found. Check System Settings > Privacy > Microphone and enable Chrome.';
                } else if (error.name === 'NotAllowedError') {
                    error_message = 'Microphone permission denied. Click the lock icon in the address bar to allow.';
                } else {
                    error_message = 'Could not access microphone. Please check your browser permissions.';
                }
                self.options.on_transcription_error(error_message);
            });
    },

    stop_recording: function() {
        if (this.media_recorder && this.is_recording) {
            this.media_recorder.stop();
        }
    },

    cancel_recording: function() {
        // Cancel recording without transcribing
        if (!this.is_recording) {
            return;
        }

        // Remove the onstop handler to prevent transcription
        if (this.media_recorder) {
            this.media_recorder.onstop = null;
        }

        // Stop recording
        try {
            if (this.media_recorder && this.is_recording) {
                this.media_recorder.stop();
            }
        } catch (e) {
            console.error('Error stopping media recorder:', e);
        }

        // Stop all tracks to release microphone
        try {
            if (this.stream) {
                this.stream.getTracks().forEach(function(track) {
                    track.stop();
                });
                this.stream = null;
            }
        } catch (e) {
            console.error('Error stopping stream tracks:', e);
        }

        // Reset state
        this.is_recording = false;
        this.audio_chunks = [];
        this.media_recorder = null;

        // Notify that recording was cancelled
        if (this.options.on_recording_cancel) {
            this.options.on_recording_cancel();
        }
    },

    cleanup: function() {
        // Forcefully stop recording and release all resources
        // This is a defensive cleanup method that ensures recording stops even if something fails
        this.stop_audio_level_monitor();

        try {
            if (this.media_recorder && this.is_recording) {
                this.media_recorder.stop();
            }
        } catch (e) {
            console.error('Error stopping media recorder:', e);
        }

        // Stop all tracks to release microphone
        try {
            if (this.stream) {
                this.stream.getTracks().forEach(function(track) {
                    track.stop();
                });
                this.stream = null;
            }
        } catch (e) {
            console.error('Error stopping stream tracks:', e);
        }

        // Reset state
        this.is_recording = false;
        this.audio_chunks = [];
        this.media_recorder = null;
    },

    setup_audio_level_monitor: function(stream) {
        var self = this;

        try {
            // Create audio context and analyser
            this.audio_context = new (window.AudioContext || window.webkitAudioContext)();
            this.analyser = this.audio_context.createAnalyser();
            this.analyser.fftSize = 256;

            // Connect stream to analyser
            var source = this.audio_context.createMediaStreamSource(stream);
            source.connect(this.analyser);

            // Sample audio level periodically
            var data_array = new Uint8Array(this.analyser.frequencyBinCount);

            this.level_interval = setInterval(function() {
                if (!self.is_recording) {
                    self.stop_audio_level_monitor();
                    return;
                }

                self.analyser.getByteFrequencyData(data_array);

                // Calculate average volume (0-255)
                var sum = 0;
                for (var i = 0; i < data_array.length; i++) {
                    sum += data_array[i];
                }
                var average = sum / data_array.length;

                // Normalize to 0-1 range
                var level = Math.min(1, average / 128);

                self.options.on_audio_level(level);
            }, 50);  // Update every 50ms

        } catch (e) {
            console.error('Error setting up audio level monitor:', e);
        }
    },

    stop_audio_level_monitor: function() {
        if (this.level_interval) {
            clearInterval(this.level_interval);
            this.level_interval = null;
        }

        if (this.audio_context) {
            try {
                this.audio_context.close();
            } catch (e) {
                // Ignore errors closing context
            }
            this.audio_context = null;
        }

        this.analyser = null;

        // Send final zero level
        this.options.on_audio_level(0);
    },

    transcribe_audio: function(audio_blob) {
        var self = this;

        self.options.on_transcription_start();

        var form_data = new FormData();
        // Add proper extension based on mime type
        var extension = 'webm';
        if (audio_blob.type.includes('ogg')) {
            extension = 'ogg';
        } else if (audio_blob.type.includes('mp4')) {
            extension = 'mp4';
        }
        form_data.append('audio', audio_blob, 'recording.' + extension);

        $.ajax({
            url: '/ask-ai/transcribe',
            type: 'POST',
            data: form_data,
            processData: false,
            contentType: false,
            success: function(response) {
                if (response.code === 1 && response.text) {
                    self.options.on_transcription_complete(response.text);
                } else {
                    self.options.on_transcription_error(response.message || 'Transcription failed');
                }
            },
            error: function(xhr, status, error) {
                console.error('Transcription error:', error);
                self.options.on_transcription_error('Failed to transcribe audio. Please try again.');
            }
        });
    }
};
