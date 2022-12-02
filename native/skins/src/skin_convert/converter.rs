extern crate base64;
extern crate jsonwebtokens;
extern crate lodepng;
extern crate rgb;
extern crate rustler;
extern crate serde_json;
extern crate sha2;

use std::primitive;
use std::str::from_utf8;
use std::sync::MutexGuard;
use json::JsonValue;

use serde_json::Value;
use crate::SkinModel;
use crate::common::OffsetAndDimension;
use crate::common::geometry::BoneType;
use crate::common::skin::{SkinLayer, SkinPart, SkinSection};
use crate::common::texture::{scale_and_fill_texture, texture_position};
use crate::skin_convert::skin_codec::{SKIN_CHANNELS, SKIN_HEIGHT, SKIN_WIDTH, SkinInfo};
use crate::SkinModel::{Classic, Slim};

const TEXTURE_TYPE_FACE: i64 = 1;

const SKIN_DATA_LENGTH: usize = SKIN_WIDTH * SKIN_HEIGHT * SKIN_CHANNELS;

pub fn get_skin_or_convert_geometry(info: SkinInfo, client_claims: &Value) -> Result<(Vec<u8>, bool), &'static str> {
    let skin_width = info.skin_width;

    if info.needs_convert && (skin_width > 0 && !info.raw_skin_data.is_empty()) {
        match convert_geometry(
            &info.raw_skin_data, skin_width, client_claims,
            &info.geometry_data, &info.geometry_patch, info.geometry_name.as_str(),
        ) {
            Err(err) => Err(err),
            Ok((raw_data, skin_model)) =>
            // fallback to Steve if model can't be found
                Ok((raw_data, skin_model != Some(Slim))),
        }
    } else {
        let is_steve = !info.geometry_name.ends_with("Slim");
        // we still have to scale even though we technically don't have to convert them
        if info.raw_skin_data.len() != SKIN_DATA_LENGTH {
            let mut new_vec: Vec<u8> = vec![0; SKIN_DATA_LENGTH];

            let source = OffsetAndDimension {
                x_offset: 0,
                y_offset: 0,
                width: skin_width,
                height: info.raw_skin_data.len() / SKIN_CHANNELS / skin_width,
            };

            let target = OffsetAndDimension {
                x_offset: 0,
                y_offset: 0,
                width: SKIN_WIDTH,
                height: SKIN_HEIGHT,
            };

            // apparently some people have an empty skin so yeah
            if info.skin_width > 0 && !info.raw_skin_data.is_empty() {
                scale_and_fill_texture(&info.raw_skin_data, &mut new_vec, skin_width, SKIN_WIDTH, &source, &target);
            }

            return Ok((new_vec, is_steve));
        }
        Ok((info.raw_skin_data, is_steve))
    }
}

fn convert_geometry(skin_data: &[u8], mut skin_width: usize, client_claims: &Value, geometry_data: &[u8], geometry_patch: &JsonValue, geometry_name: &str) -> Result<(Vec<u8>, Option<SkinModel>), &'static str> {
    let geometry_data_string = from_utf8(geometry_data);
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

        scale_and_fill_texture(
            skin_data,
            &mut accurate_skin_data,
            skin_width,
            tex_width,
            &OffsetAndDimension {
                x_offset: 0,
                y_offset: 0,
                width: skin_width,
                height: skin_height,
            },
            &OffsetAndDimension {
                x_offset: 0,
                y_offset: 0,
                width: tex_width,
                height: tex_height,
            }
        );

        accurate_skin = accurate_skin_data.as_slice();
        skin_width = tex_width
    } else {
        accurate_skin = skin_data;
    }

    on_start_convert(client_claims, &json, geometry_patch);
    on_change_geometry(geometry_name, geometry_entry, accurate_skin, skin_width);

    let bones = &geometry_entry["bones"];
    if bones.is_null() {
        return Err("geometry data doesn't have any bones");
    }
    if !bones.is_array() {
        return Err("bones isn't an array");
    }

    let mut new_vec: Vec<u8> = vec![0; SKIN_DATA_LENGTH];

    let mut skin_model: Option<SkinModel> = None;

    for bone in bones.members() {
        match translate_bone(accurate_skin, skin_width, bone, false, &mut new_vec) {
            Err(err) => return Err(err),
            Ok(model) => {
                if skin_model.is_none() {
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

        let name = animated_face.unwrap();
        let (geometry_entry, tex_width, tex_height) = get_correct_entry(format_version, &json, name)?;

        on_change_geometry(name, geometry_entry, &face_data, face_width);

        if tex_width != face_width || tex_height != face_height {
            return Err("the image width and height doesn't match the geometry data width and height");
        }

        let bones = &geometry_entry["bones"];
        if !bones.is_array() || bones.is_empty() {
            return Err("geometry data doesn't have bones");
        }

        for bone in bones.members() {
            translate_bone(face_data.as_slice(), face_width, bone, true, &mut new_vec)?;
        }
    }

    on_finish_convert(&new_vec);

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

fn translate_cubed_bone(
    skin_data: &[u8],
    w: usize,
    name: &str,
    position: &OffsetAndDimension,
    cubes: &JsonValue,
    new_vec: &mut [u8]
) -> Result<Option<SkinModel>, &'static str> {
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

    let result = if skin_model.is_some() && is_bottom_arm(name) {
        skin_model
    } else {
        None
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

    let source = OffsetAndDimension {
        x_offset,
        y_offset,
        width: tex_width,
        height: tex_height,
    };

    scale_and_fill_texture(skin_data, new_vec, w, SKIN_WIDTH, &source, position);
    on_cube_translated(name, skin_data, w, &source, new_vec);

    Ok(result)
}

fn translate_poly_bone(
    skin_data: &[u8],
    w: usize,
    name: &str,
    position: &OffsetAndDimension,
    poly_mesh: &JsonValue,
    new_vec: &mut [u8]
) -> Result<Option<SkinModel>, &'static str> {
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

    let source = OffsetAndDimension {
        x_offset,
        y_offset,
        width: tex_width,
        height: tex_height,
    };

    //todo impl mirroring
    scale_and_fill_texture(skin_data, new_vec, w, SKIN_WIDTH, &source, position);
    on_poly_translated(name, skin_data, w, &source, new_vec);

    //todo check
    let skin_model = match tex_width {
        18 => Some(Slim),
        20 => Some(Classic),
        _ => None
    };

    if skin_model.is_some() && is_bottom_arm(name) {
        return Ok(skin_model)
    }

    Ok(None)
}

fn translate_bone(skin_data: &[u8], w: usize, bone: &JsonValue, only_face: bool, new_vec: &mut [u8])
    -> Result<Option<SkinModel>, &'static str> {

    let name = bone["name"].as_str();
    if name.is_none() {
        return Err("bone doesn't have a name");
    }
    let name = name.unwrap();

    if only_face {
        // only translate the face
        if !"hat".eq(name) && !"head".eq(name) {
            return Ok(None);
        }
    }

    let result = get_texture_position(name);
    // we don't have to map every bone
    if result.is_none() {
        return Ok(None);
    }
    let position = result.unwrap();

    // lets check if it is a cubed bone or a poly bone

    let cubes = &bone["cubes"];
    if !cubes.is_null() {
        on_bone_found(name, BoneType::Cube, bone);

        if !cubes.is_array() {
            return Err("cubes isn't an array");
        }
        if cubes.is_empty() {
            return Ok(None); // apparently empty cubes is valid :shrug:
        }
        return translate_cubed_bone(skin_data, w, name, &position, cubes, new_vec);
    }

    let poly_mesh = &bone["poly_mesh"];
    if !poly_mesh.is_null() {
        on_bone_found(name, BoneType::Poly, bone);

        return translate_poly_bone(skin_data, w, name, &position, poly_mesh, new_vec);
    }

    // not every bone has cubes nor a poly mesh
    Ok(None)
}

fn get_bone_offset(uv: &JsonValue) -> Option<(usize, usize)> {
    if uv.len() != 2 {
        return None;
    }
    Some((uv[0].as_f64()? as usize, uv[1].as_f64()? as usize))
}

fn size_to_tex_size(size: &JsonValue) -> Option<(Option<SkinModel>, usize, usize)> {
    let width = size[0].as_f64()?;
    let height = size[1].as_f64()?;
    let depth = size[2].as_f64()?;

    let skin_model = match width.ceil() as i32 {
        3 => Some(Slim),
        4 => Some(Classic),
        _ => None
    };

    Some((skin_model, ((depth * 2.0) + (width * 2.0)) as usize, (depth + height).round() as usize))
}

fn is_bottom_arm(bone_name: &str) -> bool {
    // todo alternatively we add a method that converts a SkinPart + SkinLayer to the bone name?
    let section =
        bone_name_to_skin_section(bone_name)
            .expect("we only translate bones that have a section??");
    section.1 == SkinLayer::Bottom && section.0 == &SkinPart::ArmLeft || section.0 == &SkinPart::ArmRight
}

fn bone_name_to_skin_section(bone_name: &primitive::str) -> Option<SkinSection> {
    match bone_name {
        "head" => Some(SkinSection(&SkinPart::Head, SkinLayer::Bottom)),
        "hat" => Some(SkinSection(&SkinPart::Head, SkinLayer::Top)),
        "leftArm" | "leftarm" => Some(SkinSection(&SkinPart::ArmLeft, SkinLayer::Bottom)),
        "leftSleeve" | "leftsleeve" => Some(SkinSection(&SkinPart::ArmLeft, SkinLayer::Top)),
        "body" => Some(SkinSection(&SkinPart::Body, SkinLayer::Bottom)),
        "jacket" => Some(SkinSection(&SkinPart::Body, SkinLayer::Top)),
        "rightArm" | "rightarm" => Some(SkinSection(&SkinPart::ArmRight, SkinLayer::Bottom)),
        "rightSleeve" | "rightsleeve" => Some(SkinSection(&SkinPart::ArmRight, SkinLayer::Top)),
        "leftLeg" | "leftleg" => Some(SkinSection(&SkinPart::LegLeft, SkinLayer::Bottom)),
        "leftPants" | "leftpants" => Some(SkinSection(&SkinPart::LegLeft, SkinLayer::Top)),
        "rightLeg" | "rightleg" => Some(SkinSection(&SkinPart::LegRight, SkinLayer::Bottom)),
        "rightPants" | "rightpants" => Some(SkinSection(&SkinPart::LegRight, SkinLayer::Top)),
        _ => None,
    }
}

fn get_texture_position(bone_name: &primitive::str) -> Option<OffsetAndDimension> {
    let section = bone_name_to_skin_section(bone_name)?;
    texture_position(section)
}

//region skin debugger
#[cfg(feature = "build-binary")]
fn get_instance<'a>() -> MutexGuard<'a, crate::gui::skin_convert::SkinConvertData> {
    crate::gui::skin_convert::INSTANCE.lock().unwrap()
}

#[cfg(feature = "build-binary")]
fn on_start_convert(client_claims: &Value, geometry_data: &JsonValue, resource_patch: &JsonValue) {
    get_instance().start_convert(client_claims, geometry_data, resource_patch);
}

#[cfg(not(feature = "build-binary"))]
#[inline(always)]
fn on_start_convert(client_claims: &Value, geometry_data: &JsonValue, resource_patch: &JsonValue) {}

#[cfg(feature = "build-binary")]
fn on_change_geometry(
    geometry_name: &str,
    geometry_entry: &JsonValue,
    source_image: &[u8],
    image_width: usize
) {
    get_instance().change_geometry_entry(geometry_name, geometry_entry, source_image, image_width);
}

#[cfg(not(feature = "build-binary"))]
#[inline(always)]
fn on_change_geometry(
    geometry_name: &str,
    geometry_entry: &JsonValue,
    source_image: &[u8],
    image_width: usize
) {}


#[cfg(feature = "build-binary")]
fn on_bone_found(name: &str, bone_type: BoneType, geometry: &JsonValue) {
    get_instance().found_bone(name, bone_type, geometry);
}

#[cfg(not(feature = "build-binary"))]
#[inline(always)]
fn on_bone_found(name: &str, bone_type: BoneType, geometry: &JsonValue) {}


#[cfg(feature = "build-binary")]
fn on_cube_translated(name: &str, source: &[u8], source_width: usize, source_section: &OffsetAndDimension, step_image: &[u8]) {
    get_instance().bone_handled(name, source, source_width, source_section, step_image);
}

#[cfg(not(feature = "build-binary"))]
#[inline(always)]
fn on_cube_translated(name: &str, source: &[u8], source_width: usize, source_section: &OffsetAndDimension, step_image: &[u8]) {}


#[cfg(feature = "build-binary")]
fn on_poly_translated(name: &str, source: &[u8], source_width: usize, source_section: &OffsetAndDimension, step_image: &[u8]) {
    get_instance().bone_handled(name, source, source_width, source_section, step_image);
}

#[cfg(not(feature = "build-binary"))]
#[inline(always)]
fn on_poly_translated(name: &str, source: &[u8], source_width: usize, source_section: &OffsetAndDimension, step_image: &[u8]) {}


#[cfg(feature = "build-binary")]
fn on_finish_convert(final_image: &[u8]) {
    get_instance().finish_convert(final_image);
}

#[cfg(not(feature = "build-binary"))]
#[inline(always)]
fn on_finish_convert(final_image: &[u8]) {}

//endregion
