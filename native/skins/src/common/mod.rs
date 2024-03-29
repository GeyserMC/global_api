use rustler::NifTuple;

pub mod geometry;
pub mod skin;
pub mod texture;

pub const RGBA_CHANNELS: usize = 4;

#[derive(NifTuple)]
pub struct Dimension {
    pub width: usize,
    pub height: usize,
}

pub struct Offset {
    pub x_offset: usize,
    pub y_offset: usize,
}

#[derive(Debug)]
pub struct OffsetAndDimension {
    pub x_offset: usize,
    pub y_offset: usize,
    pub width: usize,
    pub height: usize,
}

impl OffsetAndDimension {
    pub fn new(x_offset: usize, y_offset: usize, width: usize, height: usize) -> OffsetAndDimension {
        OffsetAndDimension { x_offset, y_offset, width, height }
    }
}

impl Offset {
    pub fn new(x_offset: usize, y_offset: usize) -> Offset {
        Offset { x_offset, y_offset }
    }
}
