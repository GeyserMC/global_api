extern crate fontdue;
extern crate lazy_static;

use std::cmp::{max, min};
use std::ops::Deref;

use fontdue::{Font, FontSettings};
use lazy_static::lazy_static;
use lodepng::{Bitmap, ColorType, FilterStrategy};
use rgb::{RGB16, RGBA};
use rustler::{Env, Term};

use crate::as_binary;
use crate::site_preview::render_items::{Image, Text};

use self::fontdue::layout::{CoordinateSystem, Layout, LayoutSettings, TextStyle};

mod render_items;

lazy_static! {
    // font stuff
    static ref FONT: Font = {
        let font = include_bytes!("../resources/Inter-Regular.ttf") as &[u8];
        Font::from_bytes(font, FontSettings::default()).unwrap()
    };
    static ref FONT_BOLD: Font = {
        let font = include_bytes!("../resources/Inter-Bold.ttf") as &[u8];
        Font::from_bytes(font, FontSettings::default()).unwrap()
    };
    static ref FONTS: [&'static Font; 2] = [FONT.deref(), FONT_BOLD.deref()];
    // logo stuff
    static ref SMALL_LOGO: Bitmap<RGBA<u8, u8>> = {
        let logo_data = include_bytes!("../resources/GeyserMC-logo-192x192.png") as &[u8];
        lodepng::decode32(logo_data).unwrap()
    };
}

const WIDTH: usize = 1200;
// const HEIGHT: usize = 630;
const HEIGHT: usize = 600;

const TITLE_COLOR: RGB16 = RGB16 {r: 55, g: 65, b: 81}; // tailwind gray 700
const BACKGROUND_COLOR: RGB16 = RGB16 {r: 243, g: 244, b: 246}; // tailwind gray 100

#[rustler::nif]
pub fn render_link_preview<'a>(env: Env<'a>, page: &str) -> Term<'a> {
    let mut preview = init_render(&WIDTH, &HEIGHT, &BACKGROUND_COLOR);
    render_image(&mut preview, &(WIDTH as i32), &Image { x: 600, y: 190, data: SMALL_LOGO.buffer.as_slice(), width: SMALL_LOGO.width as i32, center: true }, &BACKGROUND_COLOR);
    render_text(&mut preview, &Text { content: page, font_index: 1, px: 45.0, x: 600, y: 325, width: 800, height: 25, ..Text::default()}, &BACKGROUND_COLOR);
    render_text(&mut preview, &Text { content: "A way to link your accounts globally", font_index: 1, px: 40.0, x: 600, y: 390 + 45, width: 800, height: 25, ..Text::default()}, &BACKGROUND_COLOR);
    render_text(&mut preview, &Text { content: "Link once, join on every server with Global Linking enabled!", px: 30.0, x: 600, y: 480, width: 1000, height: 50, ..Text::default()}, &BACKGROUND_COLOR);
    as_binary(env, &encode_preview(&preview, &WIDTH))
}

fn encode_preview(preview: &[u8], width: &usize) -> Vec<u8> {
    let mut encoder = lodepng::Encoder::new();
    encoder.info_raw_mut().colortype = ColorType::RGB;

    // performance over filesize. It'll be cached by Cloudflare
    let mut encoder_settings = encoder.settings_mut();
    encoder_settings.zlibsettings.set_level(2);
    encoder_settings.auto_convert = false;
    encoder_settings.filter_strategy = FilterStrategy::ZERO;

    encoder.encode(preview, *width, preview.len() / 3 / width).unwrap()
}

fn init_render(width: &usize, height: &usize, background_color: &RGB16) -> Vec<u8> {
    let mut preview: Vec<u8> = Vec::with_capacity(width * height * 3);
    unsafe { preview.set_len(preview.capacity()) }

    // use background color as default color
    for i in 0..(preview.len() / 3) {
        preview[i * 3] = background_color.r as u8;
        preview[i * 3 + 1] = background_color.g as u8;
        preview[i * 3 + 2] = background_color.b as u8;
    }
    preview
}

fn render_image(preview: &mut [u8], preview_width: &i32, image: &Image, background_color: &RGB16) {
    let height = image.data.len() as i32 / image.width;

    let min_x: i32 = image.x - if image.center { image.width / 2 } else { 0 };
    let min_y: i32 = image.y - if image.center { height / 2 } else { 0 };

    for image_y in 0..height {
        let y = min_y + image_y;
        if y < 0 {
            continue;
        }
        for image_x in 0..image.width {
            let x = min_x + image_x;
            if x < 0 {
                continue;
            }
            combine_rgba(
                preview,
                &((y * preview_width + x) as usize),
                background_color,
                &image.data[(image_y * image.width + image_x) as usize]
            );
        }
    }
}

fn render_text(preview: &mut [u8], text: &Text, background_color: &RGB16) {
    let mut layout = Layout::new(CoordinateSystem::PositiveYDown);
    if text.width > 0 {
        layout.reset(&LayoutSettings { max_width: Some(text.width as f32), ..LayoutSettings::default()});
    }
    layout.append(FONTS.deref(), &TextStyle::new(text.content, text.px, text.font_index));

    let mut height_offset = std::i32::MAX;
    let mut text_height = 0;
    let mut width_offset = std::i32::MAX;
    let mut text_width = 0;
    for glyph in layout.glyphs() {
        height_offset = min(height_offset, glyph.y as i32);
        text_height = max(text_height, glyph.y as i32 + glyph.height as i32);
        width_offset = min(width_offset, glyph.x as i32); // always first element
        text_width = max(text_width, glyph.x as i32 + glyph.width as i32); // always last element
    }

    let min_x: i32;
    if text.center {
        min_x = text.x as i32 - (text_width / 2) - width_offset;
    } else {
        min_x = text.x as i32 - width_offset;
    }

    let min_y: i32 = if text.center {
        text.y as i32 - (text_height / 2) - height_offset
    } else {
        text.y as i32 - height_offset
    };

    for glyph in layout.glyphs() {
        if glyph.width * glyph.height == 0 {
            continue;
        }

        let font;
        if text.font_index == 1 {
            font = FONT_BOLD.deref()
        } else {
            font = FONT.deref()
        }

        let (metrics, data) = font.rasterize_config(glyph.key);

        let glyph_width = metrics.width;

        for index in 0..data.len() {
            // use the background color instead
            if data[index] == 0 {
                continue;
            }

            let pixel_x = glyph.x as usize + index % glyph_width;
            let pixel_y = glyph.y as usize + (index - index % glyph_width) / glyph_width;

            // we can only allow positive numbers
            if pixel_y as i32 + min_y < 0 || pixel_x as i32 + min_x < 0 {
                continue;
            }

            combine_rgb(preview, &((pixel_y + min_y as usize) * WIDTH + pixel_x + min_x as usize), background_color, &text.color, &(data[index] as u16))
        }
    }
}

fn combine_rgba(preview: &mut [u8], index: &usize, background: &RGB16, color: &RGBA<u8, u8>) {
    // we don't have to set fully transparent pixels
    if color.a == 0 {
        return;
    }

    let alpha = color.a as u16;
    let inv_alpha = 255_u16 - alpha;

    preview[index * 3] = ((alpha * color.r as u16 + inv_alpha * background.r) >> 8) as u8;
    preview[index * 3 + 1] = ((alpha * color.g as u16 + inv_alpha * background.g) >> 8) as u8;
    preview[index * 3 + 2] = ((alpha * color.b as u16 + inv_alpha * background.b) >> 8) as u8;
}

fn combine_rgb(preview: &mut [u8], index: &usize, background: &RGB16, foreground: &RGB16, coverage: &u16) {
    let inv_coverage = 255_u16 - coverage;

    preview[index * 3] = ((coverage * foreground.r + inv_coverage * background.r) >> 8) as u8;
    preview[index * 3 + 1] = ((coverage * foreground.g + inv_coverage * background.g) >> 8) as u8;
    preview[index * 3 + 2] = ((coverage * foreground.b + inv_coverage * background.b) >> 8) as u8;
}
