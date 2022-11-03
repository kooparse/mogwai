#version 330 core
out vec4 FragColor;

in vec2 TexCoord;
in vec3 MeshColor;

uniform vec4 color;
uniform bool with_color;

void main() {
    vec4 c = color;

    if (with_color) {
        c = vec4(MeshColor, 1);
    } 

    FragColor = c;
}
