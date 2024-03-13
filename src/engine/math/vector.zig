const std = @import("std");

pub const Vector2 = @import("detail/vector2.zig").Vector2;
pub const Vector3 = @import("detail/vector3.zig").Vector3;
pub const Vector4 = @import("detail/vector4.zig").Vector4;

/// 3 component 32 bit float vector. Same layout as GLSL `vec3` type.
pub const Vec3f = Vector3(f32);
/// 3 component 64 bit float vector. Same layout as GLSL `dvec3` type.
/// See `WorldPosition.fromVector()` to convert to world coordinates
pub const Vec3d = Vector3(f64);
/// 3 component 32 bit signed integer vector. Same layout as GLSL `ivec3` type.
pub const Vec3i = Vector3(i32);
/// 3 component 32 bit unsigned integer vector. Same layout as GLSL `uvec3` type.
pub const Vec3u = Vector3(u32);
