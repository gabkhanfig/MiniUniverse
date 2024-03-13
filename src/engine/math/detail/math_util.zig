pub fn isSignedInt(comptime T: type) bool {
    const typeInfo = @typeInfo(T);
    switch (typeInfo) {
        .Int => {
            return typeInfo.Int.signedness == .signed;
        },
        else => {
            return false;
        },
    }
}
