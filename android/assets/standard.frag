#ifdef GL_ES
precision mediump float;
#endif

uniform float material_shininess;
uniform vec3 material_diffuse_color;
uniform vec3 material_specular_color;
uniform vec3 material_emissive_color;

uniform vec3 scene_ambient_light;
uniform vec3 scene_light;

uniform vec3 viewSpaceLightPosition;
in vec3 viewSpaceNormal;
in vec3 viewSpacePosition;

uniform sampler2D texture;
uniform int useNormal;
uniform sampler2D normal_texture;
varying vec2 v_texCoord0;


vec3 calculateAmbient(vec3 ambientLight, vec3 materialAmbient){
    return ambientLight * materialAmbient;
}

vec3 calculateDiffuse(vec3 diffuseLight, vec3 materialDiffuse, vec3 normal, vec3 directionToLight) {
    return diffuseLight * materialDiffuse * max(0, dot(normal, directionToLight));
}

vec3 calculateSpecular(vec3 specularLight, vec3 materialSpecular, float materialShininess, vec3 normal, vec3 directionToLight, vec3 directionFromEye) {
    vec3 h = normalize(directionToLight - directionFromEye);
    float normalizationFactor = ((materialShininess + 2.0) / 8.0);
    return specularLight * materialSpecular * pow(max(0, dot(h, normal)), materialShininess) * normalizationFactor;
}

vec3 calculateFresnel(vec3 materialSpecular, vec3 normal, vec3 directionFromEye) {
 return materialSpecular + (vec3(1.0) - materialSpecular) * pow(clamp(1.0 + dot(directionFromEye, normal), 0.0, 1.0), 5.0);
}

void main() {

    // Ambient, Diffuse, Specular, Emissive
    vec3 ambient = material_diffuse_color * texture2D(texture, v_texCoord0).xyz;
    vec3 diffuse = texture2D(texture, v_texCoord0).xyz * material_diffuse_color;
    vec3 specular = material_specular_color;
    vec3 emissive = texture2D(texture, v_texCoord0).xyz * material_emissive_color;

    vec3 normal = normalize(viewSpaceNormal);
    vec3 directionToLight = normalize(viewSpaceLightPosition - viewSpacePosition);
    vec3 directionFromEye = normalize(viewSpacePosition);

    vec3 fresnelSpecular = calculateFresnel(specular, normal,directionFromEye);

    vec3 shading = calculateAmbient(scene_ambient_light, ambient)
        + calculateDiffuse(scene_light, diffuse, normal, directionToLight)
        + calculateSpecular(scene_light, fresnelSpecular, material_shininess, normal, directionToLight, directionFromEye)
        + emissive;

    vec4 fragmentColor = vec4(shading, 1.0);

    gl_FragColor = fragmentColor;
}

