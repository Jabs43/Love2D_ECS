extern int NUM_CIRCLES;
extern vec3 CircleData[1020]; // (X_c, Y_c, R)

// A smooth minimum fn to blend circles together
float smin(float a, float b, float k){
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * (1.0 / 4.0);
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
    // Initialize the combined effect variables.
    // Use a value > 1.0 to represent "inifinitely far away" initially.
    float d = 1e6; // a Large number

    for (int i = 0; i < NUM_CIRCLES; i++) {
        vec2 center = CircleData[i].xy;
        float R = CircleData[i].z;
        
        // Distance vector in pixels from the circle's center
        float dist = length(screen_coords - center) - R;

        d = smin(d, dist, 5.0);
    }

    // Early exit
    if(d > 1.0) return vec4(0.0);

    // Lighting/Vignette based on distance to surface (d=0 is the edge)
    // d is negative inside the circle.
    float mask = smoothstep(0.1, -1.0, d);
    float internalDist = clamp(-d / 10.0, 0.0, 1.0);
    float brightness = mix(0.1, 0.9, pow(internalDist, 0.5));
    
    return vec4(color.rgb * brightness, mask * color.a);
}