#![allow(dead_code)]
extern crate core;

use std::fs::File;
use std::io::{Read, Write};

use serde_json::Value;

use crate::skin_codec::{encode_image_and_get_hash, encode_image_and_get_hashes};
use crate::skin_convert::converter::get_skin_or_convert_geometry;
use crate::skin_convert::skin_codec;

mod skin_convert;
pub mod rustler_utils;

fn main() -> Result<(), String> {
    let mut client_data_content: Vec<u8> = Vec::new();

    let data_file = File::open("client_data.txt");
    if data_file.is_err() {
        return Err("Unable to open client_data.txt!".to_string());
    }
    let mut data_file = data_file.unwrap();
    data_file.read_to_end(&mut client_data_content).unwrap();

    let string = String::from_utf8(client_data_content).unwrap();
    string.lines()
        .filter(|entry| !entry.starts_with('#'))
        .for_each(|entry| convert_single_loop(entry.to_string()).unwrap());

    Ok(())
}

fn convert_single_loop(client_data: String) -> Result<(), String> {
    for _ in 0..5 {
        convert_single(client_data.clone())?;
    }
    Ok(())
}

fn convert_single(mut client_data: String) -> Result<(), String> {
    let items: Vec<&str> = client_data.split('.').collect();
    if items.len() == 3 {
        // jwt content is in the second part
        client_data = items[1].to_string();
    } else if items.len() != 1 {
        return Err("Received client data is neither a JWT nor the raw content of a JWT".to_string());
    }

    let result = base64::decode(client_data);
    if result.is_err() {
        return Err("Received invalid base64!".to_string());
    }

    let result: Result<Value, _> = serde_json::from_slice(result.unwrap().as_slice());
    if result.is_err() {
        return Err("Received invalid json!".to_string());
    }

    let client_claims = result.unwrap();

    let collect_result = skin_codec::collect_skin_info(&client_claims);
    if collect_result.is_err() {
        return Err(format!("Invalid skin! {:?}", collect_result.err().unwrap()));
    }

    let skin_info = collect_result.ok().unwrap();

    // sometimes its already defined what model a skin is
    let mut arm_model = -1;
    let arm_size = client_claims.get("ArmSize");
    if let Some(arm_size) = arm_size {
        let arm_size = arm_size.as_str();
        if let Some(arm_size) = arm_size {
            arm_model = if arm_size.eq("slim") { 1 } else { 0 };
        }
    }

    let convert_result = get_skin_or_convert_geometry(skin_info, client_claims);
    if let Err(err) = convert_result {
        return Err(format!("An error happened while converting skins! {}", err));
    }

    let (mut raw_data, mut is_steve) = convert_result.unwrap();
    if arm_model != -1 {
        is_steve = arm_model == 0;
    }

    let (png, minecraft_hash, hash) = encode_image_and_get_hashes(&mut raw_data, is_steve);

    let mc_hash_hex = write_hex(minecraft_hash.as_ref());
    let hash_hex = write_hex(hash.as_ref());

    println!("Successfully encoded the converted image!");
    println!("Internal hash: {:}, Minecraft hash: {:}", hash_hex, mc_hash_hex);

    let mut file = File::create(format!("{:}.png", mc_hash_hex)).unwrap();

    match file.write_all(png.as_ref()) {
        Ok(_) => println!("Wrote the converted png to {:}.png", mc_hash_hex),
        Err(err) => println!("Failed to write converted png! {:?}", err)
    }
    Ok(())
}

fn encode_and_save_image_loop(raw_data: String, w: usize, h: usize) {
    for _ in 0..5 {
        encode_and_save_image(raw_data.clone(), w, h);
    }
}

fn encode_and_save_image(raw_data: String, w: usize, h: usize) {
    let mut data = base64::decode(raw_data).unwrap();
    let (png, minecraft_hash) = encode_image_and_get_hash(&mut data, w, h);

    let mc_hash_hex = write_hex(minecraft_hash.as_ref());

    let mut file = File::create(format!("{:}.png", mc_hash_hex)).unwrap();

    match file.write_all(png.as_ref()) {
        Ok(_) => println!("Wrote the png to {:}.png", mc_hash_hex),
        Err(err) => println!("Failed to write converted png! {:?}", err)
    }
}

fn write_hex(bytes: &[u8]) -> String {
    let mut s = String::with_capacity(2 * bytes.len());
    for byte in bytes {
        core::fmt::write(&mut s, format_args!("{:02X}", byte)).unwrap();
    }
    s
}