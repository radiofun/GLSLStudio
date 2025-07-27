import Foundation

extension WebGLService {
    func createWebGLHTML() -> String {
        return """
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        html, body {
            width: 100%;
            height: 100%;
            margin: 0;
            padding: 0;
            overflow: hidden;
            background: #000;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        }
        canvas {
            width: 100vw;
            height: 100vh;
            display: block;
            position: absolute;
            top: 0;
            left: 0;
        }
        #error {
            position: absolute;
            top: 10px;
            left: 10px;
            right: 10px;
            color: #ff4444;
            font-family: monospace;
            font-size: 12px;
            background: rgba(0,0,0,0.9);
            padding: 15px;
            border-radius: 8px;
            max-height: 50%;
            overflow-y: auto;
            white-space: pre-wrap;
            display: none;
            border: 1px solid #ff4444;
            box-shadow: 0 4px 12px rgba(255, 68, 68, 0.3);
        }
        #stats {
            position: absolute;
            top: 10px;
            right: 10px;
            color: #00ff00;
            font-family: monospace;
            font-size: 11px;
            background: rgba(0,0,0,0.7);
            padding: 8px;
            border-radius: 4px;
            display: none;
        }
    </style>
</head>
<body>
    <canvas id="canvas"></canvas>
    <div id="error"></div>
    <div id="stats"></div>
    
    <script>
        class GLSLStudio {
            constructor() {
                this.canvas = document.getElementById('canvas');
                this.errorDiv = document.getElementById('error');
                this.statsDiv = document.getElementById('stats');
                this.gl = null;
                this.program = null;
                this.startTime = Date.now();
                this.frameCount = 0;
                this.lastStatsUpdate = Date.now();
                this.uniforms = {};
                this.currentGeometry = 'quad';
                this.geometryData = {};
                this.animationId = null;
                this.vertexBuffer = null;
                this.indexBuffer = null;
                
                this.initializeGL();
            }
            
            initializeGL() {
                this.setupCanvas();
                if (this.initWebGL()) {
                    this.createGeometries();
                    this.sendMessage('ready');
                    
                    // Check for pending shaders
                    if (window.pendingShaders) {
                        console.log('Loading pending shaders...');
                        this.updateShaders(window.pendingShaders.vertex, window.pendingShaders.fragment);
                        window.pendingShaders = null;
                    } else {
                        this.startRender();
                    }
                }
            }
            
            setupCanvas() {
                const resizeCanvas = () => {
                    const dpr = window.devicePixelRatio || 1;
                    
                    // Get the actual size of the container
                    const containerWidth = window.innerWidth;
                    const containerHeight = window.innerHeight;
                    
                    // Set canvas display size (CSS pixels)
                    this.canvas.style.width = containerWidth + 'px';
                    this.canvas.style.height = containerHeight + 'px';
                    
                    // Set canvas buffer size (actual pixels)
                    this.canvas.width = containerWidth * dpr;
                    this.canvas.height = containerHeight * dpr;
                    
                    // Scale the canvas back down using CSS
                    this.canvas.style.width = containerWidth + 'px';
                    this.canvas.style.height = containerHeight + 'px';
                    
                    if (this.gl) {
                        this.gl.viewport(0, 0, this.canvas.width, this.canvas.height);
                        console.log('Canvas resized to:', this.canvas.width, 'x', this.canvas.height, 'pixels');
                    }
                };
                
                window.addEventListener('resize', resizeCanvas);
                // Also listen for orientation changes on mobile
                window.addEventListener('orientationchange', resizeCanvas);
                
                // Use ResizeObserver for more responsive sizing
                if (window.ResizeObserver) {
                    const resizeObserver = new ResizeObserver(entries => {
                        for (let entry of entries) {
                            resizeCanvas();
                        }
                    });
                    resizeObserver.observe(document.body);
                }
                
                // Initial resize with multiple attempts
                setTimeout(resizeCanvas, 50);
                setTimeout(resizeCanvas, 200);
                setTimeout(resizeCanvas, 500);
            }
            
            initWebGL() {
                console.log('Initializing WebGL...');
                this.gl = this.canvas.getContext('webgl', {
                    alpha: false,
                    antialias: true,
                    depth: true,
                    preserveDrawingBuffer: true
                }) || this.canvas.getContext('experimental-webgl', {
                    alpha: false,
                    antialias: true,
                    depth: true,
                    preserveDrawingBuffer: true
                });
                
                if (!this.gl) {
                    console.error('WebGL not supported');
                    this.showError('WebGL not supported');
                    return false;
                }
                
                console.log('WebGL context created successfully');
                console.log('Canvas size:', this.canvas.width, 'x', this.canvas.height);
                
                // Enable extensions
                this.gl.getExtension('OES_standard_derivatives');
                this.gl.getExtension('EXT_shader_texture_lod');
                
                // Set viewport
                this.gl.viewport(0, 0, this.canvas.width, this.canvas.height);
                this.gl.enable(this.gl.DEPTH_TEST);
                
                // Force a resize to ensure canvas fills container
                setTimeout(() => {
                    window.dispatchEvent(new Event('resize'));
                }, 50);
                
                return true;
            }
            
            createGeometries() {
                // Quad (default)
                this.geometryData.quad = {
                    vertices: new Float32Array([
                        -1, -1, 0, 0,
                         1, -1, 1, 0,
                        -1,  1, 0, 1,
                         1,  1, 1, 1
                    ]),
                    indices: new Uint16Array([0, 1, 2, 1, 3, 2]),
                    primitive: this.gl.TRIANGLES
                };
                
                // Triangle
                this.geometryData.triangle = {
                    vertices: new Float32Array([
                         0,  1, 0.5, 1,
                        -1, -1, 0, 0,
                         1, -1, 1, 0
                    ]),
                    indices: new Uint16Array([0, 1, 2]),
                    primitive: this.gl.TRIANGLES
                };
                
                // Cube (for 3D shaders)
                this.createCubeGeometry();
                
                // Sphere (for 3D shaders)
                this.createSphereGeometry();
            }
            
            createCubeGeometry() {
                const vertices = new Float32Array([
                    // Front face
                    -1, -1,  1,  0, 0,
                     1, -1,  1,  1, 0,
                     1,  1,  1,  1, 1,
                    -1,  1,  1,  0, 1,
                    // Back face
                    -1, -1, -1,  1, 0,
                    -1,  1, -1,  1, 1,
                     1,  1, -1,  0, 1,
                     1, -1, -1,  0, 0,
                    // Top face
                    -1,  1, -1,  0, 1,
                    -1,  1,  1,  0, 0,
                     1,  1,  1,  1, 0,
                     1,  1, -1,  1, 1,
                    // Bottom face
                    -1, -1, -1,  0, 0,
                     1, -1, -1,  1, 0,
                     1, -1,  1,  1, 1,
                    -1, -1,  1,  0, 1,
                    // Right face
                     1, -1, -1,  0, 0,
                     1,  1, -1,  1, 0,
                     1,  1,  1,  1, 1,
                     1, -1,  1,  0, 1,
                    // Left face
                    -1, -1, -1,  1, 0,
                    -1, -1,  1,  0, 0,
                    -1,  1,  1,  0, 1,
                    -1,  1, -1,  1, 1
                ]);
                
                const indices = new Uint16Array([
                    0,  1,  2,    0,  2,  3,    // front
                    4,  5,  6,    4,  6,  7,    // back
                    8,  9,  10,   8,  10, 11,   // top
                    12, 13, 14,   12, 14, 15,   // bottom
                    16, 17, 18,   16, 18, 19,   // right
                    20, 21, 22,   20, 22, 23    // left
                ]);
                
                this.geometryData.cube = {
                    vertices: vertices,
                    indices: indices,
                    primitive: this.gl.TRIANGLES
                };
            }
            
            createSphereGeometry() {
                const latitudeBands = 30;
                const longitudeBands = 30;
                const radius = 1;
                
                const vertices = [];
                const indices = [];
                
                for (let lat = 0; lat <= latitudeBands; lat++) {
                    const theta = lat * Math.PI / latitudeBands;
                    const sinTheta = Math.sin(theta);
                    const cosTheta = Math.cos(theta);
                    
                    for (let lon = 0; lon <= longitudeBands; lon++) {
                        const phi = lon * 2 * Math.PI / longitudeBands;
                        const sinPhi = Math.sin(phi);
                        const cosPhi = Math.cos(phi);
                        
                        const x = cosPhi * sinTheta;
                        const y = cosTheta;
                        const z = sinPhi * sinTheta;
                        const u = 1 - (lon / longitudeBands);
                        const v = 1 - (lat / latitudeBands);
                        
                        vertices.push(x * radius, y * radius, z * radius, u, v);
                    }
                }
                
                for (let lat = 0; lat < latitudeBands; lat++) {
                    for (let lon = 0; lon < longitudeBands; lon++) {
                        const first = (lat * (longitudeBands + 1)) + lon;
                        const second = first + longitudeBands + 1;
                        
                        indices.push(first, second, first + 1);
                        indices.push(second, second + 1, first + 1);
                    }
                }
                
                this.geometryData.sphere = {
                    vertices: new Float32Array(vertices),
                    indices: new Uint16Array(indices),
                    primitive: this.gl.TRIANGLES
                };
            }
            
            createShader(type, source) {
                const shader = this.gl.createShader(type);
                this.gl.shaderSource(shader, source);
                this.gl.compileShader(shader);
                
                if (!this.gl.getShaderParameter(shader, this.gl.COMPILE_STATUS)) {
                    const error = this.gl.getShaderInfoLog(shader);
                    this.gl.deleteShader(shader);
                    throw new Error(error);
                }
                
                return shader;
            }
            
            updateShaders(vertexSource, fragmentSource) {
                try {
                    console.log('UpdateShaders called with:', vertexSource.length, 'vertex chars,', fragmentSource.length, 'fragment chars');
                    this.hideError();
                    
                    const vertexShader = this.createShader(this.gl.VERTEX_SHADER, vertexSource);
                    const fragmentShader = this.createShader(this.gl.FRAGMENT_SHADER, fragmentSource);
                    
                    if (this.program) {
                        this.gl.deleteProgram(this.program);
                    }
                    
                    this.program = this.gl.createProgram();
                    this.gl.attachShader(this.program, vertexShader);
                    this.gl.attachShader(this.program, fragmentShader);
                    this.gl.linkProgram(this.program);
                    
                    if (!this.gl.getProgramParameter(this.program, this.gl.LINK_STATUS)) {
                        throw new Error(this.gl.getProgramInfoLog(this.program));
                    }
                    
                    this.gl.useProgram(this.program);
                    this.setupGeometry();
                    this.detectUniforms();
                    
                    console.log('Shaders compiled successfully, starting render...');
                    
                    // Start rendering if not already started
                    if (!this.animationId) {
                        this.startRender();
                    }
                    
                } catch (error) {
                    console.error('Shader compilation error:', error.message);
                    this.showError(error.message);
                    this.sendMessage('error', { message: error.message });
                }
            }
            
            setupGeometry() {
                const geometry = this.geometryData[this.currentGeometry];
                if (!geometry) return;
                
                // Clean up old buffers
                if (this.vertexBuffer) this.gl.deleteBuffer(this.vertexBuffer);
                if (this.indexBuffer) this.gl.deleteBuffer(this.indexBuffer);
                
                // Create buffers
                this.vertexBuffer = this.gl.createBuffer();
                this.gl.bindBuffer(this.gl.ARRAY_BUFFER, this.vertexBuffer);
                this.gl.bufferData(this.gl.ARRAY_BUFFER, geometry.vertices, this.gl.STATIC_DRAW);
                
                this.indexBuffer = this.gl.createBuffer();
                this.gl.bindBuffer(this.gl.ELEMENT_ARRAY_BUFFER, this.indexBuffer);
                this.gl.bufferData(this.gl.ELEMENT_ARRAY_BUFFER, geometry.indices, this.gl.STATIC_DRAW);
                
                // Setup attributes
                const positionLocation = this.gl.getAttribLocation(this.program, 'a_position');
                const texcoordLocation = this.gl.getAttribLocation(this.program, 'a_texcoord');
                
                if (positionLocation >= 0) {
                    this.gl.enableVertexAttribArray(positionLocation);
                    const stride = (this.currentGeometry === 'quad' || this.currentGeometry === 'triangle') ? 16 : 20;
                    const posSize = (this.currentGeometry === 'quad' || this.currentGeometry === 'triangle') ? 2 : 3;
                    this.gl.vertexAttribPointer(positionLocation, posSize, this.gl.FLOAT, false, stride, 0);
                }
                
                if (texcoordLocation >= 0) {
                    this.gl.enableVertexAttribArray(texcoordLocation);
                    const stride = (this.currentGeometry === 'quad' || this.currentGeometry === 'triangle') ? 16 : 20;
                    const offset = (this.currentGeometry === 'quad' || this.currentGeometry === 'triangle') ? 8 : 12;
                    this.gl.vertexAttribPointer(texcoordLocation, 2, this.gl.FLOAT, false, stride, offset);
                }
            }
            
            detectUniforms() {
                if (!this.program) return;
                
                const numUniforms = this.gl.getProgramParameter(this.program, this.gl.ACTIVE_UNIFORMS);
                this.uniforms = {};
                
                for (let i = 0; i < numUniforms; i++) {
                    const uniform = this.gl.getActiveUniform(this.program, i);
                    const location = this.gl.getUniformLocation(this.program, uniform.name);
                    
                    this.uniforms[uniform.name] = {
                        location: location,
                        type: uniform.type,
                        size: uniform.size
                    };
                }
            }
            
            setUniform(name, value) {
                const uniform = this.uniforms[name];
                if (!uniform) return;
                
                switch (uniform.type) {
                    case this.gl.FLOAT:
                        this.gl.uniform1f(uniform.location, value);
                        break;
                    case this.gl.FLOAT_VEC2:
                        this.gl.uniform2fv(uniform.location, value);
                        break;
                    case this.gl.FLOAT_VEC3:
                        this.gl.uniform3fv(uniform.location, value);
                        break;
                    case this.gl.FLOAT_VEC4:
                        this.gl.uniform4fv(uniform.location, value);
                        break;
                }
            }
            
            setGeometry(geometryType) {
                if (this.geometryData[geometryType]) {
                    this.currentGeometry = geometryType;
                    if (this.program) {
                        this.setupGeometry();
                    }
                }
            }
            
            startRender() {
                if (!this.gl) return;
                this.render();
            }
            
            render() {
                if (!this.gl) {
                    return;
                }
                
                const startTime = performance.now();
                const time = (Date.now() - this.startTime) / 1000.0;
                
                // Clear the canvas
                this.gl.clearColor(0.1, 0.1, 0.1, 1.0);
                this.gl.clear(this.gl.COLOR_BUFFER_BIT | this.gl.DEPTH_BUFFER_BIT);
                
                if (this.program) {
                    this.gl.useProgram(this.program);
                    
                    // Update built-in uniforms
                    if (this.uniforms.u_time) {
                        this.gl.uniform1f(this.uniforms.u_time.location, time);
                    }
                    
                    if (this.uniforms.u_resolution) {
                        this.gl.uniform2f(this.uniforms.u_resolution.location, this.canvas.width, this.canvas.height);
                    }
                    
                    if (this.uniforms.u_mouse && window.mousePos) {
                        this.gl.uniform2f(this.uniforms.u_mouse.location, window.mousePos.x, window.mousePos.y);
                    }
                    
                    // Bind buffers and draw
                    const geometry = this.geometryData[this.currentGeometry];
                    if (geometry && this.vertexBuffer && this.indexBuffer) {
                        this.gl.bindBuffer(this.gl.ARRAY_BUFFER, this.vertexBuffer);
                        this.gl.bindBuffer(this.gl.ELEMENT_ARRAY_BUFFER, this.indexBuffer);
                        
                        this.gl.drawElements(geometry.primitive, geometry.indices.length, this.gl.UNSIGNED_SHORT, 0);
                    }
                }
                
                // Update stats
                this.frameCount++;
                const renderTime = performance.now() - startTime;
                
                if (Date.now() - this.lastStatsUpdate > 1000) {
                    const fps = this.frameCount;
                    this.frameCount = 0;
                    this.lastStatsUpdate = Date.now();
                    
                    this.updateStats(fps, renderTime);
                    this.sendMessage('stats', { fps: fps, renderTime: renderTime });
                }
                
                this.animationId = requestAnimationFrame(() => this.render());
            }
            
            updateStats(fps, renderTime) {
                this.statsDiv.innerHTML = `FPS: ${fps}\\nRender: ${renderTime.toFixed(2)}ms\\nCanvas: ${this.canvas.width}x${this.canvas.height}`;
                this.statsDiv.style.display = 'block';
            }
            
            showError(message) {
                this.errorDiv.textContent = message;
                this.errorDiv.style.display = 'block';
            }
            
            hideError() {
                this.errorDiv.style.display = 'none';
                this.sendMessage('clearError');
            }
            
            captureFrame() {
                return this.canvas.toDataURL('image/png');
            }
            
            sendMessage(type, data = {}) {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.nativeHandler) {
                    window.webkit.messageHandlers.nativeHandler.postMessage({
                        type: type,
                        ...data
                    });
                }
            }
        }
        
        // Mouse tracking
        window.mousePos = { x: 0, y: 0 };
        document.addEventListener('mousemove', (e) => {
            const rect = document.getElementById('canvas').getBoundingClientRect();
            window.mousePos.x = e.clientX - rect.left;
            window.mousePos.y = rect.height - (e.clientY - rect.top);
        });
        
        // Initialize
        window.glslStudio = new GLSLStudio();
    </script>
</body>
</html>
"""
    }
}