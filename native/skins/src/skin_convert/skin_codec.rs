use std::str::from_utf8;
use base64::decode;
use json::{JsonValue, parse};
use lodepng::FilterStrategy;
use serde_json::Value;
use sha2::{Digest, Sha256};

use crate::skin_convert::skin_codec::ErrorType::{InvalidGeometry, InvalidSize};

#[derive(Debug)]
pub enum ErrorType {
    InvalidSize,
    InvalidGeometry,
}

pub struct SkinInfo {
    pub needs_convert: bool,
    pub raw_skin_data: Vec<u8>,
    pub skin_width: usize,
    pub geometry_data: Vec<u8>,
    pub geometry_patch: JsonValue,
    pub geometry_name: String,
}

pub struct ImageWithHashes {
    pub png: Box<[u8]>,
    pub minecraft_hash: Box<[u8]>,
    pub hash: Box<[u8]>,
}

pub fn collect_skin_info(client_claims: &Value) -> Result<SkinInfo, ErrorType> {
    let skin_width = client_claims["SkinImageWidth"].as_u64().unwrap() as usize;
    let skin_height = client_claims["SkinImageHeight"].as_u64().unwrap() as usize;

    let skin_data = client_claims["SkinData"].as_str().unwrap();
    let raw_skin_data = decode(skin_data).unwrap();

    if raw_skin_data.len() != skin_width * skin_height * 4 {
        return Err(InvalidSize);
    }

    let resource_patch_option = client_claims["SkinResourcePatch"].as_str();
    let geometry_data_option = client_claims["SkinGeometryData"].as_str();

    if resource_patch_option.is_none() || geometry_data_option.is_none() {
        return Err(InvalidGeometry);
    }

    let geometry_data = geometry_data_option.unwrap();
    let needs_convert = !geometry_data.eq("bnVsbAo="); // null in base64

    let geometry_patch_res = decode(resource_patch_option.unwrap());
    let geometry_data_res = decode(geometry_data);

    if geometry_patch_res.is_err() || geometry_data_res.is_err() {
        return Err(InvalidGeometry);
    }

    let geometry_patch_slice = geometry_patch_res.unwrap();

    let geometry_patch_str = from_utf8(geometry_patch_slice.as_slice());
    if geometry_patch_str.is_err() {
        return Err(InvalidGeometry);
    }

    let geometry_patch_res = parse(geometry_patch_str.unwrap());
    if geometry_patch_res.is_err() {
        return Err(InvalidGeometry);
    }

    let geometry_patch_val = geometry_patch_res.unwrap();
    let geometry_patch = &geometry_patch_val["geometry"];

    if geometry_patch.is_null() {
        return Err(InvalidGeometry);
    };

    let geometry_name = &geometry_patch["default"].as_str();
    if geometry_name.is_none() {
        return Err(InvalidGeometry);
    }

    let geometry_name = String::from(geometry_name.unwrap());
    let geometry_data = geometry_data_res.unwrap();

    Ok(SkinInfo { needs_convert, raw_skin_data, skin_width, geometry_data, geometry_patch: geometry_patch.clone(), geometry_name })
}

pub fn encode_image(raw_data: &mut Vec<u8>) -> ImageWithHashes {
    encode_custom_image(raw_data, 64, 64)
}

pub fn encode_custom_image(raw_data: &mut Vec<u8>, width: usize, height: usize) -> ImageWithHashes {
    // encode images like Minecraft does
    let mut encoder = lodepng::Encoder::new();
    encoder.set_auto_convert(false);
    encoder.info_png_mut().interlace_method = 0; // should be 0 but just to be sure

    let mut encoder_settings = encoder.settings_mut();
    encoder_settings.zlibsettings.set_level(4);
    encoder_settings.filter_strategy = FilterStrategy::ZERO;

    let png = encoder.encode(raw_data.as_slice(), width, height).unwrap();

    let mut hasher = Sha256::new();

    hasher.update(&png);
    let minecraft_hash = hasher.finalize_reset();

    // make our own hash
    hasher.update(raw_data.as_slice());
    let hash = hasher.finalize();

    ImageWithHashes {
        png: Box::from(png.as_slice()),
        minecraft_hash: Box::from(minecraft_hash.as_slice()),
        hash: Box::from(hash.as_slice())
    }
}