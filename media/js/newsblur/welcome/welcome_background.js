NEWSBLUR.WelcomeBackground = (function () {
    var gl, canvas, program, timeUniform, resolutionUniform, themeUniform;
    var startTime, animationId;
    var running = false;
    var currentTheme = 1.0; // 0.0 = light, 1.0 = dark
    var targetTheme = 1.0;

    var VERT_SRC = [
        'attribute vec2 a_position;',
        'void main() {',
        '    gl_Position = vec4(a_position, 0.0, 1.0);',
        '}'
    ].join('\n');

    var FRAG_SRC = [
        'precision mediump float;',
        'uniform float u_time;',
        'uniform vec2 u_resolution;',
        'uniform float u_theme;',

        'void main() {',
        '    vec2 uv = gl_FragCoord.xy / u_resolution;',

        // Dark palette (original)
        '    vec3 d_base     = vec3(0.106, 0.141, 0.141);',
        '    vec3 d_mid      = vec3(0.247, 0.326, 0.329);',
        '    vec3 d_light    = vec3(0.35, 0.54, 0.55);',
        '    vec3 d_gold     = vec3(0.85, 0.65, 0.13);',
        '    vec3 d_softGold = vec3(0.98, 0.86, 0.61);',

        // Light palette — lighter teal/green, still recognizable
        '    vec3 l_base     = vec3(0.20, 0.28, 0.28);',
        '    vec3 l_mid      = vec3(0.35, 0.46, 0.47);',
        '    vec3 l_light    = vec3(0.48, 0.66, 0.67);',
        '    vec3 l_gold     = vec3(0.85, 0.65, 0.13);',
        '    vec3 l_softGold = vec3(0.98, 0.86, 0.61);',

        // Interpolate palettes based on theme
        '    vec3 base     = mix(l_base,     d_base,     u_theme);',
        '    vec3 mid      = mix(l_mid,      d_mid,      u_theme);',
        '    vec3 light    = mix(l_light,    d_light,    u_theme);',
        '    vec3 gold     = mix(l_gold,     d_gold,     u_theme);',
        '    vec3 softGold = mix(l_softGold, d_softGold, u_theme);',

        // Base gradient: mid at top fading to base at bottom
        '    vec3 bg = mix(mid, base, smoothstep(0.0, 1.0, uv.y));',

        // Diagonal coordinate for wave ridges
        '    float diag = uv.x * 0.6 + uv.y * 0.4;',

        // Wave ridge 1 - slow, broad
        '    float wave1 = sin(diag * 8.0 + u_time * 0.7) * 0.5 + 0.5;',
        '    wave1 = pow(wave1, 3.0);',

        // Wave ridge 2 - medium frequency
        '    float wave2 = sin(diag * 14.0 - u_time * 0.5 + 1.5) * 0.5 + 0.5;',
        '    wave2 = pow(wave2, 4.0);',

        // Wave ridge 3 - higher frequency, subtle
        '    float wave3 = sin(diag * 22.0 + u_time * 0.3 + 3.0) * 0.5 + 0.5;',
        '    wave3 = pow(wave3, 5.0);',

        // Combine ridges with light tinting
        '    vec3 ridge1 = mix(bg, light, wave1 * 0.4);',
        '    vec3 ridge2 = mix(ridge1, light, wave2 * 0.25);',
        '    vec3 color  = mix(ridge2, light, wave3 * 0.15);',

        // Slow gold glow that drifts across
        '    float glow = sin(uv.x * 3.0 + u_time * 0.2) * sin(uv.y * 2.0 - u_time * 0.15);',
        '    glow = max(glow, 0.0);',
        '    glow = pow(glow, 2.0) * 0.3;',
        '    color = mix(color, softGold, glow * 0.25);',

        // Subtle gold highlight on wave peaks
        '    float goldHighlight = wave1 * wave2;',
        '    color = mix(color, gold, goldHighlight * 0.08);',

        '    gl_FragColor = vec4(color, 1.0);',
        '}'
    ].join('\n');

    function compileShader(type, src) {
        var shader = gl.createShader(type);
        gl.shaderSource(shader, src);
        gl.compileShader(shader);
        if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
            console.warn('Shader compile error:', gl.getShaderInfoLog(shader));
            gl.deleteShader(shader);
            return null;
        }
        return shader;
    }

    function resize() {
        var dpr = Math.min(window.devicePixelRatio || 1, 2);
        var w = canvas.clientWidth * dpr;
        var h = canvas.clientHeight * dpr;
        if (canvas.width !== w || canvas.height !== h) {
            canvas.width = w;
            canvas.height = h;
            gl.viewport(0, 0, w, h);
        }
    }

    function render() {
        if (!running) return;
        resize();

        // Smooth theme transition
        if (currentTheme !== targetTheme) {
            var delta = targetTheme - currentTheme;
            currentTheme += delta * 0.08;
            if (Math.abs(delta) < 0.005) currentTheme = targetTheme;
        }

        var elapsed = (Date.now() - startTime) / 1000.0 * 0.4;
        gl.uniform1f(timeUniform, elapsed);
        gl.uniform2f(resolutionUniform, canvas.width, canvas.height);
        gl.uniform1f(themeUniform, currentTheme);
        gl.drawArrays(gl.TRIANGLES, 0, 3);
        animationId = requestAnimationFrame(render);
    }

    function onVisibilityChange() {
        if (document.hidden) {
            if (animationId) {
                cancelAnimationFrame(animationId);
                animationId = null;
            }
        } else if (running) {
            animationId = requestAnimationFrame(render);
        }
    }

    return {
        init: function (canvasEl) {
            canvas = canvasEl;
            try {
                gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');
            } catch (e) {
                return false;
            }
            if (!gl) return false;

            var vert = compileShader(gl.VERTEX_SHADER, VERT_SRC);
            var frag = compileShader(gl.FRAGMENT_SHADER, FRAG_SRC);
            if (!vert || !frag) return false;

            program = gl.createProgram();
            gl.attachShader(program, vert);
            gl.attachShader(program, frag);
            gl.linkProgram(program);

            if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
                console.warn('Program link error:', gl.getProgramInfoLog(program));
                return false;
            }

            gl.useProgram(program);

            // Full-screen triangle (3 vertices, covers entire clip space)
            var buf = gl.createBuffer();
            gl.bindBuffer(gl.ARRAY_BUFFER, buf);
            gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([
                -1, -1,
                 3, -1,
                -1,  3
            ]), gl.STATIC_DRAW);

            var posAttr = gl.getAttribLocation(program, 'a_position');
            gl.enableVertexAttribArray(posAttr);
            gl.vertexAttribPointer(posAttr, 2, gl.FLOAT, false, 0, 0);

            timeUniform = gl.getUniformLocation(program, 'u_time');
            resolutionUniform = gl.getUniformLocation(program, 'u_resolution');
            themeUniform = gl.getUniformLocation(program, 'u_theme');

            document.addEventListener('visibilitychange', onVisibilityChange);
            return true;
        },

        start: function () {
            running = true;
            startTime = Date.now();
            animationId = requestAnimationFrame(render);
        },

        stop: function () {
            running = false;
            if (animationId) {
                cancelAnimationFrame(animationId);
                animationId = null;
            }
        },

        setTheme: function (isDark) {
            targetTheme = isDark ? 1.0 : 0.0;
        },

        setThemeImmediate: function (isDark) {
            targetTheme = isDark ? 1.0 : 0.0;
            currentTheme = targetTheme;
        },

        destroy: function () {
            this.stop();
            document.removeEventListener('visibilitychange', onVisibilityChange);
            if (gl && program) {
                gl.deleteProgram(program);
            }
            gl = null;
            canvas = null;
            program = null;
        }
    };
})();
