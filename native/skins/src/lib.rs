extern crate base64;
extern crate bytes;
extern crate jsonwebtokens;
extern crate lodepng;
extern crate rgb;
extern crate rustler;
extern crate serde_json;
extern crate sha2;

use std::borrow::Borrow;
use std::primitive;

use jsonwebtokens::{Algorithm, AlgorithmID, Verifier};
use rustler::{Binary, Encoder, Env, ListIterator, OwnedBinary, Term};
use rustler::atoms;
use rustler::types::atom::{false_, true_};
use rustler::types::tuple::make_tuple;
use serde_json::Value;
use sha2::{Digest, Sha256};

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

    let mojang_key: Algorithm = create_key("MHYwEAYHKoZIzj0CAQYFK4EEACIDYgAE8ELkixyLcwlZryUQcu1TvPOmI2B7vX83ndnWRUaXm74wFfa5f/lwQNTfrLVHa2PmenpGI6JhIMUJaWZrjmMj90NoKNFSNBuKdm8rYiXsfaz3K36x/1U26HpG0ZxK/V1V");
    let verifier = Verifier::create().build().unwrap();

    let mut last_data = Value::Null;
    let mut current_key = mojang_key;

    for x in list_iterator {
        let data: &primitive::str = x.decode::<&primitive::str>().unwrap();
        let claims = verifier.verify(data, &current_key);
        if claims.is_ok() {
            last_data = claims.unwrap();
            current_key = create_key(last_data["identityPublicKey"].as_str().unwrap())
        } else if last_data != Value::Null {
            return invalid_chain_data().to_term(env);
        }
    }

    if last_data == Value::Null {
        return invalid_chain_data().to_term(env);
    }

    let claims = verifier.verify(client_data, &current_key);

    if claims.is_err() {
        return invalid_client_data().to_term(env);
    }

    let client_claims = claims.unwrap();

    let skin_width = &(client_claims["SkinImageWidth"].as_u64().unwrap() as usize);
    let skin_height = &(client_claims["SkinImageHeight"].as_u64().unwrap() as usize);

    let skin_data = client_claims["SkinData"].as_str().unwrap();
    let raw_skin_data = base64::decode(skin_data).unwrap();

    // we have to clone, you can't use stuff for calculations and re-use it after that :/
    if raw_skin_data.len() != skin_width * skin_height * 4 {
        return invalid_size().to_term(env);
    }

    let geometry_name_option = client_claims["SkinResourcePatch"].as_str();
    let geometry_data_option = client_claims["SkinGeometryData"].as_str();

    if geometry_name_option.is_none() || geometry_data_option.is_none() {
        return invalid_geometry().to_term(env);
    }

    let geometry_data_option = geometry_data_option.unwrap();
    let needs_convert = !geometry_data_option.eq("bnVsbAo=");

    let geometry_name_res = base64::decode(geometry_name_option.unwrap());
    let geometry_data_res = base64::decode(geometry_data_option);

    if geometry_name_res.is_err() || geometry_data_res.is_err() {
        return invalid_geometry().to_term(env);
    }

    let geometry_name_res1: Result<Value, _> = serde_json::from_slice(geometry_name_res.unwrap().as_slice());
    if geometry_name_res1.is_err() {
        return invalid_geometry().to_term(env);
    }

    let geometry_name_val = geometry_name_res1.unwrap();
    let geometry_name_opt = geometry_name_val.get("geometry");

    if geometry_name_opt.is_none() {
        return invalid_geometry().to_term(env);
    }

    let geometry_name_val = geometry_name_opt.unwrap();
    let geometry_name_opt = geometry_name_val.get("default");

    if geometry_name_opt.is_none() {
        return invalid_geometry().to_term(env);
    }

    let geometry_name_opt = geometry_name_opt.unwrap().as_str();
    if geometry_name_opt.is_none() {
        return invalid_geometry().to_term(env);
    }

    let geometry_name = geometry_name_opt.unwrap();
    let geometry_data = geometry_data_res.unwrap();

    let convert_result = get_skin_or_convert_geometry(needs_convert, raw_skin_data, skin_height, geometry_data, geometry_name);
    if convert_result.is_err() {
        return make_tuple(env, &[invalid_geometry().to_term(env), convert_result.unwrap_err().encode(env)]);
    }

    let (raw_data, is_steve) = convert_result.unwrap();
    let is_steve = if is_steve { true_() } else { false_() };

    let xuid = last_data["extraData"]["XUID"].as_str();

    //todo interpolate during conversion to prevent new alloc and making it faster
    let raw_data = interpolate_nearest(raw_data, skin_width, 64, 64);
    let png = lodepng::encode32(raw_data.as_slice(), 64, 64).unwrap();

    let mut hasher = Sha256::new();
    hasher.update(raw_data.as_slice());

    let hash = hasher.finalize();

    make_tuple(env, &[xuid.encode(env), is_steve.to_term(env), as_binary(env, &png), as_binary(env, hash.as_slice())])
}

fn get_skin_or_convert_geometry(needs_convert: bool, skin_data: Vec<u8>, skin_height: &usize, geometry_data: Vec<u8>, geometry_name: &str) -> Result<(Vec<u8>, bool), &'static str> {
    if needs_convert {
        let raw_data = convert_geometry(skin_data.as_slice(), skin_height, geometry_data, geometry_name);
        if raw_data.is_err() {
            return Err(raw_data.unwrap_err())
        }
        let (raw_data, skin_model) = raw_data.unwrap();
        // fallback to steve if skin isn't alex
        Ok((raw_data, skin_model != 3))
    } else {
        Ok((skin_data, !geometry_name.ends_with("Slim\"")))
    }
}

fn convert_geometry(skin_data: &[u8], skin_height: &usize, geometry_data: Vec<u8>, geometry_name: &str) -> Result<(Vec<u8>, i32), &'static str> {
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
        return Err("unknown format version or geometry data doesn't contain name of geometry");
    }

    let bones = geometry_entry.unwrap().get("bones");
    if bones.is_none() {
        return Err("geometry data doesn't have any bones");
    }

    let bones = bones.unwrap().as_array();
    if bones.is_none() {
        return Err("bones aren't an array");
    }

    let mut new_vec: Vec<u8> = Vec::with_capacity(skin_data.len());
    unsafe { new_vec.set_len(new_vec.capacity()) }

    let skin_height = &(skin_height.clone() as f64);
    let skin_width = &(skin_data.len() as f64 / 4.0 / skin_height);

    let height_scale = &(64.0 / skin_height);
    let width_scale = &(64.0 / skin_width);

    let skin_width = &(skin_width.clone() as usize);

    let mut skin_model = -1;

    for bone in bones.unwrap() {
        let model_or_err = translate_bone(skin_data, skin_width, width_scale, height_scale, bone, &mut new_vec);
        if model_or_err.is_err() {
            return Err(model_or_err.unwrap_err());
        }
        if skin_model == -1 {
            skin_model = model_or_err.unwrap();
        }
    }

    Ok((new_vec, skin_model))
}

fn get_correct_entry<'a>(format_version: &str, geometry_data: &'a Value, geometry_name: &'a str) -> Option<&'a Value> {
    match format_version {
        "1.8.0" => {
            let geometry_data_opt = geometry_data.get(geometry_name);
            if geometry_data_opt.is_some() {
                return Some(geometry_data_opt.unwrap());
            }
            None
        }
        "1.12.0" => {
            let geometry_data_opt = geometry_data.get("minecraft:geometry");
            if geometry_data_opt.is_none() {
                return None;
            }

            let geometry_data_opt = geometry_data_opt.unwrap().as_array();
            if geometry_data_opt.is_none() {
                return None;
            }

            for entry in geometry_data_opt.unwrap() {
                let description_opt = entry.get("description");
                if description_opt.is_none() {
                    return None;
                }

                let identifier_opt = description_opt.unwrap().get("identifier");
                if identifier_opt.is_none() {
                    return None;
                }

                let identifier_opt = identifier_opt.unwrap().as_str();
                if identifier_opt.is_none() {
                    return None;
                }

                if identifier_opt.unwrap().eq(geometry_name) {
                    return Some(entry);
                }
            }
            None
        }
        _ => None
    }
}

fn translate_bone(skin_data: &[u8], w: &usize, w_scale: &f64, h_scale: &f64, bone: &Value, new_vec: &mut Vec<u8>) -> Result<i32, &'static str> {
    // not every bone has cubes, so we don't return errors for that
    let cubes = bone.get("cubes");
    if cubes.is_none() {
        return Ok(-1);
    }

    let cube = cubes.unwrap().get(0);
    if cube.is_none() {
        return Ok(-1);
    }

    let cube = cube.unwrap();

    let name = bone.get("name");
    if name.is_none() {
        return Err("bone doesn't have a name");
    }

    let name = name.unwrap().as_str();
    if name.is_none() {
        return Err("bone isn't a string");
    }

    let name = name.unwrap();

    let (x_tex_offset, y_tex_offset) = &get_texture_offset(name, w_scale, h_scale);
    // we don't have to map every bone, and bones that we don't have to map have are: offset > width
    if x_tex_offset > w {
        return Ok(-1);
    }

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

    let uv = uv.unwrap().as_array();
    if uv.is_none() {
        return Err("cube's uv isn't an array");
    }

    let uv = uv.unwrap();
    let (success, x_offset, y_offset) = &get_bone_offset(uv);
    if !success {
        return Err("failed to get bone offset");
    }

    for x in 0..tex_width {
        for y in 0..tex_height {
            for i in 0..4 as usize {
                let val = skin_data[((y_offset + y) * w + x_offset + x) * 4 + i].borrow();
                new_vec[((y_tex_offset + y) * w + x_tex_offset + x) * 4 + i] = *val;
            }
        }
    }

    let result = if skin_model == 0 || skin_model == 1 && name.eq("leftArm") || name.eq("rightArm") {
        skin_model
    } else {
        -1
    };

    return Ok(result);
}

fn interpolate_nearest(skin_data: Vec<u8>, skin_width: &usize, new_width: usize, new_height: usize) -> Vec<u8> {
    let skin_height = &(skin_data.len() / 4 / skin_width);

    let x_scale = &(skin_width.clone() as f32 / new_width.clone() as f32);
    let y_scale = &(skin_height.clone() as f32 / new_height.clone() as f32);

    if x_scale == &1.0 && y_scale == &1.0 {
        return skin_data;
    }

    let mut new_image = Vec::with_capacity((new_width * new_height * 4) as usize);
    unsafe { new_image.set_len(new_image.capacity()) }

    for x in 0..new_width {
        let x_ref = &x;
        for y in 0..new_height {
            let y_ref = &y;
            let x1: &usize = &(((x as f32 + 0.5) * x_scale).floor() as usize);
            let y1: &usize = &(((y as f32 + 0.5) * y_scale).floor() as usize);
            for i in 0..4 {
                let i_ref = &(i as usize);
                let pixel = skin_data[(y1 * skin_width + x1) * 4 + i_ref].borrow();
                new_image[(y_ref * new_width.borrow() + x_ref) * 4 + i_ref] = *pixel
            }
        }
    }

    new_image
}

fn get_bone_offset(uv: &Vec<Value>) -> (bool, usize, usize) {
    if uv.len() != 2 {
        return (false, 0, 0);
    }

    let x_offset = uv.get(0);
    let y_offset = uv.get(1);

    if x_offset.is_none() || y_offset.is_none() {
        return (false, 0, 0);
    }

    let x_offset = x_offset.unwrap().as_i64();
    let y_offset = y_offset.unwrap().as_i64();

    if x_offset.is_none() || y_offset.is_none() {
        return (false, 0, 0);
    }

    return (true, x_offset.unwrap() as usize, y_offset.unwrap() as usize);
}

fn size_to_tex_size(size: &Vec<Value>) -> (bool, i32, usize, usize) {
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

    return (true, skin_model, ((depth * 2.0) + (width * 2.0)) as usize, (depth + height).round() as usize);
}

fn get_texture_offset(bone_name: &primitive::str, width_scale: &f64, height_scale: &f64) -> (usize, usize) {
    let (x, y) = match bone_name {
        "body" => ((16.0 * width_scale), (16.0 * height_scale)),
        "head" => (0.0, 0.0),
        "hat" => (32.0 * width_scale, 0.0),
        "leftArm" => (32.0 * width_scale, 48.0 * height_scale),
        "rightArm" => (40.0 * width_scale, 16.0 * height_scale),
        "leftSleeve" => (48.0 * width_scale, 48.0 * height_scale),
        "rightSleeve" => (40.0 * width_scale, 32.0 * height_scale),
        "leftLeg" => (16.0 * width_scale, 48.0 * height_scale),
        "rightLeg" => (0.0, 16.0 * height_scale),
        "leftPants" => (0.0, 48.0 * height_scale),
        "rightPants" => (0.0, 32.0 * height_scale),
        "jacket" => (16.0 * width_scale, 32.0 * height_scale),
        _ => (61.0 * width_scale, 61.0 * height_scale),
    };
    (x as usize, y as usize)
}

fn as_binary<'a>(env: Env<'a>, data: &[u8]) -> Term<'a> {
    let mut erl_bin: OwnedBinary = OwnedBinary::new(data.len()).unwrap();
    erl_bin.as_mut_slice().copy_from_slice(data);
    Binary::from_owned(erl_bin, env).to_term(env)
}

pub fn create_key(pub_key: &primitive::str) -> Algorithm {
    Algorithm::new_ecdsa_pem_verifier(AlgorithmID::ES384, create_key_from(pub_key).as_bytes()).unwrap()
}

pub fn create_key_from<'a>(pub_key: &primitive::str) -> String {
    vec!["-----BEGIN PUBLIC KEY-----", pub_key, "-----END PUBLIC KEY-----"].concat()
}

rustler::init!("Elixir.GlobalLinking.SkinNifUtils", [validate_and_get_png]);
