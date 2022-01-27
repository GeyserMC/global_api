extern crate base64;
extern crate bytes;
extern crate jsonwebtokens;
extern crate lodepng;
extern crate rgb;
extern crate rustler;
extern crate serde_json;
extern crate sha2;

use rustler::{Encoder, Env, ListIterator, Term};
use rustler::atoms;
use rustler::types::atom::{false_, true_};
use rustler::types::tuple::make_tuple;

use chain_validator::validate_chain;
use converter::get_skin_or_convert_geometry;
use skin_codec::encode_image_and_get_hashes;

use crate::rustler_utils::as_binary;
use crate::skin_convert::converter::SkinModel;
use crate::skin_convert::skin_codec::ErrorType::{InvalidGeometry, InvalidSize};

pub mod converter;
mod pixel_cleaner;
mod chain_validator;
pub mod skin_codec;

atoms! {
    invalid_chain_data,
    invalid_client_data,
    invalid_size,
    invalid_image,
    invalid_geometry,
    hash_doesnt_match
}

#[rustler::nif]
pub fn validate_and_get_png<'a>(env: Env<'a>, chain_data: Term<'a>, client_data: &'a str) -> Term<'a> {
    let list_iterator: ListIterator = chain_data.decode().unwrap();
    let validation_result = validate_chain(list_iterator, client_data);

    if validation_result.is_none() {
        return invalid_chain_data().to_term(env);
    }

    let (last_data, client_claims) = validation_result.unwrap();

    let extra_data = last_data.get("extraData").unwrap();
    let xuid = extra_data["XUID"].as_str().unwrap();
    let gamertag = extra_data["displayName"].as_str().unwrap();
    let issued_at = last_data["iat"].as_i64().unwrap() * 1000; // seconds to ms
    let extra_data = make_tuple(env, &[xuid.encode(env), gamertag.encode(env), issued_at.encode(env)]);

    let collect_result = skin_codec::collect_skin_info(&client_claims);
    if collect_result.is_err() {
        let atom = match collect_result.err().unwrap() {
            InvalidSize => invalid_size(),
            InvalidGeometry => invalid_geometry(),
        };
        return make_tuple(env, &[atom.to_term(env), extra_data]);
    }

    let skin_info = collect_result.ok().unwrap();

    // sometimes its already defined what model a skin is
    let mut arm_model = SkinModel::Unknown;
    let arm_size = client_claims.get("ArmSize");
    if let Some(arm_size) = arm_size {
        let arm_size = arm_size.as_str();
        if let Some(arm_size) = arm_size {
            arm_model = if arm_size.eq("slim") { SkinModel::Alex } else { SkinModel::Steve };
        }
    }

    let convert_result = get_skin_or_convert_geometry(skin_info, client_claims);
    if let Err(err) = convert_result {
        return make_tuple(env, &[invalid_geometry().to_term(env), err.encode(env), extra_data]);
    }

    let (mut raw_data, mut is_steve) = convert_result.unwrap();
    if arm_model != SkinModel::Unknown {
        is_steve = arm_model == SkinModel::Steve;
    }
    let is_steve_atom = if is_steve { true_() } else { false_() };

    let (png, minecraft_hash, hash) = encode_image_and_get_hashes(&mut raw_data, is_steve);

    make_tuple(env, &[is_steve_atom.to_term(env), as_binary(env, png.as_ref()), as_binary(env, hash.as_ref()), as_binary(env, minecraft_hash.as_ref()), extra_data])
}
