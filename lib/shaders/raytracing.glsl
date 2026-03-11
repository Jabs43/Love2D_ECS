// === Abyssal Raytracing Shader (with Normal Cache) === \\
// Simulates deep ocean spectral attenuation, scattering, and bounce 
extern Image baseHeight;
extern Image dynamicHeight;
extern vec2 heightTexelSize; // 1.0 / heightmap resolution
extern float aspectRatioY; // W / H

float sampleHeight(vec2 uv) {
    // Adding a tiny half-texel offset helps center the sample
    vec2 centeredUV = uv + (heightTexelSize * 0.5);
    float dyn = Texel(dynamicHeight, centeredUV).r;
    float base = Texel(baseHeight, centeredUV).r;
    
    // Mix based on whether dyn is above the threshold
    return mix(base, dyn, step(0.001, dyn)); 
}

extern int NUM_LIGHTS;
extern vec3 lightPos[3]; // World pos (x,y depth)
extern float lightRadius[3]; 
extern float lightIntensity[3];
extern vec3 lightColour[3]; // RGB per-light colour

// Sun (surface) parameters
const vec3 sunColour = vec3(1.0, 0.9, 0.7);     // e.g. vec3(1.0, 0.95, 0.9)
const float sunIntensity = 10.0; // e.g. 10.0
const float sunAngle = 0.0;     // angle in radians from vertical (0 = straight down)
const float sunAtten = 4.0;     // attenuation strength with depth (e.g. 4.0)

const int VOLUME_STEPS = 64; // e.g. 24-64
const float volumeDensity = 2.0; // e.g. 0.8-2.0
const float volumeIntensity = 1.0; // overall strength, e.g. 0.5 
const float volumeJitter = 1.0; // 0.0-1.0 for noise in beams 
extern float refractiveIndex; // e.g. 1.33 for water, 1.5 for rock, 1.0 for air

extern int NUM_SAMPLES;
extern int BOUNCE_STEPS; 
extern int STEPS;

const float HEIGHT_SCALE = 0.5;
const float shadowBrightness = 0.000001; // shadows retain color (not black)
const float bounceStrength = 0.95;
const float bounceDecay = 0.40;
const vec3 waterAbsorption = vec3(0.55, 0.28, 0.1); // R,G,B attenuation rates
const vec3 ambientLight = vec3(0.002, 0.004, 0.008); // abyssal blue ambient

// === Normal Cache ===
// Small cache for local UV samples — avoids redundant normal lookups
const int CACHE_SIZE = 10;
vec2 normalCacheUV[CACHE_SIZE];
vec3 normalCacheVal[CACHE_SIZE];
int normalCacheCount = 0;

bool getCachedNormal(vec2 uv, out vec3 n) {
    for (int i = 0; i < normalCacheCount; i++) {
        // Change number [0.0001 - 0.0005] 
        // Lower number == more samplying (better accuracy)
        if (distance(uv, normalCacheUV[i]) < 0.0005) {
            n = normalCacheVal[i];
            return true;
        }
    }
    return false;
}

void cacheNormal(vec2 uv, vec3 n) {
    if (normalCacheCount < CACHE_SIZE) {
        normalCacheUV[normalCacheCount] = uv;
        normalCacheVal[normalCacheCount] = n;
        normalCacheCount++;
    }
}

vec3 getNormalCached(vec2 uv) {
    vec3 n;
    if (getCachedNormal(uv, n)) return n;

    // offsets (one texel)
    vec2 dx = vec2(heightTexelSize.x, 0.0);
    vec2 dy = vec2(0.0, heightTexelSize.y);

    // 3x3 box blur to reduce high freq
    float h00 = sampleHeight(uv - dx - dy);
    float h10 = sampleHeight(uv        - dy);
    float h20 = sampleHeight(uv + dx - dy);
    float h01 = sampleHeight(uv - dx);
    float h11 = sampleHeight(uv);
    float h21 = sampleHeight(uv + dx);
    float h02 = sampleHeight(uv - dx + dy);
    float h12 = sampleHeight(uv        + dy);
    float h22 = sampleHeight(uv + dx + dy);

    float hx = (h20 + 2.0*h21 + h22) - (h00 + 2.0*h01 + h02); // Sobel X-ish
    float hy = (h02 + 2.0*h12 + h22) - (h00 + 2.0*h10 + h20); // Sobel Y-ish

    vec3 normal = normalize(vec3(hx * HEIGHT_SCALE, hy * HEIGHT_SCALE, 1.0));
    cacheNormal(uv, normal);
    return normal;
}

// Sample some simple "fog density" based on depth (y) and height (z)
float sampleVolumeDensity(vec3 pos) {
    // more scattering near the surface, less in the deep
    float depthFactor = exp(-pos.y * 6.0); // y = 0 top, 1 bottom
    // tiny bit more density near terrain surface
    float h = sampleHeight(pos.xy) * HEIGHT_SCALE;
    float terrainProx = clamp((pos.z - h) * 10.0, 0.0, 1.0);

    return depthFactor * (0.3 + 0.7 * terrainProx); // 0..1-ish
}

// === Utility ===
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

vec3 randomOffset(vec2 seed, float radius) {
    float a = hash(seed) * 6.2831853;
    float r = sqrt(hash(seed * 1.37)) * radius;
    return vec3(cos(a) * r, sin(a) * r, 0.0);
}

// Raymarch along sun direction, accumulating volumetric in-scattering
vec3 computeVolumeScattering(vec3 startPos, vec3 sunDir, float NdotSun) {
    // startPos is your (uv, height) surface position
    vec3 pos = startPos;

    // step in *screen UV* along -sunDir.xy (toward the sun)
    float stepLen = 1.0 / float(VOLUME_STEPS);      // UV step length
    vec2 baseStep = -sunDir.xy * stepLen;

    // jitter to break banding
    float jitter = (hash(startPos.xy * 431.7) - 0.5) * volumeJitter;
    vec2 stepXY = baseStep * (1.0 + jitter * 0.3);

    vec3 accum = vec3(0.0);
    float transmittance = 1.0;  // how much light is left along the ray

    for (int i = 0; i < VOLUME_STEPS; i++) {
        pos.xy += stepXY;

        // left the water / screen
        if (pos.x < 0.0 || pos.x > 1.0 || pos.y < 0.0 || pos.y > 1.0)
            break;

        float h = sampleHeight(pos.xy) * HEIGHT_SCALE;

        // if volume ray goes "behind" terrain, we're in shadow – stop
        if (h > pos.z)
            break;

        float dens = sampleVolumeDensity(pos) * volumeDensity;
        if (dens <= 0.0001) continue;

        // Beer–Lambert transmittance over this segment
        float segmentT = exp(-dens * stepLen * 8.0);
        float scatterAmt = transmittance * (1.0 - segmentT);

        // scale by sun colour & intensity, and NdotSun so beams fade when
        // surface normal isn't facing the sun much
        vec3 scatter = sunColour * sunIntensity * scatterAmt * NdotSun;

        accum += scatter;
        transmittance *= segmentT;

        if (transmittance < 0.01)
            break;
    }

    // VolumeIntensity is just an artistic multiplier
    return accum * volumeIntensity;
}


// === Main Shader === //
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords)
{
    normalCacheCount = 0; // reset per-pixel

    float hgt = sampleHeight(uv) * HEIGHT_SCALE;
    hgt = max(hgt, 0.000001);

    vec3 normal = getNormalCached(uv);
    vec3 surfacePos = vec3(uv, hgt);

    float depth = 1.0 - surfacePos.y;
    float surfaceBright = pow(1.0 - depth, 1.0); // brightest at surface

    vec3 totalLight = vec3(0.0);
    vec3 totalBounce = vec3(0.0);
    float totalShadow = 0.0;

    float importance = clamp(length(lightPos[1].xy - uv) * 2.0, 0.3, 1.0);
    int dynamicSamples = int(float(NUM_SAMPLES) * importance);

    const float EPS = 1e-4;

    // compute sun direction (assume sun is somewhere along top edge, single azimuth = 0)
    vec3 sunDir = normalize(vec3(sin(sunAngle), -cos(sunAngle), 0.0)); 
    // note: y-axis points *down* in your UV system, so -cos(sunAngle) means "from top"

    // surface facing term
    float NdotSun = max(dot(normal, -sunDir), 0.0);

    // exponential attenuation with depth (surfacePos.y is 0..1)
    float sunDepthAtten = exp(-surfacePos.y * sunAtten);

    // spectral absorption across channels (reuse waterAbsorption)
    vec3 sunBll = exp(-waterAbsorption * (surfacePos.y * 3.0));

    // --- Volumetric scattering (sun beams in water column) ---
    vec3 volumeCol = computeVolumeScattering(surfacePos, sunDir, NdotSun);

    // Pre-calculate full, unshadowed sunlight contribution
    vec3 sunLight = sunColour * sunIntensity * NdotSun * sunDepthAtten * sunBll;

    for (int L = 0; L < NUM_LIGHTS; L++) {

        float current_radius = lightRadius[L];
        vec3 current_pos = lightPos[L];
        // Compute per-light importance
        importance = clamp(length(current_pos.xy - uv) * 2.0, 0.3, 1.0);
        dynamicSamples = int(float(NUM_SAMPLES) * importance);

        for (int s = 0; s < dynamicSamples; s++) {

            vec3 jitteredLight = current_pos + randomOffset(uv + float(s), current_radius);
            if (jitteredLight.x < 0.0 || jitteredLight.x > 1.0 ||
                jitteredLight.y < 0.0 || jitteredLight.y > 1.0)
                continue;

            // Calc the scaled difference vec
            vec3 diff = jitteredLight - surfacePos;
            vec2 scaledDiffXY = vec2(diff.x, diff.y * aspectRatioY);

            float pdist_sq = dot(scaledDiffXY, scaledDiffXY) + diff.z * diff.z;
            float pdist = sqrt(pdist_sq);

            vec3 Ldir = normalize(jitteredLight - surfacePos);
            float NdotL = max(dot(normal, Ldir), 0.0);

            // === Spectral Beer–Lambert attenuation ===
            vec3 bll = exp(-waterAbsorption * pdist);

            // === Sunlight color & intensity ===
            float p4 = pdist * pdist * pdist * pdist;
            // PER-LIGHT colour contribution
            vec3 lightCol = 
                 lightColour[L] * 
                 lightIntensity[L] * 
                 bll * NdotL / max(EPS, p4);

            // === Raymarch + bounce ===
            vec3 p = surfacePos;
            int steps = int(mix(STEPS * 0.5, STEPS, NdotL));
            int bounceSteps = int(BOUNCE_STEPS * NdotL);
            vec3 stepDir = (jitteredLight - surfacePos) / float(steps);

            float inShadow = 0.0;
            float bounceLight = 0.0;

            for (int i = 0; i < steps; i++) {
                p += stepDir;

                if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0) break;

                float h = sampleHeight(p.xy) * HEIGHT_SCALE;

                if (h < 0.01) continue;

                // === 2. TERRAIN COLLISION ===
                if (h > p.z) {
                    // === Shadow & bounce logic ===
                    inShadow = 1.0;

                    float cosTheta = clamp(dot(-stepDir, normal), 0.0, 1.0);
                    float R = (1.0 - refractiveIndex) / (1.0 + refractiveIndex);
                    float R0 = R * R;
                    float x = 1.0 - cosTheta;
                    float x2 = x * x;
                    float fresnel = R0 + (1.0 - R0) * (x2 * x2 * x);
                    float eta = 1.0 / refractiveIndex;

                    vec3 localNormal = getNormalCached(p.xy);
                    vec3 incoming = normalize(stepDir);
                    vec3 reflectDir = reflect(incoming, localNormal);
                    vec3 refractDir = refract(incoming, localNormal, eta);
                    vec3 nextDir = mix(refractDir, reflectDir, fresnel);

                    vec3 bouncePos = p;
                    float bounceEnergy = bounceStrength;

                    for (int j = 0; j < bounceSteps; j++) {
                        bouncePos += reflectDir * 0.01;

                        if (bouncePos.x < 0.0 || bouncePos.x > 1.0 ||
                            bouncePos.y < 0.0 || bouncePos.y > 1.0)
                            break;

                        float bh = sampleHeight(bouncePos.xy) * HEIGHT_SCALE;

                        if (bh > bouncePos.z) {
                            bounceEnergy *= bounceDecay;
                            reflectDir = reflect(reflectDir, localNormal);
                        }

                        bounceLight += bounceEnergy * 0.02;
                        bounceEnergy *= bounceDecay;
                        if (bounceEnergy < 0.01) break;
                    }
                    break;
                }
            }

            totalLight  += lightCol;
            totalLight += sunLight;
            totalBounce += bll * bounceLight * ambientLight;
            totalShadow += inShadow;
        }
    }

    vec3 avgLight  = totalLight  / float(dynamicSamples);
    vec3 avgBounce = totalBounce / float(dynamicSamples);
    float avgShadow = totalShadow / float(dynamicSamples);

    vec3 lit = color.rgb * (avgLight + clamp(avgBounce, 0.0, 1.0));

    // Add volumetric contribution on top (not multiplied by surface albedo)
    lit += volumeCol;

    vec3 shadowCol = mix(vec3(0.002, 0.004, 0.006), color.rgb, shadowBrightness);
    float mixVal = avgShadow * (1.0 - length(avgBounce));

    vec3 finalCol = mix(lit, shadowCol, mixVal);

    finalCol += ambientLight * surfaceBright * 1.0;
    finalCol = finalCol / (1.0 + finalCol);
    return vec4(clamp(finalCol, 0.0, 1.0), color.a);
}