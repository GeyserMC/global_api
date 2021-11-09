extern crate base64;
extern crate bytes;
extern crate jsonwebtokens;
extern crate lodepng;
extern crate rgb;
extern crate rustler;
extern crate serde_json;
extern crate sha2;

use std::primitive;

use jsonwebtokens::{Algorithm, AlgorithmID, Verifier};
use lodepng::FilterStrategy;
use rustler::{Encoder, Env, ListIterator, Term};
use rustler::atoms;
use rustler::types::atom::{false_, true_};
use rustler::types::tuple::make_tuple;
use serde_json::json;
use serde_json::Value;
use sha2::{Digest, Sha256};
use crate::as_binary;

const TEXTURE_TYPE_FACE: i64 = 1;
const MOJANG_PUBLIC_KEY: &primitive::str = "MHYwEAYHKoZIzj0CAQYFK4EEACIDYgAE8ELkixyLcwlZryUQcu1TvPOmI2B7vX83ndnWRUaXm74wFfa5f/lwQNTfrLVHa2PmenpGI6JhIMUJaWZrjmMj90NoKNFSNBuKdm8rYiXsfaz3K36x/1U26HpG0ZxK/V1V";

atoms! {
    invalid_chain_data,
    invalid_client_data,
    invalid_size,
    invalid_image,
    invalid_geometry,
    hash_doesnt_match
}

#[rustler::nif]
pub fn validate_and_get_png<'a>(env: Env<'a>, chain_data: Term, client_data: &primitive::str) -> Term<'a> {
    let list_iterator: ListIterator = chain_data.decode().unwrap();

    let verifier = Verifier::create().build().unwrap();

    let mut current_key: Algorithm = create_key(MOJANG_PUBLIC_KEY);
    let mut last_data = Value::Null;
    let mut list_size: i32 = 0;

    let mut was_mojang = false;
    let mut auth_completed = false;

    for x in list_iterator {
        list_size += 1;
        if list_size > 3 {
            return invalid_chain_data().to_term(env);
        }

        if auth_completed {
            return invalid_chain_data().to_term(env);
        }

        let data: &primitive::str = x.decode::<&primitive::str>().unwrap();

        let claims = verifier.verify(data, &current_key);
        if let Ok(data) = claims {
            if was_mojang {
                auth_completed = true;
            } else {
                was_mojang = true;
            }

            last_data = data;
            current_key = create_key(last_data["identityPublicKey"].as_str().unwrap())
        } else if last_data != Value::Null {
            return invalid_chain_data().to_term(env);
        }
    }

    if !auth_completed {
        return invalid_chain_data().to_term(env);
    }

    let claims = verifier.verify(client_data, &current_key);

    if claims.is_err() {
        return invalid_client_data().to_term(env);
    }

    let client_claims = claims.unwrap();

    let extra_data = last_data.get("extraData").unwrap();
    let xuid = extra_data["XUID"].as_str().unwrap();
    let gamertag = extra_data["displayName"].as_str().unwrap();
    let issued_at = last_data["iat"].as_i64().unwrap() * 1000; // seconds to ms
    let extra_data = make_tuple(env, &[xuid.encode(env), gamertag.encode(env), issued_at.encode(env)]);

    let skin_width = &(client_claims["SkinImageWidth"].as_u64().unwrap() as usize);
    let skin_height = &(client_claims["SkinImageHeight"].as_u64().unwrap() as usize);

    let skin_data = client_claims["SkinData"].as_str().unwrap();
    let raw_skin_data = base64::decode(skin_data).unwrap();

    if raw_skin_data.len() != skin_width * skin_height * 4 {
        return make_tuple(env, &[invalid_size().to_term(env), extra_data]);
    }

    let geometry_name_option = client_claims["SkinResourcePatch"].as_str();
    let geometry_data_option = client_claims["SkinGeometryData"].as_str();

    if geometry_name_option.is_none() || geometry_data_option.is_none() {
        return make_tuple(env, &[invalid_geometry().to_term(env), extra_data]);
    }

    let geometry_data = geometry_data_option.unwrap();
    let needs_convert = !geometry_data.eq("bnVsbAo=");

    let geometry_name_res = base64::decode(geometry_name_option.unwrap());
    let geometry_data_res = base64::decode(geometry_data);

    if geometry_name_res.is_err() || geometry_data_res.is_err() {
        return make_tuple(env, &[invalid_geometry().to_term(env), extra_data]);
    }

    let geometry_name_res: Result<Value, _> = serde_json::from_slice(geometry_name_res.unwrap().as_slice());
    if geometry_name_res.is_err() {
        return make_tuple(env, &[invalid_geometry().to_term(env), extra_data]);
    }

    let geometry_name_val = geometry_name_res.unwrap();
    let geometry_name_obj = geometry_name_val.get("geometry");

    if geometry_name_obj.is_none() {
        return make_tuple(env, &[invalid_geometry().to_term(env), extra_data]);
    }

    let geometry_name_obj = geometry_name_obj.unwrap();
    let geometry_name_opt = geometry_name_obj.get("default");

    if geometry_name_opt.is_none() {
        return make_tuple(env, &[invalid_geometry().to_term(env), extra_data]);
    }

    let geometry_name_opt = geometry_name_opt.unwrap().as_str();
    if geometry_name_opt.is_none() {
        return make_tuple(env, &[invalid_geometry().to_term(env), extra_data]);
    }

    let geometry_name = geometry_name_opt.unwrap();
    let geometry_data = geometry_data_res.unwrap();

    // sometimes its already defined what model a skin is
    let mut arm_model = -1;
    let arm_size = client_claims.get("ArmSize");
    if let Some(arm_size) = arm_size {
        let arm_size = arm_size.as_str();
        if let Some(arm_size) = arm_size {
            arm_model = if arm_size.eq("slim") { 1 } else { 0 };
        }
    }

    let convert_result = get_skin_or_convert_geometry(needs_convert, raw_skin_data, skin_width, client_claims, geometry_data, geometry_name_obj, geometry_name);
    if let Err(err) = convert_result {
        return make_tuple(env, &[invalid_geometry().to_term(env), err.encode(env), extra_data]);
    }

    let (mut raw_data, mut is_steve) = convert_result.unwrap();
    if arm_model != -1 {
        is_steve = arm_model == 0;
    }
    let is_steve_atom = if is_steve { true_() } else { false_() };

    let clean_data = clear_unused_pixels(&mut raw_data, is_steve);

    // encode images like Minecraft does
    let mut encoder = lodepng::Encoder::new();
    encoder.set_auto_convert(false);
    encoder.info_png_mut().interlace_method = 0; // should be 0 but just to be sure

    let mut encoder_settings = encoder.settings_mut();
    encoder_settings.zlibsettings.set_level(4);
    encoder_settings.filter_strategy = FilterStrategy::ZERO;

    let png = encoder.encode(clean_data.as_slice(), 64, 64).unwrap();

    let mut hasher = Sha256::new();

    hasher.update(&png);
    let minecraft_hash = hasher.finalize_reset();

    // make our own hash
    hasher.update(clean_data.as_slice());
    let hash = hasher.finalize();

    make_tuple(env, &[is_steve_atom.to_term(env), as_binary(env, &png), as_binary(env, hash.as_slice()), as_binary(env, minecraft_hash.as_slice()), extra_data])
}

fn get_skin_or_convert_geometry(needs_convert: bool, skin_data: Vec<u8>, skin_width: &usize, client_claims: Value, geometry_data: Vec<u8>, geometry_name_obj: &Value, geometry_name: &str) -> Result<(Vec<u8>, bool), &'static str> {
    if needs_convert && (skin_width > &0 && !skin_data.is_empty()) {
        let raw_data = convert_geometry(skin_data.as_slice(), skin_width, client_claims, geometry_data, geometry_name_obj, geometry_name);
        if let Err(err) = raw_data {
            return Err(err);
        }
        let (raw_data, skin_model) = raw_data.unwrap();
        // fallback to steve if skin isn't alex
        Ok((raw_data, skin_model != 3))
    } else {
        // we still have to scale even though we technically don't have to convert them
        if skin_data.len() != 64 * 64 * 4 {
            let mut new_vec: Vec<u8> = Vec::with_capacity(64 * 64 * 4);
            unsafe { new_vec.set_len(new_vec.capacity()) }

            // apparently some people have an empty skin so yeah
            if skin_width > &0 && !skin_data.is_empty() {
                fill_and_scale_texture(skin_data.as_slice(), &mut new_vec, *skin_width, 64, *skin_width, skin_data.len() / 4 / skin_width, 64, 64, 0, 0, 0, 0);
            }

            return Ok((new_vec, !geometry_name.ends_with("Slim")));
        }
        Ok((skin_data, !geometry_name.ends_with("Slim")))
    }
}

fn convert_geometry(skin_data: &[u8], skin_width: &usize, client_claims: Value, geometry_data: Vec<u8>, geometry_name_obj: &Value, geometry_name: &str) -> Result<(Vec<u8>, i32), &'static str> {
    let json: Result<Value, _> = serde_json::from_slice(geometry_data.as_slice());
    if json.is_err() {
        return Err("invalid json");
    }

    let json = json.unwrap();

    let format_version_opt = json.get("format_version");
    if format_version_opt.is_none() {
        return Err("geometry data doesn't have a format version");
    }

    let format_version_opt = format_version_opt.unwrap().as_str();
    if format_version_opt.is_none() {
        return Err("format version isn't a string");
    }

    let format_version = format_version_opt.unwrap();

    let geometry_entry = get_correct_entry(format_version, &json, geometry_name);
    if geometry_entry.is_none() {
        return Err("unknown format version or can't find the correct geometry data");
    }

    let (geometry_entry, tex_width, tex_height) = geometry_entry.unwrap();

    if &tex_width != skin_width || tex_width * tex_height * 4 != skin_data.len() {
        return Err("the image width and height doesn't match the geometry data width and height");
    }

    let bones = geometry_entry.get("bones");
    if bones.is_none() {
        return Err("geometry data doesn't have any bones");
    }

    let bones = bones.unwrap().as_array();
    if bones.is_none() {
        return Err("bones isn't an array");
    }

    let mut new_vec: Vec<u8> = Vec::with_capacity(64 * 64 * 4);
    unsafe { new_vec.set_len(new_vec.capacity()) }

    let mut skin_model = -1;

    for bone in bones.unwrap() {
        let model_or_err = translate_bone(skin_data, skin_width, bone, false, &mut new_vec);
        if let Err(err) = model_or_err {
            return Err(err);
        }
        if skin_model == -1 {
            skin_model = model_or_err.unwrap();
        }
    }

    // lets check (and translate it) if the skin also has an animated head

    let animated_face = geometry_name_obj.get("animated_face");
    if let Some(animated_face) = animated_face {
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

        if face_data.len() != face_width * face_height * 4 {
            return Err("animated frame image has an incorrect length");
        }

        let geometry_entry = get_correct_entry(format_version, &json, animated_face.unwrap());
        if geometry_entry.is_none() {
            return Err("unknown format version or can't find the correct geometry data");
        }

        let (geometry_entry, tex_width, tex_height) = geometry_entry.unwrap();

        if tex_width != face_width || tex_height != face_height {
            return Err("the image width and height doesn't match the geometry data width and height");
        }

        let bones = geometry_entry.get("bones");
        if bones.is_none() {
            return Err("geometry data doesn't have any bones");
        }

        let bones = bones.unwrap().as_array();
        if bones.is_none() {
            return Err("bones isn't an array");
        }

        for bone in bones.unwrap() {
            let model_or_err = translate_bone(face_data.as_slice(), &face_width, bone, true, &mut new_vec);
            if let Err(err) = model_or_err {
                return Err(err);
            }
        }
    }

    Ok((new_vec, skin_model))
}

fn get_correct_entry<'a>(format_version: &str, geometry_data: &'a Value, geometry_name: &'a str) -> Option<(&'a Value, usize, usize)> {
    match format_version {
        "1.8.0" => {
            let geometry_data = geometry_data.get(geometry_name)?;

            let texture_width = geometry_data.get("texturewidth")?.as_f64()?;
            let texture_height = geometry_data.get("textureheight")?.as_f64()?;

            Some((geometry_data, texture_width as usize, texture_height as usize))
        }
        "1.12.0" | "1.14.0" => {
            let geometry_data = geometry_data.get("minecraft:geometry")?;

            let geometry_data = geometry_data.as_array()?;

            for entry in geometry_data {
                let description = entry.get("description")?;

                let identifier = description.get("identifier")?;
                let identifier = identifier.as_str()?;

                if identifier.eq(geometry_name) {
                    let texture_width = description.get("texture_width")?.as_f64()?;
                    let texture_height = description.get("texture_height")?.as_f64()?;
                    return Some((entry, texture_width as usize, texture_height as usize));
                }
            }
            None
        }
        _ => None
    }
}

fn translate_cubed_bone(skin_data: &[u8], w: &usize, name: &str, x_tex_offset: usize, y_tex_offset: usize, x_tex_size: usize, y_tex_size: usize, cubes: &[Value], new_vec: &mut Vec<u8>) -> Result<i32, &'static str> {
    let cube = cubes.get(0).unwrap();

    let size = cube.get("size");
    if size.is_none() {
        return Err("bone doesn't have a size");
    }

    let size = size.unwrap().as_array();
    if size.is_none() {
        return Err("bone size isn't an array");
    }

    let size = size.unwrap();
    if size.len() != 3 {
        return Err("bone size doesn't have the length 3");
    }

    let (success, skin_model, tex_width, tex_height) = size_to_tex_size(size);
    if !success {
        return Err("failed converting size to texture size");
    }

    let uv = cube.get("uv");
    if uv.is_none() {
        return Err("cube doesn't have uv");
    }

    // temp pos
    let result = if (skin_model == 0 || skin_model == 1) && (name.eq("leftArm") || name.eq("leftarm") || name.eq("rightArm") || name.eq("rightarm")) {
        skin_model
    } else {
        -1
    };

    let uv = uv.unwrap().as_array();
    if uv.is_none() {
        // temp 'fix'
        if cube.get("uv").unwrap().is_object() {
            return Ok(result);
        }
        return Err("cube's uv isn't an array");
    }

    let uv = uv.unwrap();
    let (success, x_offset, y_offset) = get_bone_offset(uv);
    if !success {
        return Err("failed to get bone offset");
    }

    fill_and_scale_texture(skin_data, new_vec, *w, 64, tex_width, tex_height, x_tex_size, y_tex_size, x_offset, y_offset, x_tex_offset, y_tex_offset);

    Ok(result)
}

fn fill_and_scale_texture(skin_data: &[u8], new_vec: &mut Vec<u8>, skin_data_width: usize, new_width: usize, bone_width: usize, bone_height: usize, tex_width: usize, tex_height: usize, x_offset: usize, y_offset: usize, x_tex_offset: usize, y_tex_offset: usize) {
    if tex_width >= bone_width && tex_height >= bone_height {
        for x in 0..bone_width {
            for y in 0..bone_height {
                for i in 0..4_usize {
                    let val = skin_data[((y_offset + y) * skin_data_width + x_offset + x) * 4 + i];
                    new_vec[((y_tex_offset + y) * new_width + x_tex_offset + x) * 4 + i] = val;
                }
            }
        }
    } else {
        let x_scale = bone_width as f32 / tex_width as f32;
        let y_scale = bone_height as f32 / tex_height as f32;

        for x in 0..tex_width {
            for y in 0..tex_height {
                let x1 = (((x + x_offset) as f32 + 0.5) * x_scale).floor() as usize;
                let y1 = (((y + y_offset) as f32 + 0.5) * y_scale).floor() as usize;
                for i in 0..4_usize {
                    let pixel = skin_data[(y1 * skin_data_width + x1) * 4 + i];
                    new_vec[((y_tex_offset + y) * new_width + x_tex_offset + x) * 4 + i] = pixel
                }
            }
        }
    }
}

fn translate_poly_bone(skin_data: &[u8], w: &usize, name: &str, x_tex_offset: usize, y_tex_offset: usize, x_tex_size: usize, y_tex_size: usize, poly_mesh: &Value, new_vec: &mut Vec<u8>) -> Result<i32, &'static str> {
    let is_normalized = poly_mesh.get("normalized_uvs").unwrap_or(&json!(false)).as_bool();
    if is_normalized.is_none() {
        return Err("invalid is_normalized");
    }
    let is_normalized = is_normalized.unwrap();

    let polys = poly_mesh.get("polys");
    if polys.is_none() {
        return Err("bone doesn't have polys");
    }
    let polys = polys.unwrap().as_array();
    if polys.is_none() {
        return Err("polys isn't an array");
    }
    let polys = polys.unwrap();

    let normals = poly_mesh.get("normals");
    if normals.is_none() {
        return Err("bone doesn't have normals");
    }
    let normals = normals.unwrap().as_array();
    if normals.is_none() {
        return Err("normals aren't an array");
    }
    let normals = normals.unwrap();

    if polys.len() != normals.len() {
        return Err("polys and normals should have the same length");
    }

    let uvs = poly_mesh.get("uvs");
    if uvs.is_none() {
        return Err("bone doesn't have uvs");
    }
    let uvs = uvs.unwrap().as_array();
    if uvs.is_none() {
        return Err("uvs aren't an array");
    }
    let uvs = uvs.unwrap();

    if polys.is_empty() || uvs.is_empty() {
        return Err("cannot translate empty geometry");
    }

    // we should be able to get the texture size by just looping through the uvs values
    // and pick the highest and lowest entries of those values

    let h = skin_data.len() / 4 / w;

    let w_f = *w as f64;
    let h_f = h as f64;

    let mut lowest_u = w_f;
    let mut highest_u = 0 as f64;
    let mut lowest_v = h_f;
    let mut highest_v = 0 as f64;

    for uv in uvs {
        let uv = uv.as_array();
        if uv.is_none() {
            return Err("invalid uv data");
        }
        let uv = uv.unwrap();
        if uv.len() != 2 {
            return Err("invalid uv entry length");
        }

        let u = uv.get(0).unwrap().as_f64();
        let v = uv.get(1).unwrap().as_f64();
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

    //todo impl mirroring
    fill_and_scale_texture(skin_data, new_vec, *w, 64, tex_width, tex_height, x_tex_size, y_tex_size, x_offset, y_offset, x_tex_offset, y_tex_offset);

    //todo check
    let skin_model = if tex_width == 18 { 1 } else if tex_width == 20 { 0 } else { -1 };

    let result = if skin_model == 0 || skin_model == 1 && name.eq("leftarm") || name.eq("rightarm") {
        skin_model
    } else {
        -1
    };

    Ok(result)
}

fn translate_bone(skin_data: &[u8], w: &usize, bone: &Value, only_face: bool, new_vec: &mut Vec<u8>) -> Result<i32, &'static str> {
    let name = bone.get("name");
    if name.is_none() {
        return Err("bone doesn't have a name");
    }
    let name = name.unwrap().as_str();
    if name.is_none() {
        return Err("bone isn't a string");
    }
    let name = name.unwrap();

    if only_face {
        // only translate the face
        if !"hat".eq(name) && !"head".eq(name) {
            return Ok(-1);
        }
    }

    let (x_tex_offset, y_tex_offset, x_tex_size, y_tex_size) = get_texture_offset(name);
    // we don't have to map every bone, and bones that we don't have to map have are: 0, 1
    if x_tex_size == 0 && y_tex_size == 0 {
        return Ok(-1);
    }

    // lets check if it is a cubed bone or a poly bone

    let cubes = bone.get("cubes");
    if let Some(cubes) = cubes {
        let cubes = cubes.as_array();
        if cubes.is_none() {
            return Err("cubes isn't an array");
        }
        let cubes = cubes.unwrap();
        if cubes.is_empty() {
            return Ok(-1); // apparently empty cubes is valid :shrug:
        }
        return translate_cubed_bone(skin_data, w, name, x_tex_offset, y_tex_offset, x_tex_size, y_tex_size, cubes, new_vec);
    }

    let poly_mesh = bone.get("poly_mesh");
    if let Some(mesh) = poly_mesh {
        return translate_poly_bone(skin_data, w, name, x_tex_offset, y_tex_offset, x_tex_size, y_tex_size, mesh, new_vec);
    }

    // not every bone has cubes nor a poly mesh
    Ok(-1)
}

fn get_bone_offset(uv: &[Value]) -> (bool, usize, usize) {
    if uv.len() != 2 {
        return (false, 0, 0);
    }

    let x_offset = uv.get(0);
    let y_offset = uv.get(1);

    if x_offset.is_none() || y_offset.is_none() {
        return (false, 0, 0);
    }

    let x_offset = x_offset.unwrap().as_f64();
    let y_offset = y_offset.unwrap().as_f64();

    if x_offset.is_none() || y_offset.is_none() {
        return (false, 0, 0);
    }

    (true, x_offset.unwrap() as usize, y_offset.unwrap() as usize)
}

fn size_to_tex_size(size: &[Value]) -> (bool, i32, usize, usize) {
    let width = size.get(0).unwrap().as_f64();
    let height = size.get(1).unwrap().as_f64();
    let depth = size.get(2).unwrap().as_f64();

    if width.is_none() || height.is_none() || depth.is_none() {
        return (false, -1, 0, 0);
    }

    let width = width.unwrap();
    let height = height.unwrap();
    let depth = &depth.unwrap();

    let skin_model = if width == 3.0 { 1 } else if width == 4.0 { 0 } else { -1 };

    (true, skin_model, ((depth * 2.0) + (width * 2.0)) as usize, (depth + height).round() as usize)
}

fn get_texture_offset(bone_name: &primitive::str) -> (usize, usize, usize, usize) {
    // start x, start y, width, height
    match bone_name {
        "body" => (16, 16, 24, 16),
        "head" => (0, 0, 32, 16),
        "hat" => (32, 0, 32, 16),
        "leftArm" | "leftarm" => (32, 48, 16, 16),
        "rightArm" | "rightarm" => (40, 16, 16, 16),
        "leftSleeve" | "leftsleeve" => (48, 48, 16, 16),
        "rightSleeve" | "rightsleeve" => (40, 32, 16, 16),
        "leftLeg" | "leftleg" => (16, 48, 16, 16),
        "rightLeg" | "rightleg" => (0, 16, 16, 16),
        "leftPants" | "leftpants" => (0, 48, 16, 16),
        "rightPants" | "rightpants" => (0, 32, 16, 16),
        "jacket" => (16, 32, 24, 16),
        _ => (0, 0, 0, 0),
    }
}

fn clear_unused_pixels(raw_data: &mut Vec<u8>, is_steve: bool) -> &mut Vec<u8> {
    // clear the unused sections of a 64x64 skin

    // first row
    for x in 0..8 {
        for y in 0..8 {
            set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
        }
    }
    for x in 24..40 {
        for y in 0..8 {
            set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
        }
    }
    for x in 56..64 {
        for y in 0..8 {
            set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
        }
    }
    // second row
    for x in 0..4 {
        for y in 16..20 {
            set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
        }
    }
    for x in 12..20 {
        for y in 16..20 {
            set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
        }
    }
    for x in 36..44 {
        for y in 16..20 {
            set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
        }
    }
    // third row
    for x in 0..4 {
        for y in 32..36 {
            set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
        }
    }
    for x in 12..20 {
        for y in 32..36 {
            set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
        }
    }
    for x in 36..44 {
        for y in 32..36 {
            set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
        }
    }
    // fourth row
    for x in 0..4 {
        for y in 48..52 {
            set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
        }
    }
    for x in 12..20 {
        for y in 48..52 {
            set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
        }
    }
    for x in 28..36 {
        for y in 48..52 {
            set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
        }
    }
    // Alex skins have more empty space then Steve skins
    if is_steve {
        // second row
        for x in 52..56 {
            for y in 16..20 {
                set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
            }
        }
        // third row
        for x in 52..56 {
            for y in 32..36 {
                set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
            }
        }
        // fourth row
        for x in 44..52 {
            for y in 48..52 {
                set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
            }
        }
        for x in 60..64 {
            for y in 48..52 {
                set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
            }
        }
        // big unused area in row 2 and 3
        for x in 56..64 {
            for y in 16..48 {
                set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
            }
        }
    } else {
        // second row
        for x in 50..54 {
            for y in 16..20 {
                set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
            }
        }
        // third row
        for x in 50..52 {
            for y in 32..36 {
                set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
            }
        }
        // fourth row
        for x in 42..52 {
            for y in 48..52 {
                set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
            }
        }
        for x in 46..48 {
            for y in 52..64 {
                set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
            }
        }
        for x in 58..64 {
            for y in 48..52 {
                set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
            }
        }
        for x in 62..64 {
            for y in 52..64 {
                set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
            }
        }
        // big unused area in row 2 and 3
        for x in 54..64 {
            for y in 16..48 {
                set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
            }
        }
    }
    raw_data
}

fn set_pixel(vec: &mut Vec<u8>, x: usize, y: usize, width: usize, r: u8, g: u8, b: u8, a: u8) {
    vec[(y * width + x) * 4] = r;
    vec[(y * width + x) * 4 + 1] = g;
    vec[(y * width + x) * 4 + 2] = b;
    vec[(y * width + x) * 4 + 3] = a;
}

fn create_key(pub_key: &primitive::str) -> Algorithm {
    Algorithm::new_ecdsa_pem_verifier(AlgorithmID::ES384, create_key_from(pub_key).as_bytes()).unwrap()
}

fn create_key_from<'a>(pub_key: &primitive::str) -> String {
    vec!["-----BEGIN PUBLIC KEY-----", pub_key, "-----END PUBLIC KEY-----"].concat()
}
