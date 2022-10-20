use rustler::NifUnitEnum;

#[derive(PartialEq, Eq, NifUnitEnum)]
pub enum SkinModel {
    Classic,
    Slim
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
