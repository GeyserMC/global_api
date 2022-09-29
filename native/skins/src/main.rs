#![allow(dead_code)]
extern crate core;

use std::fs::File;
use std::io::{Read, Write};
use std::time::Instant;

use serde_json::Value;

use crate::skin_codec::{encode_custom_image, ImageWithHashes};
use crate::skin_convert::{ConvertResult, convert_skin, skin_codec};

mod skin_convert;
pub mod rustler_utils;

fn main() -> Result<(), String> {
    handle_skin_data_to_png_file().unwrap();
    handle_client_data_file().unwrap();
    Ok(())
}

/// the format of the file is width.height.skin_data
/// each line will be handled as a separate entry, so each line should have that format
fn handle_skin_data_to_png_file() -> Result<(), String> {
    let mut skin_data_content: Vec<u8> = Vec::new();

    let data_file = File::open("skin_data_to_png.txt");
    if data_file.is_err() {
        return Err("Unable to open client_data.txt!".to_string());
    }
    let mut data_file = data_file.unwrap();
    data_file.read_to_end(&mut skin_data_content).unwrap();

    let string = String::from_utf8(skin_data_content).unwrap();
    string.lines()
        .filter(|entry| !entry.starts_with('#'))
        .for_each(|entry| decode_and_save_image(entry.to_string()).unwrap());

    Ok(())
}

/// format is either the full client_data jwt or just the data section (headers.data.signature)
/// each line will be handled as a separate entry so each line should follow the format
fn handle_client_data_file() -> Result<(), String> {
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
    // for _ in 0..5 {
        convert_single(client_data.clone())?;
    // }
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

    let start_time = Instant::now();
    match convert_skin(&client_claims) {
        ConvertResult::Invalid(err) =>
            Err(format!("Invalid skin! {:?}", err)),

        ConvertResult::Error(err) =>
            Err(format!("An error happened while converting skins! {}", err)),

        ConvertResult::Success(ImageWithHashes { png, minecraft_hash, hash }, _is_steve) => {
            println!("Took {:.2?} to convert skin", start_time.elapsed());

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
    }
}

fn decode_and_save_image_loop(raw_data: String) -> Result<(), String> {
    for _ in 0..5 {
        decode_and_save_image(raw_data.clone()).unwrap();
    }
    Ok(())
}

fn decode_and_save_image(raw_data: String) -> Result<(), String> {
    let format: Vec<&str> = raw_data.split('.').collect();
    let mut data: Vec<u8> = base64::decode(format[2]).unwrap();
    encode_and_save_image(&mut data, format[0].parse().unwrap(), format[1].parse().unwrap());
    Ok(())
}

fn encode_and_save_image(data: &mut Vec<u8>, w: usize, h: usize) {
    let ImageWithHashes { png, minecraft_hash, hash: _hash } = encode_custom_image(data, w, h);

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