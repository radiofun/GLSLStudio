import Foundation

// Additional shader templates and examples
struct GLSLExamples {
    static let noiseShader = """
precision mediump float;

uniform float u_time;
uniform vec2 u_resolution;
varying vec2 v_texcoord;

// Perlin noise functions
vec3 mod289(vec3 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 mod289(vec4 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x) {
    return mod289(((x*34.0)+1.0)*x);
}

vec4 taylorInvSqrt(vec4 r) {
    return 1.79284291400159 - 0.85373472095314 * r;
}

float snoise(vec3 v) {
    const vec2 C = vec2(1.0/6.0, 1.0/3.0);
    const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
    
    vec3 i = floor(v + dot(v, C.yyy));
    vec3 x0 = v - i + dot(i, C.xxx);
    
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);
    
    vec3 x1 = x0 - i1 + C.xxx;
    vec3 x2 = x0 - i2 + C.yyy;
    vec3 x3 = x0 - D.yyy;
    
    i = mod289(i);
    vec4 p = permute(permute(permute(
        i.z + vec4(0.0, i1.z, i2.z, 1.0))
        + i.y + vec4(0.0, i1.y, i2.y, 1.0))
        + i.x + vec4(0.0, i1.x, i2.x, 1.0));
    
    float n_ = 0.142857142857;
    vec3 ns = n_ * D.wyz - D.xzx;
    
    vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
    
    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_);
    
    vec4 x = x_ *ns.x + ns.yyyy;
    vec4 y = y_ *ns.x + ns.yyyy;
    vec4 h = 1.0 - abs(x) - abs(y);
    
    vec4 b0 = vec4(x.xy, y.xy);
    vec4 b1 = vec4(x.zw, y.zw);
    
    vec4 s0 = floor(b0) * 2.0 + 1.0;
    vec4 s1 = floor(b1) * 2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));
    
    vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
    
    vec3 p0 = vec3(a0.xy, h.x);
    vec3 p1 = vec3(a0.zw, h.y);
    vec3 p2 = vec3(a1.xy, h.z);
    vec3 p3 = vec3(a1.zw, h.w);
    
    vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2,p2), dot(p3,p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;
    
    vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
    m = m * m;
    return 42.0 * dot(m*m, vec4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
}

void main() {
    vec2 uv = v_texcoord * 4.0;
    
    float noise = snoise(vec3(uv, u_time * 0.5));
    noise = (noise + 1.0) * 0.5;
    
    vec3 color = vec3(noise);
    gl_FragColor = vec4(color, 1.0);
}
"""
    
    static let waterShader = """
precision mediump float;

uniform float u_time;
uniform vec2 u_resolution;
varying vec2 v_texcoord;

void main() {
    vec2 uv = v_texcoord;
    
    // Create water waves
    float wave1 = sin(uv.x * 10.0 + u_time * 2.0) * 0.1;
    float wave2 = sin(uv.y * 8.0 + u_time * 1.5) * 0.1;
    float wave3 = sin((uv.x + uv.y) * 12.0 + u_time * 3.0) * 0.05;
    
    float waves = wave1 + wave2 + wave3;
    
    // Water color
    vec3 deepWater = vec3(0.0, 0.2, 0.4);
    vec3 shallowWater = vec3(0.2, 0.6, 0.8);
    
    vec3 color = mix(deepWater, shallowWater, waves + 0.5);
    
    // Add foam
    float foam = smoothstep(0.8, 1.0, waves + 0.5);
    color = mix(color, vec3(1.0), foam * 0.3);
    
    gl_FragColor = vec4(color, 1.0);
}
"""
    
    static let fireShader = """
precision mediump float;

uniform float u_time;
uniform vec2 u_resolution;
varying vec2 v_texcoord;

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(a, b, u.x) + (c - a)* u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void main() {
    vec2 uv = v_texcoord;
    
    // Flip Y to make fire go up
    uv.y = 1.0 - uv.y;
    
    // Create turbulent noise for fire
    float n = noise(uv * 4.0 + vec2(0.0, u_time * 2.0));
    n += noise(uv * 8.0 + vec2(0.0, u_time * 4.0)) * 0.5;
    n += noise(uv * 16.0 + vec2(0.0, u_time * 8.0)) * 0.25;
    
    // Shape the fire
    float fireShape = smoothstep(0.0, 0.3, uv.y) * (1.0 - uv.y);
    fireShape *= smoothstep(0.1, 0.5, 1.0 - abs(uv.x - 0.5) * 2.0);
    
    float fire = n * fireShape;
    
    // Fire colors
    vec3 fireColor = vec3(1.0, 0.3, 0.0) * fire;
    fireColor += vec3(1.0, 0.8, 0.0) * fire * fire;
    fireColor += vec3(1.0, 1.0, 0.8) * fire * fire * fire;
    
    gl_FragColor = vec4(fireColor, 1.0);
}
"""
    
    static let plasmaShader = """
precision mediump float;

uniform float u_time;
uniform vec2 u_resolution;
varying vec2 v_texcoord;

void main() {
    vec2 uv = v_texcoord;
    
    // Scale coordinates
    uv = uv * 2.0 - 1.0;
    uv.x *= u_resolution.x / u_resolution.y;
    
    // Create plasma pattern
    float plasma = 0.0;
    plasma += sin(uv.x * 10.0 + u_time);
    plasma += sin(uv.y * 8.0 + u_time * 1.2);
    plasma += sin((uv.x + uv.y) * 12.0 + u_time * 0.8);
    plasma += sin(sqrt(uv.x * uv.x + uv.y * uv.y) * 15.0 + u_time * 1.5);
    
    plasma /= 4.0;
    
    // Convert to colors
    vec3 color = vec3(0.5 + 0.5 * sin(plasma + vec3(0.0, 2.0, 4.0)));
    
    gl_FragColor = vec4(color, 1.0);
}
"""
}