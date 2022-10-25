use crate::common::{OffsetAndDimension, RGBA_CHANNELS};
use crate::common::skin::{SkinFace, SkinLayer, SkinModel, SkinPart, SkinSection};

pub fn texture_position(section: SkinSection) -> Option<OffsetAndDimension> {
    // start x, start y, width, height
    let new = OffsetAndDimension::new;
    match section {
        SkinSection(SkinPart::Head, SkinLayer::Bottom) => Some(new(0, 0, 32, 16)),
        SkinSection(SkinPart::Head, SkinLayer::Top) => Some(new(32, 0, 32, 16)),
        SkinSection(SkinPart::ArmLeft, SkinLayer::Bottom) => Some(new(32, 48, 16, 16)),
        SkinSection(SkinPart::ArmLeft, SkinLayer::Top) => Some(new(48, 48, 16, 16)),
        SkinSection(SkinPart::Body, SkinLayer::Bottom) => Some(new(16, 16, 24, 16)),
        SkinSection(SkinPart::Body, SkinLayer::Top) => Some(new(16, 32, 24, 16)),
        SkinSection(SkinPart::ArmRight, SkinLayer::Bottom) => Some(new(40, 16, 16, 16)),
        SkinSection(SkinPart::ArmRight, SkinLayer::Top) => Some(new(40, 32, 16, 16)),
        SkinSection(SkinPart::LegLeft, SkinLayer::Bottom) => Some(new(16, 48, 16, 16)),
        SkinSection(SkinPart::LegLeft, SkinLayer::Top) => Some(new(0, 48, 16, 16)),
        SkinSection(SkinPart::LegRight, SkinLayer::Bottom) => Some(new(0, 16, 16, 16)),
        SkinSection(SkinPart::LegRight, SkinLayer::Top) => Some(new(0, 32, 16, 16)),
        _ => None
    }
}

#[inline(never)]
pub fn texture_position_face(part: &SkinPart, layer: &SkinLayer, face: &SkinFace, model: &SkinModel)
    -> Option<OffsetAndDimension> {

    let mut width: usize;
    let height: usize;
    let mut x_offset: usize = 0;
    let mut y_offset: usize = 0;

    // head is 8x8
    if part == &SkinPart::Head {
        width = 8;
        height = 8;
        match face {
            SkinFace::Top => x_offset = 8,
            SkinFace::Bottom => x_offset = 16,
            SkinFace::Right => y_offset = 8,
            SkinFace::Front => {
                x_offset = 8;
                y_offset = 8;
            }
            SkinFace::Left => {
                x_offset = 16;
                y_offset = 8;
            }
            SkinFace::Back => {
                x_offset = 24;
                y_offset = 8;
            }
        }

        if layer == &SkinLayer::Top {
            x_offset += 32;
        }

    } else if part == &SkinPart::Body {
        if face == &SkinFace::Left || face == &SkinFace::Right {
            x_offset = if face == &SkinFace::Left { 16 } else { 28 };
            y_offset = 20;
            width = 4;
            height = 12;
        } else {
            width = 8;
            if face == &SkinFace::Top || face == &SkinFace::Bottom {
                x_offset = if face == &SkinFace::Top { 20 } else { 28 };
                y_offset = 16;
                height = 4;
            } else {
                x_offset = if face == &SkinFace::Front { 20 } else { 32 };
                y_offset = 20;
                height = 12;
            }
        }

        if layer == &SkinLayer::Top {
            y_offset += 16;
        }

    } else {
        // right arm, left arm, right leg, left leg
        width = 4;
        height = if face == &SkinFace::Top || face == &SkinFace::Bottom { 4 } else { 12 };

        if part == &SkinPart::LegRight || part == &SkinPart::LegLeft {
            if face == &SkinFace::Top || face == &SkinFace::Bottom {
                y_offset = 16;
                x_offset = if face == &SkinFace::Top { 4 } else { 8 };
            } else {
                y_offset = 20;
                match face {
                    SkinFace::Right => {},
                    SkinFace::Front => x_offset = 4,
                    SkinFace::Left => x_offset = 8,
                    SkinFace::Back => x_offset = 12,
                    _ => panic!()
                }
            }

            // right leg to left leg
            if part == &SkinPart::LegLeft {
                x_offset += 16;
                y_offset += 32;
            }
        } else {
            // right arm, left arm
            let arm_width = if model == &SkinModel::Classic { 4 } else { 3 };

            if face == &SkinFace::Top || face == &SkinFace::Bottom {
                x_offset = 44;
                if face == &SkinFace::Bottom { x_offset += arm_width };
                y_offset = 16;
                width = arm_width;
            } else {
                x_offset = 40;
                y_offset = 20;
                match face {
                    SkinFace::Right => {},
                    SkinFace::Front => {
                        x_offset += 4;
                        width = arm_width
                    },
                    SkinFace::Left => x_offset += 4 + arm_width,
                    SkinFace::Back => {
                        x_offset += 4 + arm_width;
                        width = arm_width
                    },
                    _ => panic!()
                }
            }

            // right arm to left arm
            if part == &SkinPart::ArmLeft {
                x_offset -= 8;
                y_offset += 32;
            }
        }

        if layer == &SkinLayer::Top {
            if part == &SkinPart::ArmLeft {
                x_offset += 16;
            } else if part == &SkinPart::LegLeft {
                x_offset -= 16;
            } else {
                // right arm, right leg
                y_offset += 16;
            }
        }
    }

    Some(OffsetAndDimension { x_offset, y_offset, width, height })
}


pub fn scale_and_fill_texture(source_data: &[u8], target_data: &mut [u8], source_width: usize, target_width: usize, source: &OffsetAndDimension, target: &OffsetAndDimension) {
    //todo uncomment and place fill in statement when fill will be replaced with upscale
    // if target.width == source.width && target.height == source.height {
    //     return;
    // }

    if target.width >= source.width || target.height >= source.height {
        // fill
        for x in 0..source.width {
            for y in 0..source.height {
                for i in (0..RGBA_CHANNELS).rev() {
                    let val = source_data[((source.y_offset + y) * source_width + source.x_offset + x) * RGBA_CHANNELS + i];

                    if i == RGBA_CHANNELS - 1 && val == 0 {
                        // alpha channel comes first,
                        // we don't need to handle all the other channels if alpha is 0
                        break;
                    }

                    target_data[((target.y_offset + y) * target_width + target.x_offset + x) * RGBA_CHANNELS + i] = val;
                }
            }
        }

        //todo should fill be replaced with upscale when the source's width/height doesn't match
        // the target's width/height?
        //
        // let x_scale = source.width as f32 / target.width as f32;
        // let y_scale = source.height as f32 / target.height as f32;
        // for x in 0..target.width {
        //     for y in 0..target.height {
        //         let x1 = (((x + source.x_offset) as f32 + 0.5) * x_scale).floor() as usize;
        //         let y1 = (((y + source.y_offset) as f32 + 0.5) * y_scale).floor() as usize;
        //         for i in 0..SKIN_CHANNELS {
        //             let pixel = skin_data[(y1 * skin_data_width + x1) * SKIN_CHANNELS + i];
        //             new_vec[((target.y_offset + y) * new_width + target.x_offset + x) * SKIN_CHANNELS + i] = pixel
        //         }
        //     }
        // }

    } else {
        // downscale
        let x_scale = source.width / target.width;
        let y_scale = source.height / target.height;
        let sample_count = x_scale * y_scale;

        // average x_scale x y_scale pixels

        for x in 0..target.width {
            for y in 0..target.height {
                for i in (0..RGBA_CHANNELS).rev() {
                    let mut total: usize = 0;

                    let source_x = x + source.x_offset;
                    let source_y = y + source.y_offset;
                    for x_channel_sample in 0..x_scale {
                        for y_channel_sample in 0..y_scale {
                            let source_x = source_x * x_scale + x_channel_sample;
                            let source_y = source_y * y_scale + y_channel_sample;

                            total += source_data[(source_y * source_width + source_x) * RGBA_CHANNELS + i] as usize;
                        }
                    }

                    let average = total / sample_count;

                    if i == RGBA_CHANNELS - 1 && average == 0 {
                        // alpha channel comes first,
                        // we don't need to handle all the other channels if alpha is 0
                        break;
                    }

                    //todo should probably use the average of the already existing pixel
                    // if it has any. At the moment it's just overridden

                    target_data[((target.y_offset + y) * target_width + target.x_offset + x) * RGBA_CHANNELS + i] = average as u8;
                }
            }
        }
    }
}

