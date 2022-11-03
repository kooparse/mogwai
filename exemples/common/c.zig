pub const glfw = @cImport({
    @cDefine("GL_SILENCE_DEPRECATION", "");
    @cDefine("GLFW_INCLUDE_GLCOREARB", "");
    @cInclude("GLFW/glfw3.h");
});
