use serde_json::Value;

use crate::skin_convert::converter::convert_skin as other_convert_skin;
use crate::skin_convert::ConvertResult::{Error, Invalid, Success};
use crate::skin_convert::pixel_cleaner::clear_unused_pixels;
use crate::skin_convert::skin_codec::{encode_image, ImageWithHashes};
use crate::SkinModel;

pub mod converter;
mod pixel_cleaner;
pub mod chain_validator;
pub mod skin_codec;

#[derive(Debug)]
pub enum ErrorType {
    InvalidSize,
    InvalidGeometry,
}

pub enum ConvertResult<'a> {
    Invalid(ErrorType),
    Error(&'a str),
    Success(ImageWithHashes, bool),
}

pub fn convert_skin(client_claims: &Value) -> ConvertResult {
    let collect_result = skin_codec::collect_skin_info(client_claims);
    if collect_result.is_err() {
        return Invalid(collect_result.err().unwrap());
    }

    let skin_info = collect_result.ok().unwrap();

    // sometimes its already defined which model the skin is
    let mut arm_model: Option<SkinModel> = None;
    let arm_size = client_claims.get("ArmSize");
    if let Some(arm_size) = arm_size {
        let arm_size = arm_size.as_str();
        if let Some(arm_size) = arm_size {
            arm_model = match arm_size {
                "slim" => Some(SkinModel::Slim),
                "steve" => Some(SkinModel::Classic),
                _ => None
            };
        }
    }

    let convert_result = other_convert_skin(skin_info, client_claims);
    if let Err(err) = convert_result {
        return Error(err);
    }

    let (mut raw_data, mut is_classic) = convert_result.unwrap();
    if let Some(model) = arm_model {
        is_classic = model == SkinModel::Classic;
    }

    clear_unused_pixels(&mut raw_data, is_classic);
    let data = encode_image(&mut raw_data);

    Success(data, is_classic)
}
