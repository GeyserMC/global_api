extern crate rustler;

use rustler::{atoms, Encoder, Env, ListIterator, Term};
use rustler::types::atom::{false_, true_};
use rustler::types::tuple::make_tuple;

use crate::rustler_utils::as_binary;
use crate::skin_convert::{ConvertResult, convert_skin, ErrorType};
use crate::skin_convert::chain_validator::validate_chain;
use crate::skin_convert::skin_codec::{ImageWithHashes};

mod skin_render;
mod skin_convert;
pub mod rustler_utils;

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

    match convert_skin(&client_claims) {
        ConvertResult::Invalid(err) => {
            let atom = match err {
                ErrorType::InvalidSize => invalid_size(),
                ErrorType::InvalidGeometry => invalid_geometry()
            };
            make_tuple(env, &[atom.to_term(env), extra_data])
        }
        ConvertResult::Error(err) =>
            make_tuple(env, &[invalid_geometry().to_term(env), err.encode(env), extra_data]),

        ConvertResult::Success(ImageWithHashes { png, minecraft_hash, hash }, is_steve) => {
            let is_steve_atom = if is_steve { true_() } else { false_() };
            make_tuple(env, &[is_steve_atom.to_term(env), as_binary(env, png.as_ref()), as_binary(env, hash.as_ref()), as_binary(env, minecraft_hash.as_ref()), extra_data])
        }
    }
}


rustler::init!("Elixir.GlobalApi.SkinsNif", [validate_and_get_png]);
