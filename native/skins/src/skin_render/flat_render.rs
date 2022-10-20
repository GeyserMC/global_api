use image::RgbaImage;
use crate::common::{Offset, OffsetAndDimension};
use crate::common::skin::{SkinFace, SkinLayer, SkinModel, SkinPart, SkinSection};
use crate::common::texture::{scale_and_fill_texture, texture_position, texture_position_face};

pub fn render_front(data: &[u8], data_width: usize, layer: &SkinLayer, model: &SkinModel, target_width: usize) -> RgbaImage {
    let scale = (target_width - (target_width % 16)) / 16;

    let mut target = RgbaImage::new((16 * scale) as u32, (32 * scale) as u32);

    render_face(
        &SkinPart::Head, layer, &SkinFace::Front, model,
        data, data_width, &mut target,
    &Offset::new(4, 0), scale
    );

    render_face(
        &SkinPart::ArmRight, layer, &SkinFace::Front, model,
        data, data_width, &mut target,
    &Offset::new(if model == &SkinModel::Classic { 0 } else { 1 }, 8), scale
    );
    render_face(
        &SkinPart::Body, layer, &SkinFace::Front, model,
        data, data_width, &mut target,
    &Offset::new(4, 8), scale
    );
    render_face(
        &SkinPart::ArmLeft, layer, &SkinFace::Front, model,
        data, data_width, &mut target,
    &Offset::new(12, 8), scale
    );

    render_face(
        &SkinPart::LegRight, layer, &SkinFace::Front, model,
        data, data_width, &mut target,
    &Offset::new(4, 20), scale
    );
    render_face(
        &SkinPart::LegLeft, layer, &SkinFace::Front, model,
        data, data_width, &mut target,
    &Offset::new(8, 20), scale
    );

    target
}

pub(crate) fn render_section(
    section: SkinSection,
    data: &[u8],
    data_width: usize,
    target: &mut RgbaImage,
    target_offset: &Offset,
    target_scale: usize
) {
    if section.1 == SkinLayer::Both {
        let skin_part = section.0;
        render_section(
            SkinSection(skin_part, SkinLayer::Bottom),
            data, data_width, target, target_offset, target_scale
        );
        render_section(
            SkinSection(skin_part, SkinLayer::Top),
            data, data_width, target, target_offset, target_scale
        );
        return;
    }

    if let Some(position) = texture_position(section) {
        render_position(data, data_width, &position, target, target_offset, target_scale)
    }
}

fn render_face(
    part: &SkinPart,
    layer: &SkinLayer,
    face: &SkinFace,
    model: &SkinModel,
    data: &[u8],
    data_width: usize,
    target: &mut RgbaImage,
    target_offset: &Offset,
    target_scale: usize
) {
    if layer == &SkinLayer::Both {
        render_face(part, &SkinLayer::Bottom, face, model, data, data_width, target, target_offset, target_scale);
        render_face(part, &SkinLayer::Top, face, model, data, data_width, target, target_offset, target_scale);
        return;
    }

    if let Some(position) = texture_position_face(part, layer, face, model) {
        render_position(data, data_width, &position, target, target_offset, target_scale)
    }
}

/// the target_offset is the offset without the target_scale
/// target_offset will be multiplied by target_scale in the method
fn render_position(
    data: &[u8],
    data_width: usize,
    data_position: &OffsetAndDimension,
    target: &mut RgbaImage,
    target_offset: &Offset,
    target_scale: usize
) {
    let width = target.width() as usize;
    let height = target.height() as usize;

    if target_scale == 0 {
        return;
    }

    let target_position = OffsetAndDimension {
        x_offset: target_offset.x_offset * target_scale,
        y_offset: target_offset.y_offset * target_scale,
        width: width * target_scale,
        height: height * target_scale,
    };

    scale_and_fill_texture(data, target, data_width, width, data_position, &target_position);
}