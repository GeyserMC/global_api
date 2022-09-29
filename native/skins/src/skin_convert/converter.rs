extern crate base64;
extern crate bytes;
extern crate jsonwebtokens;
extern crate lodepng;
extern crate rgb;
extern crate rustler;
extern crate serde_json;
extern crate sha2;

use std::primitive;
use std::str::from_utf8;
use json::JsonValue;

use serde_json::Value;
use crate::skin_convert::converter::SkinModel::{Alex, Steve, Unknown};
use crate::skin_convert::skin_codec::{SKIN_CHANNELS, SKIN_HEIGHT, SKIN_WIDTH, SkinInfo};

const TEXTURE_TYPE_FACE: i64 = 1;

const SKIN_DATA_LENGTH: usize = SKIN_WIDTH * SKIN_HEIGHT * SKIN_CHANNELS;

#[derive(Eq, PartialEq, Debug)]
pub enum SkinModel {
    Unknown = -1,
    Steve = 1,
    Alex = 2,
}

#[derive(Debug)]
struct DimensionAndOffset {
    width: usize,
    height: usize,
    x_offset: usize,
    y_offset: usize,
}

impl DimensionAndOffset {
    // note that width and height are the third and forth arguments instead of the first and second
    fn new(x_offset: usize, y_offset: usize, width: usize, height: usize) -> DimensionAndOffset {
        DimensionAndOffset { width, height, x_offset, y_offset }
    }
}

pub fn get_skin_or_convert_geometry(info: SkinInfo, client_claims: &Value) -> Result<(Vec<u8>, bool), &str> {
    let skin_width = info.skin_width;

    if info.needs_convert && (skin_width > 0 && !info.raw_skin_data.is_empty()) {
        match convert_geometry(
            &info.raw_skin_data, skin_width, client_claims,
            info.geometry_data, &info.geometry_patch, info.geometry_name.as_str(),
        ) {
            Err(err) => Err(err),
            Ok((raw_data, skin_model)) =>
            // fallback to Steve if model can't be found
                Ok((raw_data, skin_model != Alex)),
        }
    } else {
        let is_steve = !info.geometry_name.ends_with("Slim");
        // we still have to scale even though we technically don't have to convert them
        if info.raw_skin_data.len() != SKIN_DATA_LENGTH {
            let mut new_vec: Vec<u8> = vec![0; SKIN_DATA_LENGTH];

            let source = DimensionAndOffset {
                width: skin_width,
                height: info.raw_skin_data.len() / SKIN_CHANNELS / skin_width,
                x_offset: 0,
                y_offset: 0,
            };

            let target = DimensionAndOffset {
                width: SKIN_WIDTH,
                height: SKIN_HEIGHT,
                x_offset: 0,
                y_offset: 0,
            };

            // apparently some people have an empty skin so yeah
            if info.skin_width > 0 && !info.raw_skin_data.is_empty() {
                fill_and_scale_texture(info.raw_skin_data.as_slice(), &mut new_vec, skin_width, SKIN_WIDTH, &source, &target);
            }

            return Ok((new_vec, is_steve));
        }
        Ok((info.raw_skin_data, is_steve))
    }
}

fn convert_geometry<'a>(skin_data: &'a [u8], mut skin_width: usize, client_claims: &'a Value, geometry_data: Vec<u8>, geometry_patch: &'a JsonValue, geometry_name: &'a str) -> Result<(Vec<u8>, SkinModel), &'static str> {
    let geometry_data_string = from_utf8(geometry_data.as_slice());
    if geometry_data_string.is_err() {
        return Err("invalid utf-8 data");
    }
    let json = json::parse(geometry_data_string.unwrap());
    if json.is_err() {
        return Err("invalid json");
    }

    let json = json.unwrap();

    let format_version_opt = json["format_version"].as_str();
    if format_version_opt.is_none() {
        return Err("geometry data doesn't have a valid format version");
    }

    let format_version = format_version_opt.unwrap();

    let (geometry_entry, tex_width, tex_height) = get_correct_entry(format_version, &json, geometry_name)?;

    let skin_height = skin_data.len() / SKIN_CHANNELS / skin_width;

    let mut accurate_skin_data: Vec<u8>;
    let accurate_skin: &[u8];

    if skin_width != tex_width || skin_height != tex_height {
        // we have to scale the skin data to what the geometry says

        accurate_skin_data = vec![0; tex_width * tex_height * SKIN_CHANNELS];

        fill_and_scale_texture(
            skin_data,
            &mut accurate_skin_data,
            skin_width,
            tex_width,
            &DimensionAndOffset {
                width: skin_width,
                height: skin_height,
                x_offset: 0,
                y_offset: 0
            },
            &DimensionAndOffset {
                width: tex_width,
                height: tex_height,
                x_offset: 0,
                y_offset: 0
            }
        );

        accurate_skin = accurate_skin_data.as_slice();
        skin_width = tex_width
    } else {
        accurate_skin = skin_data;
    }

    let bones = &geometry_entry["bones"];
    if bones.is_null() {
        return Err("geometry data doesn't have any bones");
    }
    if !bones.is_array() {
        return Err("bones isn't an array");
    }

    let mut new_vec: Vec<u8> = vec![0; SKIN_DATA_LENGTH];

    let mut skin_model: SkinModel = Unknown;

    for bone in bones.members() {
        match translate_bone(accurate_skin, skin_width, bone, false, &mut new_vec) {
            Err(err) => return Err(err),
            Ok(model) => {
                if skin_model == Unknown {
                    skin_model = model
                }
            }
        };
    }

    // lets check (and translate it) if the skin also has an animated head

    let animated_face = &geometry_patch["animated_face"];
    if animated_face.is_string() {
        let animated_face = animated_face.as_str();
        if animated_face.is_none() {
            return Err("animated face name is not a string");
        }

        let animated_frames = client_claims.get("AnimatedImageData");
        if animated_frames.is_none() {
            return Err("animated image data has to be present");
        }
        let animated_frames = animated_frames.unwrap().as_array();
        if animated_frames.is_none() {
            return Err("animated image data has to be an array");
        }
        let animated_frames = animated_frames.unwrap();
        if animated_frames.is_empty() {
            return Err("no animated frames were found");
        }

        // we can't assume that the first entry always is the head
        // so we have to find the head
        let mut face_frame = None;

        for animated_frame in animated_frames {
            let animation_type = animated_frame.get("Type");
            if animation_type.is_none() {
                return Err("animation frame doesn't have a type");
            }

            let animation_type = animation_type.unwrap().as_i64();
            if animation_type.is_none() {
                return Err("animation frame type is not an int");
            }

            if animation_type.unwrap() == TEXTURE_TYPE_FACE {
                face_frame = Some(animated_frame);
            }
        }

        if face_frame.is_none() {
            return Err("geometry did have an animated face, but the animation frame doesn't");
        }
        let face_frame: &Value = face_frame.unwrap();
        // we found the face :)

        let face_width = face_frame.get("ImageWidth");
        let face_height = face_frame.get("ImageHeight");
        if face_width.is_none() || face_height.is_none() {
            return Err("animated frame doesn't have a predefined width and height");
        }
        let face_width = face_width.unwrap().as_i64();
        let face_height = face_height.unwrap().as_i64();
        if face_width.is_none() || face_height.is_none() {
            return Err("animated frame width or height isn't an int");
        }
        let face_width = face_width.unwrap() as usize;
        let face_height = face_height.unwrap() as usize;

        let face_data = face_frame.get("Image");
        if face_data.is_none() {
            return Err("animated frame doesn't have image data");
        }
        let face_data = face_data.unwrap().as_str();
        if face_data.is_none() {
            return Err("animated frame image isn't a string");
        }
        let face_data = base64::decode(face_data.unwrap());
        if face_data.is_err() {
            return Err("animated frame image is invalid base64");
        }
        let face_data = face_data.unwrap();

        if face_data.len() != face_width * face_height * SKIN_CHANNELS {
            return Err("animated frame image has an incorrect length");
        }

        let (geometry_entry, tex_width, tex_height) = get_correct_entry(format_version, &json, animated_face.unwrap())?;

        if tex_width != face_width || tex_height != face_height {
            return Err("the image width and height doesn't match the geometry data width and height");
        }

        let bones = &geometry_entry["bones"];
        if !bones.is_array() || bones.is_empty() {
            return Err("geometry data doesn't have bones");
        }

        for bone in bones.members() {
            let model_or_err = translate_bone(face_data.as_slice(), face_width, bone, true, &mut new_vec);
            if let Err(err) = model_or_err {
                return Err(err);
            }
        }
    }

    Ok((new_vec, skin_model))
}

fn get_correct_entry<'a>(format_version: &'a str, geometry_data: &'a JsonValue, geometry_name: &'a str) -> Result<(&'a JsonValue, usize, usize), &'static str> {
    match format_version {
        "1.8.0" => {
            let geometry_data = &geometry_data[geometry_name];

            let texture_width = geometry_data["texturewidth"].as_f64()
                .ok_or("geometry entry's texture width is not a number")?;
            let texture_height = geometry_data["textureheight"].as_f64()
                .ok_or("geometry entry's texture height is not a number")?;

            if texture_width <= 0.0 || texture_height <= 0.0 {
                return Err("texture width and height needs to be > 0")
            }

            Ok((geometry_data, texture_width as usize, texture_height as usize))
        }
        "1.12.0" | "1.14.0" => {
            let geometry_data = &geometry_data["minecraft:geometry"];

            for entry in geometry_data.members() {
                let description = &entry["description"];

                let identifier = description["identifier"].as_str()
                    .ok_or("geometry entry does not have an identifier")?;

                if identifier.eq(geometry_name) {
                    let texture_width = description["texture_width"].as_f64()
                        .ok_or("geometry entry's texture width is not a number")?;
                    let texture_height = description["texture_height"].as_f64()
                        .ok_or("geometry entry's texture height is not a number")?;

                    if texture_width <= 0.0 || texture_height <= 0.0 {
                        return Err("texture width and height needs to be > 0")
                    }

                    return Ok((entry, texture_width as usize, texture_height as usize));
                }
            }
            Err("geometry with given identifier wasn't found")
        }
        _ => Err("unknown/unsupported geometry format version")
    }
}

fn translate_cubed_bone(skin_data: &[u8], w: usize, name: &str, position: DimensionAndOffset, cubes: &JsonValue, new_vec: &mut Vec<u8>) -> Result<SkinModel, &'static str> {
    let cube = &cubes[0];

    let size = &cube["size"];
    if !size.is_array() || size.len() != 3 {
        return Err("bone doesn't have a valid size");
    }

    let tex_size = size_to_tex_size(size);
    if tex_size.is_none() {
        return Err("failed converting size to texture size");
    }
    let (skin_model, tex_width, tex_height) = tex_size.unwrap();

    let uv = &cube["uv"];
    if uv.is_null() {
        return Err("cube doesn't have uv");
    }

    // temp pos
    let result = if skin_model != Unknown && (name.eq_ignore_ascii_case("leftArm") || name.eq_ignore_ascii_case("rightArm")) {
        skin_model
    } else {
        Unknown
    };

    // temp 'fix'
    // todo find out why we aren't doing anything when uv is an object
    if uv.is_object() {
        return Ok(result);
    }

    if !uv.is_array() {
        return Err("cube's uv isn't an array")
    }

    let offset = get_bone_offset(uv);
    if offset.is_none() {
        return Err("failed to get bone offset");
    }
    let (x_offset, y_offset) = offset.unwrap();

    let source = DimensionAndOffset {
        width: tex_width,
        height: tex_height,
        x_offset,
        y_offset,
    };

    fill_and_scale_texture(skin_data, new_vec, w, SKIN_WIDTH, &source, &position);

    Ok(result)
}

fn fill_and_scale_texture(skin_data: &[u8], new_vec: &mut Vec<u8>, skin_data_width: usize, new_width: usize, source: &DimensionAndOffset, target: &DimensionAndOffset) {
    if target.width >= source.width || target.height >= source.height {
        // fill
        for x in 0..source.width {
            for y in 0..source.height {
                for i in 0..SKIN_CHANNELS {
                    let val = skin_data[((source.y_offset + y) * skin_data_width + source.x_offset + x) * SKIN_CHANNELS + i];
                    new_vec[((target.y_offset + y) * new_width + target.x_offset + x) * SKIN_CHANNELS + i] = val;
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

        // average x_scale x y_scale pixels

        for x in 0..target.width {
            for y in 0..target.height {
                for i in 0..SKIN_CHANNELS {
                    let mut total: usize = 0;

                    let source_x = x + source.x_offset;
                    let source_y = y + source.y_offset;
                    for x_channel_sample in 0..x_scale {
                        for y_channel_sample in 0..y_scale {
                            let source_x = source_x * x_scale + x_channel_sample;
                            let source_y = source_y * y_scale + y_channel_sample;

                            total += skin_data[(source_y * skin_data_width + source_x) * SKIN_CHANNELS + i] as usize;
                        }
                    }
                    new_vec[((target.y_offset + y) * new_width + target.x_offset + x) * SKIN_CHANNELS + i] = (total / (x_scale * y_scale)) as u8;
                }
            }
        }
    }
}

fn translate_poly_bone(skin_data: &[u8], w: usize, name: &str, position: DimensionAndOffset, poly_mesh: &JsonValue, new_vec: &mut Vec<u8>) -> Result<SkinModel, &'static str> {
    let is_normalized = poly_mesh["normalized_uvs"].as_bool().unwrap_or(false);

    let polys = &poly_mesh["polys"];
    if polys.is_null() {
        return Err("bone doesn't have polys");
    }
    if !polys.is_array() {
        return Err("polys field isn't an array");
    }

    let normals = &poly_mesh["normals"];
    if normals.is_null() {
        return Err("bone doesn't have normals");
    }
    if !normals.is_array() {
        return Err("normals aren't an array");
    }

    if polys.len() != normals.len() {
        return Err("polys and normals should have the same length");
    }

    let uvs = &poly_mesh["uvs"];
    if uvs.is_null() {
        return Err("bone doesn't have uvs");
    }
    if !uvs.is_array() {
        return Err("uvs aren't an array");
    }

    if polys.is_empty() || uvs.is_empty() {
        return Err("cannot translate empty geometry");
    }

    // we should be able to get the texture size by just looping through the uvs values
    // and pick the highest and lowest entries of those values

    let h = skin_data.len() / SKIN_CHANNELS / w;

    let w_f = w as f64;
    let h_f = h as f64;

    let mut lowest_u = w_f;
    let mut highest_u = 0 as f64;
    let mut lowest_v = h_f;
    let mut highest_v = 0 as f64;

    for uv in uvs.members() {
        if !uv.is_array() {
            return Err("invalid uv data");
        }
        if uv.len() != 2 {
            return Err("invalid uv entry length");
        }

        let u = uv[0].as_f64();
        let v = uv[1].as_f64();
        if u.is_none() || v.is_none() {
            return Err("invalid uv entry data");
        }

        let mut u = u.unwrap();
        let mut v = v.unwrap();

        if is_normalized {
            u *= w_f;
            v *= h_f;
        }

        if u > w_f || v > h_f || u < 0.0 || v < 0.0 {
            return Err("uvs contains an out of bounds entry");
        }

        lowest_u = lowest_u.min(u);
        highest_u = highest_u.max(u);
        lowest_v = lowest_v.min(v);
        highest_v = highest_v.max(v);
    }


    let tex_width = (highest_u - lowest_u) as usize;
    let tex_height = (highest_v - lowest_v) as usize;

    let x_offset = lowest_u.floor() as usize;
    let y_offset = (h_f - highest_v).floor() as usize;

    let source = DimensionAndOffset {
        width: tex_width,
        height: tex_height,
        x_offset,
        y_offset,
    };

    //todo impl mirroring
    fill_and_scale_texture(skin_data, new_vec, w, SKIN_WIDTH, &source, &position);

    //todo check
    let skin_model = match tex_width {
        18 => Alex,
        20 => Steve,
        _ => Unknown
    };

    let result = if skin_model != Unknown && (name.eq_ignore_ascii_case("leftArm") || name.eq_ignore_ascii_case("rightArm")) {
        skin_model
    } else {
        Unknown
    };

    Ok(result)
}

fn translate_bone(skin_data: &[u8], w: usize, bone: &JsonValue, only_face: bool, new_vec: &mut Vec<u8>) -> Result<SkinModel, &'static str> {
    let name = bone["name"].as_str();
    if name.is_none() {
        return Err("bone doesn't have a name");
    }
    let name = name.unwrap();

    if only_face {
        // only translate the face
        if !"hat".eq(name) && !"head".eq(name) {
            return Ok(Unknown);
        }
    }

    let result = get_texture_offset(name);
    // we don't have to map every bone, and bones that we don't have to map have are: 0, 1
    if result.is_none() {
        return Ok(Unknown);
    }
    let position = result.unwrap();

    // lets check if it is a cubed bone or a poly bone

    let cubes = &bone["cubes"];
    if !cubes.is_null() {
        if !cubes.is_array() {
            return Err("cubes isn't an array");
        }
        if cubes.is_empty() {
            return Ok(Unknown); // apparently empty cubes is valid :shrug:
        }
        return translate_cubed_bone(skin_data, w, name, position, cubes, new_vec);
    }

    let poly_mesh = &bone["poly_mesh"];
    if !poly_mesh.is_null() {
        return translate_poly_bone(skin_data, w, name, position, poly_mesh, new_vec);
    }

    // not every bone has cubes nor a poly mesh
    Ok(Unknown)
}

fn get_bone_offset(uv: &JsonValue) -> Option<(usize, usize)> {
    if uv.len() != 2 {
        return None;
    }
    Some((uv[0].as_f64()? as usize, uv[1].as_f64()? as usize))
}

fn size_to_tex_size(size: &JsonValue) -> Option<(SkinModel, usize, usize)> {
    let width = size[0].as_f64()?;
    let height = size[1].as_f64()?;
    let depth = size[2].as_f64()?;

    let skin_model = match width.ceil() as i32 {
        3 => Alex,
        4 => Steve,
        _ => Unknown
    };

    Some((skin_model, ((depth * 2.0) + (width * 2.0)) as usize, (depth + height).round() as usize))
}

fn get_texture_offset(bone_name: &primitive::str) -> Option<DimensionAndOffset> {
    let new = DimensionAndOffset::new;
    // start x, start y, width, height
    match bone_name {
        "body" => Some(new(16, 16, 24, 16)),
        "head" => Some(new(0, 0, 32, 16)),
        "hat" => Some(new(32, 0, 32, 16)),
        "leftArm" | "leftarm" => Some(new(32, 48, 16, 16)),
        "rightArm" | "rightarm" => Some(new(40, 16, 16, 16)),
        "leftSleeve" | "leftsleeve" => Some(new(48, 48, 16, 16)),
        "rightSleeve" | "rightsleeve" => Some(new(40, 32, 16, 16)),
        "leftLeg" | "leftleg" => Some(new(16, 48, 16, 16)),
        "rightLeg" | "rightleg" => Some(new(0, 16, 16, 16)),
        "leftPants" | "leftpants" => Some(new(0, 48, 16, 16)),
        "rightPants" | "rightpants" => Some(new(0, 32, 16, 16)),
        "jacket" => Some(new(16, 32, 24, 16)),
        _ => None,
    }
}
