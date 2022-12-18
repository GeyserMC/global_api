use rgb::ComponentBytes;
use rustler::{atoms, Binary, Encoder, Env, init, ListIterator, nif, Term};
use rustler::types::atom::{false_, true_};
use rustler::types::tuple::make_tuple;

use crate::common::skin::{SkinLayer, SkinModel};
use crate::rustler_utils::as_binary;
use crate::skin_convert::{convert_skin, ConvertResult, ErrorType};
use crate::skin_convert::chain_validator::validate_chain;
use crate::skin_convert::skin_codec::ImageWithHashes;
use crate::skin_render::flat_render::render_front;

mod common;
mod skin_render;
mod skin_convert;
pub mod rustler_utils;

atoms! {
    // convert
    invalid_data,
    invalid_client_data,
    invalid_size,
    invalid_image,
    invalid_geometry,
    hash_doesnt_match,
}

#[nif(schedule = "DirtyCpu")]
pub fn validate_and_convert<'a>(env: Env<'a>, chain_data: Term<'a>, client_data: &'a str) -> Term<'a> {
    let list_iterator: ListIterator = chain_data.decode().unwrap();
    let validation_result = validate_chain(list_iterator, client_data);

    if validation_result.is_none() {
        return invalid_data().to_term(env);
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

#[nif]
pub fn render_skin_front<'a>(
    env: Env<'a>,
    data: Binary<'a>,
    layer: SkinLayer,
    model: SkinModel,
    target_width: usize,
) -> Term<'a> {
    let png = lodepng::decode32(data.as_slice());
    if png.is_err() {
        return invalid_image().to_term(env);
    }
    let png = png.unwrap();

    let render = render_front(png.buffer.as_bytes(), png.width, &layer, &model, target_width);

    let encoded = lodepng::encode32(render.as_ref(), render.width() as usize, render.height() as usize)
        .expect("failed to encode image");


    as_binary(env, encoded.as_ref())
}

init!("Elixir.GlobalApi.SkinsNif", [validate_and_convert, render_skin_front]);
