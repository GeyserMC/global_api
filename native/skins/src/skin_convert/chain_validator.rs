use jsonwebtokens::{Algorithm, AlgorithmID, Verifier};
use rustler::ListIterator;
use serde_json::Value;

const MOJANG_PUBLIC_KEY: &str = "MHYwEAYHKoZIzj0CAQYFK4EEACIDYgAE8ELkixyLcwlZryUQcu1TvPOmI2B7vX83ndnWRUaXm74wFfa5f/lwQNTfrLVHa2PmenpGI6JhIMUJaWZrjmMj90NoKNFSNBuKdm8rYiXsfaz3K36x/1U26HpG0ZxK/V1V";

pub fn validate_chain<'a>(chain_data: ListIterator<'a>, client_data: &'a str) -> Option<(Value, Value)> {
    let verifier = Verifier::create().build().unwrap();

    let mut current_key = create_key(MOJANG_PUBLIC_KEY);
    let mut last_data = Value::Null;
    let mut list_size: i32 = 0;

    let mut was_mojang = false;
    let mut auth_completed = false;

    for item in chain_data {
        list_size += 1;
        if list_size > 3 {
            return None;
        }

        if auth_completed {
            return None;
        }

        let data: &str = item.decode::<&str>().unwrap();

        let claims = verifier.verify(data, &current_key);
        if let Ok(data) = claims {
            if was_mojang {
                auth_completed = true;
            } else {
                was_mojang = true;
            }

            last_data = data;
            current_key = create_key(last_data["identityPublicKey"].as_str().unwrap());
        } else if last_data != Value::Null {
            return None;
        }
    }

    if !auth_completed {
        return None;
    }

    let claims = verifier.verify(client_data, &current_key);

    if claims.is_err() {
        return None;
    }

    let client_claims = claims.unwrap();

    Some((last_data, client_claims))
}

fn create_key(pub_key: &str) -> Algorithm {
    Algorithm::new_ecdsa_pem_verifier(AlgorithmID::ES384, create_key_from(pub_key).as_bytes()).unwrap()
}

fn create_key_from(pub_key: &str) -> String {
    vec!["-----BEGIN PUBLIC KEY-----", pub_key, "-----END PUBLIC KEY-----"].concat()
}