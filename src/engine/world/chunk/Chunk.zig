const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const world_transform = @import("../world_transform.zig");
const BlockIndex = world_transform.BlockIndex;
const ChunkPosition = world_transform.ChunkPosition;
const RwLock = std.Thread.RwLock;
const CHUNK_LENGTH = world_transform.CHUNK_LENGTH;
const CHUNK_SIZE = world_transform.CHUNK_SIZE;
const BlockStateIndices = @import("BlockStateIndices.zig");
const BlockState = usize;

inner: *anyopaque,

//pub fn init()

pub const Inner = struct {
    const DEFAULT_BLOCK_STATE_CAPACITY = 4;

    _lock: RwLock = .{},
    allocator: Allocator,
    pos: ChunkPosition,
    blockStates: std.ArrayListUnmanaged(BlockState),
    blockStateIndices: BlockStateIndices,
    breakingProgress: ?*std.ArrayListUnmanaged(BlockBreakingProgress) = null,

    fn init(pos: ChunkPosition, allocator: Allocator) Allocator.Error!*Inner {
        const self = try allocator.create(Inner);
        self.* = Inner{
            .allocator = allocator,
            .pos = pos,
            .blockStates = try std.ArrayListUnmanaged(BlockState).initCapacity(allocator, DEFAULT_BLOCK_STATE_CAPACITY),
            .blockStateIndices = try BlockStateIndices.init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Inner) void {
        self.blockStateIndices.deinit(self.allocator);
        self.blockStates.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};

const BlockBreakingProgress = struct {
    progress: f32,
    position: BlockIndex,
};
