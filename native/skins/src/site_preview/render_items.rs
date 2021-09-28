use rgb::{RGB16, RGBA};

use crate::site_preview::TITLE_COLOR;

pub struct RenderItem {
    pub x: usize,
    pub y: usize,
    pub width: usize,
    pub height: usize,
    pub center: bool,
}

impl Default for RenderItem {
    fn default() -> Self {
        RenderItem {
            x: 0,
            y: 0,
            width: 0,
            height: 0,
            center: true,
        }
    }
}

pub struct Image<'a> {
    pub x: i32,
    pub y: i32,
    pub data: &'a [RGBA<u8, u8>],
    pub width: i32,
    // pub height: usize,
    pub center: bool
}

pub struct Text<'a> {
    pub content: &'a str,
    pub font_index: usize,
    pub px: f32,
    pub x: usize,
    pub y: usize,
    pub width: usize,
    pub height: usize,
    pub center: bool,
    pub color: RGB16,
}

impl<'a> Default for Text<'a> {
    fn default() -> Self {
        Text {
            content: "unknown text",
            font_index: 0,
            px: 10.0,
            x: 0,
            y: 0,
            width: 0,
            height: 0,
            center: true,
            color: TITLE_COLOR
        }
    }
}