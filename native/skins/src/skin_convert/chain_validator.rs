use std::collections::HashMap;
// note the 's'
use jsonwebtokens::{
    Algorithm as LegacyAlgorithm, AlgorithmID as LegacyAlgorithmID, Verifier as LegacyVerifier
};
use jsonwebtoken::{
    decode, decode_header, DecodingKey, Validation, Algorithm as JwtAlgorithm
};
use rustler::ListIterator;
use serde_json::Value;

use lazy_static::lazy_static;
use serde::Deserialize;
use std::fmt::Debug;

const MOJANG_PUBLIC_KEY: &str = "MHYwEAYHKoZIzj0CAQYFK4EEACIDYgAECRXueJeTDqNRRgJi/vlRufByu/2G0i2Ebt6YMar5QX/R0DIIyrJMcUpruK4QveTfJSTp3Shlq4Gk34cD/4GUWwkv0DVuzeuB+tXija7HBxii03NHDbPAD0AKnLr2wdAp";
const DISCOVERY_ENDPOINT: &str = "https://client.discovery.minecraft-services.net/api/v1.0/discovery/MinecraftPE/builds/1.0.0.0";

#[derive(Deserialize, Debug, Clone)]
struct Discovery {
    result: DiscoveryResult,
}

#[derive(Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
struct DiscoveryResult {
    service_environments: ServiceEnvironments,
}

#[derive(Deserialize, Debug, Clone)]
struct ServiceEnvironments {
    auth: AuthEnvironment,
}

#[derive(Deserialize, Debug, Clone)]
struct AuthEnvironment {
    prod: AuthProd,
}

#[derive(Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
struct AuthProd {
    service_uri: String,
}

#[derive(Deserialize, Debug, Clone)]
struct OpenIdConfig {
    issuer: String,
    jwks_uri: String,
}

#[derive(Deserialize, Debug, Clone)]
struct Jwks {
    keys: Vec<Jwk>,
}

#[derive(Deserialize, Debug, Clone)]
#[serde(tag = "kty")]
enum Jwk {
    #[serde(rename = "RSA")]
    Rsa {
        r#use: String,
        kid: String,
        n: String,
        e: String,
    },
    #[serde(other)]
    Unsupported
}

// https://github.com/CloudburstMC/Protocol/blob/c0fc2e863a3eec1911787ba58b6f6edf95d1cfd2/bedrock-connection/src/main/java/org/cloudburstmc/protocol/bedrock/util/EncryptionUtils.java#L97-L117
fn fetch_discovery() -> Discovery {
    ureq::get(DISCOVERY_ENDPOINT)
        .call()
        .expect("Failed to fetch discovery data")
        .body_mut()
        .read_json()
        .expect("Failed to parse discovery JSON")
}

// https://github.com/CloudburstMC/Protocol/blob/c0fc2e863a3eec1911787ba58b6f6edf95d1cfd2/bedrock-connection/src/main/java/org/cloudburstmc/protocol/bedrock/util/EncryptionUtils.java#L149-L172
fn fetch_openid_config() -> OpenIdConfig {
    let openid_url = format!(
        "{}/.well-known/openid-configuration",
        DISCOVERY_DATA.result.service_environments.auth.prod.service_uri
    );
    ureq::get(&openid_url)
        .call()
        .expect("Failed to fetch OpenID config")
        .body_mut()
        .read_json()
        .expect("Failed to parse OpenID JSON")
}

// https://github.com/CloudburstMC/Protocol/blob/c0fc2e863a3eec1911787ba58b6f6edf95d1cfd2/bedrock-connection/src/main/java/org/cloudburstmc/protocol/bedrock/util/EncryptionUtils.java#L174-L180
fn fetch_jwks() -> HashMap<String, DecodingKey> {
    let jwks: Jwks = ureq::get(&OPENID_CONFIG.jwks_uri)
        .call()
        .expect("Failed to fetch JWKS")
        .body_mut()
        .read_json()
        .expect("Failed to parse JWKS JSON");

    let mut map: HashMap<String, DecodingKey> = HashMap::with_capacity(jwks.keys.len());
    for key in jwks.keys {
        // We're currently only aware of RSA keys
        if let Jwk::Rsa { kid, r#use, n, e } = key {
            if r#use == "sig" {
                map.insert(kid, DecodingKey::from_rsa_components(&n, &e).unwrap());
            }
        }
    };
    map
}

fn create_validation() -> Validation {
    // https://github.com/CloudburstMC/Protocol/blob/c0fc2e863a3eec1911787ba58b6f6edf95d1cfd2/bedrock-connection/src/main/java/org/cloudburstmc/protocol/bedrock/util/EncryptionUtils.java#L67-L73
    // requires new lib jsonwebtoken as jsonwebtokens does not support jwks
    let mut validation = Validation::new(JwtAlgorithm::RS256);
    validation.validate_exp = true;
    validation.set_audience(&["api://auth-minecraft-services/multiplayer"]);
    validation.set_issuer(std::slice::from_ref(&OPENID_CONFIG.issuer));
    validation
}

lazy_static! {
    static ref DISCOVERY_DATA: Discovery = fetch_discovery();
    static ref OPENID_CONFIG: OpenIdConfig = fetch_openid_config();
    static ref JWKS: HashMap<String, DecodingKey> = fetch_jwks();
    static ref VALIDATION: Validation = create_validation();
}


pub fn validate_token<'a>(token: &'a str, client_data: &'a str) -> Option<(Value, Value)> {
    let header = decode_header(token).ok()?;
    let kid = header.kid?;

    let decoding_key = JWKS.get(&kid)?;

    let token_data = decode::<Value>(token, decoding_key, &VALIDATION).ok()?;
    let claims = token_data.claims;

    // check if xid is present and not null (this is xuid but they called it xid...)
    // guidance from mojang states "If the token does not contain a 'xuid' claim, servers should reject the request."
    if claims.get("xid").is_none_or(|v| v.is_null()) {
        return None;
    }

    // Uses legacy logic from jsonwebtokens to validate client data
    let cpk = claims["cpk"].as_str()?;
    
    let verifier = LegacyVerifier::create().build().unwrap();
    let cpk_key = create_key(cpk);

    let client_claims_result = verifier.verify(client_data, &cpk_key);

    if let Ok(client_claims) = client_claims_result {
        Some((claims, client_claims))
    } else {
        None
    }
}

// This is the original function for the legacy flow. Imports prefixed with Legacy.
pub fn validate_chain<'a>(chain_data: ListIterator<'a>, client_data: &'a str) -> Option<(Value, Value)> {
    let verifier = LegacyVerifier::create().build().unwrap();

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

fn create_key(pub_key: &str) -> LegacyAlgorithm {
    LegacyAlgorithm::new_ecdsa_pem_verifier(LegacyAlgorithmID::ES384, create_key_from(pub_key).as_bytes()).unwrap()
}

fn create_key_from(pub_key: &str) -> String {
    vec!["-----BEGIN PUBLIC KEY-----", pub_key, "-----END PUBLIC KEY-----"].concat()
}