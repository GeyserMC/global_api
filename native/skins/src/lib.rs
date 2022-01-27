extern crate rustler;

mod skin_render;
mod skin_convert;
pub mod rustler_utils;

rustler::init!("Elixir.GlobalApi.SkinsNif", [skin_convert::validate_and_get_png]);
