extern crate jsonwebtokens;
extern crate lodepng;
extern crate rustler;
extern crate base64;
extern crate serde_json;
extern crate sha2;
extern crate bytes;
extern crate rgb;

use jsonwebtokens::{Algorithm, AlgorithmID, Verifier};
use rustler::{Env, ListIterator, Term, Encoder, OwnedBinary, Binary};
use rustler::types::atom::{false_, true_, ok};
use rustler::types::tuple::make_tuple;
use std::primitive;
use rustler::atoms;
use serde_json::Value;
use sha2::{Sha256, Digest};
use bytes::Bytes;
use rgb::*;

const STEVE_GEOMETRY : &primitive::str = "ewogICAiZ2VvbWV0cnkiIDogewogICAgICAiZGVmYXVsdCIgOiAiZ2VvbWV0cnkuaHVtYW5vaWQuY3VzdG9tIgogICB9Cn0K";
const ALEX_GEOMETRY : &primitive::str = "ewogICAiZ2VvbWV0cnkiIDogewogICAgICAiZGVmYXVsdCIgOiAiZ2VvbWV0cnkuaHVtYW5vaWQuY3VzdG9tQWxleCIKICAgfQp9Cg==";

atoms! {
    invalid_chain_data,
    invalid_client_data,
    invalid_size,
    invalid_image,
    invalid_geometry,
    hash_doesnt_match
}

fn get_texture(texture_id: &primitive::str) -> Bytes {
    let mut uri = String::from("https://textures.minecraft.net/texture/");
    uri.push_str(texture_id);
    reqwest::blocking::get(&uri).unwrap().bytes().unwrap()
}

#[rustler::nif]
pub fn validate_and_get_hash<'a>(env: Env<'a>, chain_data: Term, client_data: &primitive::str) -> Term<'a> {
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

    let skin_width = client_claims["SkinImageWidth"].as_u64().unwrap() as usize;
    let skin_height = client_claims["SkinImageHeight"].as_u64().unwrap() as usize;

    if skin_width != 64 || (skin_height != 64 && skin_height != 32) {
        return invalid_size().to_term(env);
    }

    let skin_data = client_claims["SkinData"].as_str().unwrap();
    let raw_skin_data = base64::decode(skin_data).unwrap();

    if raw_skin_data.len() != skin_width * skin_height * 4 {
        return invalid_size().to_term(env);
    }

    let skin_geometry_option = client_claims["SkinResourcePatch"].as_str();

    if skin_geometry_option.is_none() {
        return invalid_geometry().to_term(env)
    }

    let skin_geometry = skin_geometry_option.unwrap();

    if skin_geometry != STEVE_GEOMETRY && skin_geometry != ALEX_GEOMETRY {
        return invalid_geometry().to_term(env)
    }

    let username = last_data["extraData"]["displayName"].as_str();
    let xuid = last_data["extraData"]["XUID"].as_str();

    let mut hasher = Sha256::new();
    hasher.update(raw_skin_data.as_slice());

    let hash = hasher.finalize();

    // let data = lodepng::decode32(get_texture(texture_id)).unwrap();
    // let raw_data: &[u8] = data.buffer.as_bytes();
    //
    //
    // let mut hasher = Sha256::new();
    // hasher.update(raw_data);
    // let hash2 = hasher.finalize();
    //
    // if hash == hash2 {
    //     return ok().to_term(env);
    // }

    make_tuple(env, &[xuid.encode(env), username.encode(env), as_binary(env, hash.as_slice())])
}

#[rustler::nif]
pub fn get_texture_compare_hash<'a>(env: Env<'a>, rgba_hash: Binary, texture_id: &primitive::str) -> Term<'a> {
    let data = lodepng::decode32(get_texture(texture_id)).unwrap();
    let raw_data: &[u8] = data.buffer.as_bytes();

    let mut hasher = Sha256::new();
    hasher.update(raw_data);
    let hash2 = hasher.finalize();

    if hash2.to_vec().eq(rgba_hash.as_slice()) {
        return ok().to_term(env);
    }
    make_tuple(env, &[hash_doesnt_match().to_term(env), as_binary(env, hash2.as_slice())])
}

fn as_binary<'a>(env: Env<'a>, data: &[u8]) -> Term<'a> {
    let mut erl_bin: OwnedBinary = OwnedBinary::new(data.len()).unwrap();
    erl_bin.as_mut_slice().copy_from_slice(data);
    Binary::from_owned(erl_bin, env).to_term(env)
}

#[rustler::nif]
pub fn validate_data_and_make_png<'a>(env: Env<'a>, chain_data: Term, client_data: &primitive::str) -> Term<'a> {
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

    let skin_width = client_claims["SkinImageWidth"].as_u64().unwrap() as usize;
    let skin_height = client_claims["SkinImageHeight"].as_u64().unwrap() as usize;

    if skin_width != 64 || (skin_height != 64 && skin_height != 32) {
        return invalid_size().to_term(env);
    }

    let skin_data = client_claims["SkinData"].as_str().unwrap();
    let raw_skin_data = base64::decode(skin_data).unwrap();

    let skin_geometry_option = client_claims["SkinResourcePatch"].as_str();

    if skin_geometry_option.is_none() {
        return invalid_geometry().to_term(env)
    }

    let skin_geometry = skin_geometry_option.unwrap();

    let mut is_steve = false_();
    if skin_geometry == STEVE_GEOMETRY {
        is_steve = true_();
    } else if skin_geometry != ALEX_GEOMETRY {
        return invalid_geometry().to_term(env)
    }

    let png = lodepng::encode32(raw_skin_data.as_slice(), skin_width, skin_height).unwrap();
    let mut erl_bin: OwnedBinary = OwnedBinary::new(png.len()).unwrap();
    erl_bin.as_mut_slice().copy_from_slice(&png);

    let username = last_data["extraData"]["displayName"].as_str();
    let xuid = last_data["extraData"]["XUID"].as_str();

    make_tuple(env, &[erl_bin.encode(env), is_steve.to_term(env), username.encode(env), xuid.encode(env)])
    //todo add name and xuid and check in db / cache requests / deny requests
}

pub fn create_key(pub_key: &primitive::str) -> Algorithm {
    Algorithm::new_ecdsa_pem_verifier(AlgorithmID::ES384, create_key_from(pub_key).as_bytes()).unwrap()
}

pub fn create_key_from<'a>(pub_key: &primitive::str) -> String {
    vec!["-----BEGIN PUBLIC KEY-----", pub_key, "-----END PUBLIC KEY-----"].concat()
}

rustler::init!("Elixir.GlobalLinking.SkinNifUtils", [validate_data_and_make_png, validate_and_get_hash, get_texture_compare_hash]);
