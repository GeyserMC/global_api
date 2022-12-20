use lazy_static::lazy_static;
use rgb::ComponentBytes;
use rustler::NifUnitEnum;

#[derive(PartialEq, Eq, NifUnitEnum)]
pub enum SkinModel {
    Classic,
    Slim,
}

#[derive(PartialEq, Eq)]
pub enum SkinPart {
    Head,
    ArmLeft,
    ArmRight,
    Body,
    LegLeft,
    LegRight,
}

#[derive(PartialEq, Eq, NifUnitEnum)]
pub enum SkinLayer {
    Bottom,
    Top,
    Both,
}

#[derive(PartialEq, Eq)]
pub enum SkinFace {
    Top,
    Bottom,
    Right,
    Front,
    Left,
    Back,
}

pub struct SkinSection<'a>(pub &'a SkinPart, pub SkinLayer);

lazy_static! {
    // we only need the raw content since converted skins will always be 64x64
    pub static ref ALEX_SKIN: Vec<u8> = {
        lodepng::decode32_file("resources/default/skin/alex_slim.png").unwrap().buffer.as_bytes().to_vec()
    };
    pub static ref STEVE_SKIN: Vec<u8> = {
        lodepng::decode32_file("resources/default/skin/steve_classic.png").unwrap().buffer.as_bytes().to_vec()
    };
}
