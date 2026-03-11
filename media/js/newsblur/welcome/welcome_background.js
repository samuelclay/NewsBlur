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
        '    float t = u_time;',

        // Dark palette (teal)
        '    vec3 d_darkBase  = vec3(0.106, 0.141, 0.141);',
        '    vec3 d_warm      = vec3(0.247, 0.326, 0.329);',
        '    vec3 d_lightWarm = vec3(0.35, 0.54, 0.55);',
        '    vec3 d_gold      = vec3(0.85, 0.65, 0.13);',
        '    vec3 d_softGold  = vec3(0.98, 0.86, 0.61);',

        // Light palette (sunny beige)
        '    vec3 l_darkBase  = vec3(0.52, 0.42, 0.28);',
        '    vec3 l_warm      = vec3(0.72, 0.62, 0.44);',
        '    vec3 l_lightWarm = vec3(0.88, 0.80, 0.64);',
        '    vec3 l_gold      = vec3(0.90, 0.72, 0.22);',
        '    vec3 l_softGold  = vec3(0.98, 0.90, 0.70);',

        // Interpolate palettes based on theme
        '    vec3 darkBase  = mix(l_darkBase,  d_darkBase,  u_theme);',
        '    vec3 warm      = mix(l_warm,      d_warm,      u_theme);',
        '    vec3 lightWarm = mix(l_lightWarm, d_lightWarm, u_theme);',
        '    vec3 gold      = mix(l_gold,      d_gold,      u_theme);',
        '    vec3 softGold  = mix(l_softGold,  d_softGold,  u_theme);',

        // Base gradient: warm at bottom fading to dark at top
        '    vec3 base = mix(warm, darkBase, smoothstep(0.0, 1.0, uv.y));',

        // Three diagonal coordinates for independent wave directions
        '    float d1 = uv.x * 0.6 + uv.y * 0.4;',
        '    float d2 = uv.x * 0.4 - uv.y * 0.6;',
        '    float d3 = uv.x * 0.8 + uv.y * 0.2;',

        // Gaussian wave ridges with cross-modulation
        '    float w1 = sin(d1 * 8.0 + t * 0.5 + sin(uv.y * 4.0 + t * 0.3) * 0.8);',
        '    float ridge1 = exp(-w1 * w1 * 2.5) * 0.35;',

        '    float w2 = sin(d2 * 6.0 + t * 0.7 + cos(uv.x * 3.0 - t * 0.5) * 0.6);',
        '    float ridge2 = exp(-w2 * w2 * 3.0) * 0.2;',

        '    float w3 = sin(d3 * 14.0 - t * 0.9 + sin(d1 * 5.0 + t * 0.4) * 0.4);',
        '    float ridge3 = exp(-w3 * w3 * 4.0) * 0.12;',

        // Subtle warm glow
        '    float w4 = sin(d1 * 3.0 + t * 0.25);',
        '    float glow = w4 * w4 * 0.15;',

        // Additive color blending
        '    vec3 color = base;',
        '    color += lightWarm * ridge1;',
        '    color += gold * 0.7 * ridge2;',
        '    color += softGold * 0.4 * ridge3;',
        '    color += warm * glow;',

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
