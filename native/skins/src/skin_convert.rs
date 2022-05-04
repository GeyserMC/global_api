extern crate base64;
extern crate bytes;
extern crate jsonwebtokens;
extern crate lodepng;
extern crate rgb;
extern crate rustler;
extern crate serde_json;
extern crate sha2;

use serde_json::Value;

use crate::skin_convert::converter::{get_skin_or_convert_geometry, SkinModel};
use crate::skin_convert::ConvertResult::{Error, Invalid, Success};
use crate::skin_convert::pixel_cleaner::clear_unused_pixels;
use crate::skin_convert::skin_codec::{encode_image, ImageWithHashes};

pub mod converter;
mod pixel_cleaner;
pub mod chain_validator;
pub mod skin_codec;

#[derive(Debug)]
pub enum ErrorType {
    InvalidSize,
    InvalidGeometry,
}

pub enum ConvertResult {
    Invalid(ErrorType),
    Error(&'static str),
    Success(ImageWithHashes, bool),
}

pub fn convert_skin(client_claims: Value) -> ConvertResult {
    let collect_result = skin_codec::collect_skin_info(&client_claims);
    if collect_result.is_err() {
        return Invalid(collect_result.err().unwrap());
    }

    let skin_info = collect_result.ok().unwrap();

    // sometimes its already defined which model the skin is
    let mut arm_model = SkinModel::Unknown;
    let arm_size = client_claims.get("ArmSize");
    if let Some(arm_size) = arm_size {
        let arm_size = arm_size.as_str();
        if let Some(arm_size) = arm_size {
            arm_model = match arm_size {
                "slim" => SkinModel::Alex,
                "steve" => SkinModel::Steve,
                _ => SkinModel::Unknown
            };
        }
    }

    let convert_result = get_skin_or_convert_geometry(skin_info, client_claims);
    if let Err(err) = convert_result {
        return Error(err);
    }

    let (mut raw_data, mut is_steve) = convert_result.unwrap();
    if arm_model != SkinModel::Unknown {
        is_steve = arm_model == SkinModel::Steve;
    }

    clear_unused_pixels(&mut raw_data, is_steve);
    let data = encode_image(&mut raw_data);

    Success(data, is_steve)
}
