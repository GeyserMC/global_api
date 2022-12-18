use crate::common::RGBA_CHANNELS;

pub fn clear_unused_pixels(raw_data: &mut [u8], is_steve: bool) -> &mut [u8] {
    // clear the unused sections of a 64x64 skin

    // first row
    for x in 0..8 {
        for y in 0..8 {
            set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
        }
    }
    for x in 24..40 {
        for y in 0..8 {
            set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
        }
    }
    for x in 56..64 {
        for y in 0..8 {
            set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
        }
    }
    // second row
    for x in 0..4 {
        for y in 16..20 {
            set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
        }
    }
    for x in 12..20 {
        for y in 16..20 {
            set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
        }
    }
    for x in 36..44 {
        for y in 16..20 {
            set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
        }
    }
    // third row
    for x in 0..4 {
        for y in 32..36 {
            set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
        }
    }
    for x in 12..20 {
        for y in 32..36 {
            set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
        }
    }
    for x in 36..44 {
        for y in 32..36 {
            set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
        }
    }
    // fourth row
    for x in 0..4 {
        for y in 48..52 {
            set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
        }
    }
    for x in 12..20 {
        for y in 48..52 {
            set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
        }
    }
    for x in 28..36 {
        for y in 48..52 {
            set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
        }
    }
    // Alex skins have more empty space then Steve skins
    if is_steve {
        // second row
        for x in 52..56 {
            for y in 16..20 {
                set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
            }
        }
        // third row
        for x in 52..56 {
            for y in 32..36 {
                set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
            }
        }
        // fourth row
        for x in 44..52 {
            for y in 48..52 {
                set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
            }
        }
        for x in 60..64 {
            for y in 48..52 {
                set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
            }
        }
        // big unused area in row 2 and 3
        for x in 56..64 {
            for y in 16..48 {
                set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
            }
        }
    } else {
        // second row
        for x in 50..54 {
            for y in 16..20 {
                set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
            }
        }
        // third row
        for x in 50..52 {
            for y in 32..36 {
                set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
            }
        }
        // fourth row
        for x in 42..52 {
            for y in 48..52 {
                set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
            }
        }
        for x in 46..48 {
            for y in 52..64 {
                set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
            }
        }
        for x in 58..64 {
            for y in 48..52 {
                set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
            }
        }
        for x in 62..64 {
            for y in 52..64 {
                set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
            }
        }
        // big unused area in row 2 and 3
        for x in 54..64 {
            for y in 16..48 {
                set_pixel(raw_data, x, y, 64, 0, 0, 0, 0);
            }
        }
    }
    raw_data
}

fn set_pixel(vec: &mut [u8], x: usize, y: usize, width: usize, r: u8, g: u8, b: u8, a: u8) {
    vec[(y * width + x) * RGBA_CHANNELS] = r;
    vec[(y * width + x) * RGBA_CHANNELS + 1] = g;
    vec[(y * width + x) * RGBA_CHANNELS + 2] = b;
    vec[(y * width + x) * RGBA_CHANNELS + 3] = a;
}