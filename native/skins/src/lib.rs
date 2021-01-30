extern crate jsonwebtokens;
extern crate lodepng;
extern crate rustler;

use jsonwebtokens::{Algorithm, AlgorithmID, Verifier};
use rustler::{Binary, Env, ListIterator, Term};
use rustler::OwnedBinary;
use rustler::types::atom::{nil, false_};
use rustler::types::tuple::make_tuple;
use std::primitive;

#[rustler::nif]
pub fn rgba_to_png(width: usize, height: usize, raw_rgba: Binary) -> OwnedBinary {
    let png = lodepng::encode32(raw_rgba.as_slice(), width, height).unwrap();
    let mut erl_bin: OwnedBinary = OwnedBinary::new(png.len()).unwrap();
    erl_bin.as_mut_slice().copy_from_slice(&png);
    erl_bin
}

#[rustler::nif]
pub fn validate_data<'a>(env: Env<'a>, chain_data: Term, client_data: &primitive::str) -> Term<'a> {
    let list_iterator: ListIterator = chain_data.decode().unwrap();

    let mojang_key: Algorithm = create_key("MHYwEAYHKoZIzj0CAQYFK4EEACIDYgAE8ELkixyLcwlZryUQcu1TvPOmI2B7vX83ndnWRUaXm74wFfa5f/lwQNTfrLVHa2PmenpGI6JhIMUJaWZrjmMj90NoKNFSNBuKdm8rYiXsfaz3K36x/1U26HpG0ZxK/V1V");
    let verifier = Verifier::create().build().unwrap();

    let mut last_success = false;
    let mut current_key = mojang_key;

    for x in list_iterator {
        let data: &primitive::str = x.decode::<&primitive::str>().unwrap();
        let claims = verifier.verify(data, &current_key);
        if claims.is_ok() {
            last_success = true;
            current_key = create_key(claims.unwrap()["identityPublicKey"].as_str().unwrap())
        } else if last_success {
            return false_().to_term(env);
        }
    }

    //todo return skin data claims and last chain data claim

    if last_success {
        let claims = verifier.verify(client_data, &current_key);
        if claims.is_ok() {
            make_tuple(env, &[nil().to_term(env), nil().to_term(env)])
        } else {
            false_().to_term(env)
        }
    } else {
        false_().to_term(env)
    }
}

pub fn create_key(pub_key: &primitive::str) -> Algorithm {
    Algorithm::new_ecdsa_pem_verifier(AlgorithmID::ES384, create_key_from(pub_key).as_bytes()).unwrap()
}

pub fn create_key_from<'a>(pub_key: &primitive::str) -> String {
    vec!["-----BEGIN PUBLIC KEY-----", pub_key, "-----END PUBLIC KEY-----"].concat()
}

rustler::init!("Elixir.GlobalLinking.SkinNifUtils", [rgba_to_png, validate_data]);
